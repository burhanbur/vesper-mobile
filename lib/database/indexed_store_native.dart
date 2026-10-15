import 'dart:collection';
import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'tracked_json.dart';
import 'transaction_query.dart';

/// Native page encryption protects both financial payloads and query indexes.
/// Each commit serializes only changed records and small metadata/outbox units.
class IndexedStore {
  final Database database;
  final String userId;
  final JsonJournal journal = JsonJournal();
  late final _RootState _state;
  Map<String, dynamic> get state => _state;
  int revision = 0;
  final Map<String, _SummaryWindow> _summaries = {};
  final List<(dynamic, dynamic)> _summaryChanges = [];
  bool _resetSummaries = false;

  IndexedStore(this.database, List<int> key, this.userId) {
    if (key.length != 32 || database.select('PRAGMA cipher').isEmpty) {
      throw StateError('Authenticated native database cipher unavailable');
    }
    database.execute("PRAGMA cipher='chacha20'");
    final hex = key
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    database.execute("PRAGMA key='raw:$hex'");
    // A key PRAGMA alone does not verify the key. Never initialize after an
    // unreadable schema: that would risk disguising lost data as a fresh store.
    database.select('SELECT name FROM sqlite_master LIMIT 1');
    final version = database.userVersion;
    if (version != 0 && version != 3) {
      throw StateError('Unsupported indexed storage version');
    }
    database.execute('PRAGMA journal_mode=WAL');
    database.execute('PRAGMA synchronous=FULL');
    database.execute('PRAGMA temp_store=MEMORY');
    database.execute('PRAGMA secure_delete=ON');
    database.execute(
      '''CREATE TABLE IF NOT EXISTS store_info(
      id INTEGER PRIMARY KEY CHECK(id=1), owner TEXT NOT NULL,
      revision INTEGER NOT NULL, source_digest TEXT, initialized INTEGER NOT NULL)''',
    );
    database.execute('''CREATE TABLE IF NOT EXISTS entity_tables(
      type TEXT PRIMARY KEY, kind TEXT NOT NULL, payload TEXT)''');
    database.execute('''CREATE TABLE IF NOT EXISTS entity_records(
      entity_type TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL,
      account_id TEXT, date_us INTEGER, transaction_type TEXT,
      deleted INTEGER NOT NULL, search_text TEXT NOT NULL,
      PRIMARY KEY(entity_type,id)) WITHOUT ROWID''');
    database.execute('''CREATE INDEX IF NOT EXISTS transactions_date
      ON entity_records(entity_type,deleted,date_us DESC,id ASC)''');
    database.execute('''CREATE INDEX IF NOT EXISTS transactions_account_date
      ON entity_records(entity_type,account_id,deleted,date_us DESC,id ASC)''');
    database.execute(
      '''CREATE INDEX IF NOT EXISTS transactions_type_date
      ON entity_records(entity_type,transaction_type,deleted,date_us DESC,id ASC)''',
    );
    database.execute(
      'CREATE TABLE IF NOT EXISTS metadata(key TEXT PRIMARY KEY,payload TEXT NOT NULL)',
    );
    database.execute(
      '''CREATE TABLE IF NOT EXISTS outbox(
      id TEXT PRIMARY KEY, position INTEGER NOT NULL UNIQUE, status TEXT, payload TEXT NOT NULL)''',
    );
    database.execute('INSERT OR IGNORE INTO store_info VALUES(1,?,0,NULL,0)', [
      userId,
    ]);
    final info = database.select('SELECT * FROM store_info WHERE id=1').single;
    if (info['owner'] != userId) {
      throw StateError('Indexed financial data owner mismatch');
    }
    revision = info['revision'] as int;
    _state = _RootState(this);
    database.userVersion = 3;
  }

  bool get initialized =>
      database
          .select('SELECT initialized FROM store_info WHERE id=1')
          .single['initialized'] ==
      1;
  String? get sourceDigest =>
      database
              .select('SELECT source_digest FROM store_info WHERE id=1')
              .single['source_digest']
          as String?;

  void importSnapshot(Map<String, dynamic> snapshot, String digest) {
    if (initialized) {
      if (sourceDigest != digest) {
        throw StateError('Migration source changed; both stores retained');
      }
      return;
    }
    atomic(() {
      _state.clear();
      _state.addAll(snapshot);
    }, sourceDigest: digest);
  }

  void atomic(void Function() action, {String? sourceDigest}) {
    try {
      action();
      commit(sourceDigest: sourceDigest);
    } catch (_) {
      journal.rollback();
      rethrow;
    }
  }

  void commit({String? sourceDigest}) {
    if (journal.dirty.isEmpty && sourceDigest == null) return;
    database.execute('BEGIN IMMEDIATE');
    _summaryChanges.clear();
    _resetSummaries = false;
    try {
      final current = database
          .select('SELECT revision FROM store_info WHERE id=1')
          .single['revision'];
      if (current != revision) {
        throw StateError(
          'Local data changed in another session; reopen before editing',
        );
      }
      final dirty = Set<DirtyUnit>.of(journal.dirty);
      if (dirty.any((unit) => unit.$1 == 'entities')) {
        _resetSummaries = true;
        database.execute('DELETE FROM entity_records');
        database.execute('DELETE FROM entity_tables');
        for (final type in _state.entities.keys.toList()) {
          _writeTable(type);
        }
      } else {
        final tables = dirty
            .where((unit) => unit.$1 == 'table')
            .map((unit) => unit.$2)
            .toSet();
        for (final type in tables) {
          _writeTable(type);
        }
        for (final unit in dirty.where(
          (unit) => unit.$1 == 'row' && !tables.contains(unit.$2),
        )) {
          final table = _state.entities[unit.$2] as Map?;
          if (table == null || !table.containsKey(unit.$3)) {
            _rememberSummaryChange(unit.$2, unit.$3!, null);
            database.execute(
              'DELETE FROM entity_records WHERE entity_type=? AND id=?',
              [unit.$2, unit.$3],
            );
          } else {
            _writeRow(unit.$2, unit.$3!, table[unit.$3]);
          }
        }
      }
      for (final unit in dirty.where((unit) => unit.$1 == 'meta')) {
        final key = unit.$2;
        if (key == 'outbox') {
          database.execute('DELETE FROM outbox');
          final items = _state[key] as List? ?? const [];
          for (var index = 0; index < items.length; index++) {
            final item = items[index] as Map;
            if (item['id'] is! String) {
              throw const FormatException('Invalid outbox identity');
            }
            database.execute('INSERT INTO outbox VALUES(?,?,?,?)', [
              item['id'],
              index,
              item['status'],
              jsonEncode(item),
            ]);
          }
        } else if (!_state.containsKey(key)) {
          database.execute('DELETE FROM metadata WHERE key=?', [key]);
        } else {
          database.execute(
            'INSERT INTO metadata VALUES(?,?) ON CONFLICT(key) DO UPDATE SET payload=excluded.payload',
            [key, jsonEncode(_state[key])],
          );
        }
      }
      database.execute(
        'UPDATE store_info SET revision=revision+1,initialized=1,source_digest=COALESCE(?,source_digest) WHERE id=1',
        [sourceDigest],
      );
      database.execute('COMMIT');
      revision++;
      if (_resetSummaries) {
        _summaries.clear();
      } else {
        try {
          for (final summary in _summaries.values) {
            for (final change in _summaryChanges) {
              summary.apply(change.$1, -1);
              summary.apply(change.$2, 1);
            }
          }
        } catch (_) {
          _summaries.clear();
        }
      }
      _state.entities.saved();
      journal.committed();
    } catch (_) {
      database.execute('ROLLBACK');
      journal.rollback();
      rethrow;
    }
  }

  void _writeTable(String type) {
    if (type == 'transactions') _resetSummaries = true;
    database.execute('DELETE FROM entity_records WHERE entity_type=?', [type]);
    if (!_state.entities.containsKey(type)) {
      database.execute('DELETE FROM entity_tables WHERE type=?', [type]);
      return;
    }
    final table = _state.entities[type];
    database.execute(
      'INSERT INTO entity_tables VALUES(?,?,?) ON CONFLICT(type) DO UPDATE SET kind=excluded.kind,payload=excluded.payload',
      [
        type,
        table is Map ? 'map' : 'opaque',
        table is Map ? null : jsonEncode(table),
      ],
    );
    if (table is Map) {
      for (final id in table.keys.toList()) {
        _writeRow(type, id as String, table[id]);
      }
    }
  }

  void _writeRow(String type, String id, dynamic value) {
    _rememberSummaryChange(type, id, value);
    final map = value is Map ? value : const <String, dynamic>{};
    final date = DateTime.tryParse('${map['transacted_at'] ?? ''}');
    database.execute(
      '''INSERT INTO entity_records VALUES(?,?,?,?,?,?,?,?)
      ON CONFLICT(entity_type,id) DO UPDATE SET payload=excluded.payload,
      account_id=excluded.account_id,date_us=excluded.date_us,transaction_type=excluded.transaction_type,
      deleted=excluded.deleted,search_text=excluded.search_text''',
      [
        type,
        id,
        jsonEncode(value),
        map['account_id'] is String ? map['account_id'] : null,
        date?.toUtc().microsecondsSinceEpoch,
        map['type'] is String ? map['type'] : null,
        map['deleted_at'] == null ? 0 : 1,
        '${map['description'] ?? ''} ${map['name'] ?? ''}'.toLowerCase(),
      ],
    );
  }

  void _rememberSummaryChange(String type, String id, dynamic next) {
    if (type != 'transactions' || _summaries.isEmpty || _resetSummaries) return;
    final rows = database.select(
      'SELECT payload FROM entity_records WHERE entity_type=? AND id=?',
      [type, id],
    );
    _summaryChanges.add((
      rows.isEmpty ? null : jsonDecode(rows.single['payload'] as String),
      next,
    ));
  }

  TransactionSummary transactionSummary(DateTime start, DateTime end) {
    final key =
        '${start.toUtc().microsecondsSinceEpoch}:${end.toUtc().microsecondsSinceEpoch}:${DateTime.now().timeZoneName}';
    final cached = _summaries[key];
    if (cached != null) return cached.snapshot;
    final summary = _SummaryWindow(
      start.toUtc().microsecondsSinceEpoch,
      end.toUtc().microsecondsSinceEpoch,
    );
    for (final row in database.select(
      '''SELECT payload FROM entity_records
      WHERE entity_type='transactions' AND deleted=0 AND date_us>=? AND date_us<?''',
      [summary.start, summary.end],
    )) {
      summary.apply(jsonDecode(row['payload'] as String), 1);
    }
    // Bound transient report caches as people navigate months.
    if (_summaries.length >= 24) _summaries.remove(_summaries.keys.first);
    _summaries[key] = summary;
    return summary.snapshot;
  }

  TransactionPage transactionPage(TransactionQuery query) {
    if (journal.dirty.isNotEmpty) {
      throw StateError('Commit local edits before querying history');
    }
    final limit = query.limit.clamp(1, 100);
    final clauses = <String>["t.entity_type='transactions'", 't.deleted=0'];
    final parameters = <Object?>[];
    if (query.start != null) {
      clauses.add('t.date_us>=?');
      parameters.add(query.start!.toUtc().microsecondsSinceEpoch);
    }
    if (query.end != null) {
      clauses.add('t.date_us<?');
      parameters.add(query.end!.toUtc().microsecondsSinceEpoch);
    }
    if (query.accountId != null) {
      clauses.add('t.account_id=?');
      parameters.add(query.accountId);
    }
    if (query.type != null) {
      clauses.add('t.transaction_type=?');
      parameters.add(query.type);
    }
    if (query.after != null) {
      final stamp = int.parse(query.after!.microseconds);
      clauses.add('(t.date_us<? OR(t.date_us=? AND t.id>?))');
      parameters.addAll([stamp, stamp, query.after!.id]);
    }
    var join = '';
    final search = query.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      join = "LEFT JOIN entity_records c ON c.entity_type='categories' AND c.id=json_extract(t.payload,'\$.category_id')";
      clauses.add(
        "(instr(t.search_text,?)>0 OR instr(c.search_text,?)>0 OR (t.transaction_type='TRANSFER' AND (c.id IS NULL OR json_extract(c.payload,'\$.name')='') AND instr('transfer antar akun',?)>0) OR (?=1 AND json_extract(t.payload,'\$.created_by')=?))",
      );
      parameters.addAll([
        search,
        search,
        search,
        query.actorName.toLowerCase().contains(search) ? 1 : 0,
        query.actorId,
      ]);
    }
    parameters.add(limit + 1);
    final result = database.select(
      'SELECT t.id,t.date_us,t.payload FROM entity_records t $join WHERE ${clauses.join(' AND ')} ORDER BY t.date_us DESC,t.id ASC LIMIT ?',
      parameters,
    );
    final visible = result.take(limit).toList();
    return TransactionPage(
      visible
          .map(
            (row) => Map<String, dynamic>.from(
              jsonDecode(row['payload'] as String) as Map,
            ),
          )
          .toList(),
      result.length > limit
          ? TransactionCursor(
              '${visible.last['date_us']}',
              visible.last['id'] as String,
            )
          : null,
    );
  }

  void close() => database.close();
}

class _SummaryWindow {
  final int start, end;
  BigInt income = BigInt.zero, expense = BigInt.zero;
  final Map<int, BigInt> daily = {};
  _SummaryWindow(this.start, this.end);

  void apply(dynamic value, int direction) {
    if (value is! Map || value['deleted_at'] != null) return;
    final date = DateTime.tryParse('${value['transacted_at']}');
    if (date == null ||
        date.microsecondsSinceEpoch < start ||
        date.microsecondsSinceEpoch >= end) {
      return;
    }
    if (!['INCOME', 'EXPENSE'].contains(value['type'])) return;
    final match = RegExp(r'^(-?\d+)(?:\.(\d{1,2}))?$')
        .firstMatch('${value['amount']}');
    if (match == null) throw const FormatException('Invalid decimal amount');
    final integer = BigInt.parse(match[1]!);
    final fractional = BigInt.parse((match[2] ?? '').padRight(2, '0'));
    final cents = integer.abs() * BigInt.from(100) + fractional;
    final delta = cents * BigInt.from(direction);
    final isIncome = value['type'] == 'INCOME';
    if (isIncome) {
      income += delta;
    } else {
      expense += delta;
    }
    final day = date.toLocal().day;
    daily[day] = (daily[day] ?? BigInt.zero) + (isIncome ? delta : -delta);
  }

  static String decimal(BigInt cents) {
    final absolute = cents.abs();
    return '${cents.isNegative ? '-' : ''}${absolute ~/ BigInt.from(100)}.${(absolute % BigInt.from(100)).toString().padLeft(2, '0')}';
  }

  TransactionSummary get snapshot => TransactionSummary(
    decimal(income),
    decimal(expense),
    Map.unmodifiable(daily.map((day, value) => MapEntry(day, decimal(value)))),
  );
}

class _RootState extends MapBase<String, dynamic> {
  final IndexedStore store;
  final Map<String, dynamic> _metadata = {};
  late _EntityTypes entities;
  _RootState(this.store) {
    entities = _EntityTypes(store);
    for (final row in store.database.select(
      'SELECT key,payload FROM metadata',
    )) {
      final key = row['key'] as String;
      _metadata[key] = store.journal.wrap(
        jsonDecode(row['payload'] as String),
        ('meta', key, null),
      );
    }
    _metadata.putIfAbsent('cursor', () => '0');
    _metadata['outbox'] = store.journal.wrap(
      store.database
          .select('SELECT payload FROM outbox ORDER BY position')
          .map((row) => jsonDecode(row['payload'] as String))
          .toList(),
      ('meta', 'outbox', null),
    );
  }
  @override
  dynamic operator [](Object? key) =>
      key == 'entities' ? entities : _metadata[key];
  @override
  Iterable<String> get keys => ['entities', ..._metadata.keys];
  @override
  bool containsKey(Object? key) =>
      key == 'entities' || _metadata.containsKey(key);
  @override
  dynamic putIfAbsent(String key, dynamic Function() ifAbsent) {
    if (!containsKey(key)) this[key] = ifAbsent();
    return this[key];
  }

  @override
  void operator []=(String key, dynamic value) {
    if (key == 'entities') {
      if (value is! Map) throw const FormatException('Invalid entity tables');
      final previous = entities;
      final next = _EntityTypes(
        store,
        initial: Map<String, dynamic>.from(value),
      );
      store.journal.record(('entities', '', null), () => entities = previous);
      entities = next;
      return;
    }
    final wrapped = store.journal.wrap(value, ('meta', key, null));
    final existed = _metadata.containsKey(key), previous = _metadata[key];
    store.journal.record(('meta', key, null), () {
      if (existed) {
        _metadata[key] = previous;
      } else {
        _metadata.remove(key);
      }
    });
    _metadata[key] = wrapped;
  }

  @override
  dynamic remove(Object? key) {
    if (key == 'entities') {
      final previous = entities;
      this['entities'] = <String, dynamic>{};
      return previous;
    }
    if (key is! String || !_metadata.containsKey(key)) return null;
    final previous = _metadata[key];
    store.journal.record(('meta', key, null), () => _metadata[key] = previous);
    return _metadata.remove(key);
  }

  @override
  void clear() {
    for (final key in keys.toList()) {
      remove(key);
    }
  }
}

class _EntityTypes extends MapBase<String, dynamic> {
  final IndexedStore store;
  final Map<String, dynamic> _tables = {};
  _EntityTypes(this.store, {Map<String, dynamic>? initial}) {
    if (initial != null) {
      for (final entry in initial.entries) {
        _tables[entry.key] = _table(entry.key, entry.value);
      }
    } else {
      for (final row in store.database.select(
        'SELECT * FROM entity_tables ORDER BY type',
      )) {
        final type = row['type'] as String;
        _tables[type] = row['kind'] == 'map'
            ? _EntityRows(store, type)
            : store.journal.wrap(jsonDecode(row['payload'] as String), (
                'table',
                type,
                null,
              ));
      }
    }
  }
  dynamic _table(String type, dynamic value) => value is Map
      ? _EntityRows(store, type, initial: Map<String, dynamic>.from(value))
      : store.journal.wrap(value, ('table', type, null));
  @override
  dynamic operator [](Object? key) => _tables[key];
  @override
  Iterable<String> get keys => _tables.keys;
  @override
  bool containsKey(Object? key) => _tables.containsKey(key);
  @override
  dynamic putIfAbsent(String key, dynamic Function() ifAbsent) {
    if (!containsKey(key)) this[key] = ifAbsent();
    return this[key];
  }

  @override
  void operator []=(String key, dynamic value) {
    final next = _table(key, value), previous = _tables[key];
    final existed = _tables.containsKey(key);
    store.journal.record(('table', key, null), () {
      if (existed) {
        _tables[key] = previous;
      } else {
        _tables.remove(key);
      }
    });
    _tables[key] = next;
  }

  @override
  dynamic remove(Object? key) {
    if (key is! String || !_tables.containsKey(key)) return null;
    final previous = _tables[key];
    store.journal.record(('table', key, null), () => _tables[key] = previous);
    return _tables.remove(key);
  }

  @override
  void clear() {
    for (final key in keys.toList()) {
      remove(key);
    }
  }

  void saved() {
    for (final table in _tables.values) {
      if (table is _EntityRows) table.saved();
    }
  }
}

class _EntityRows extends MapBase<String, dynamic> {
  final IndexedStore store;
  final String type;
  final Map<String, dynamic> _cache = {};
  final Set<String> _added = {}, _removed = {};
  Set<String>? _keys;
  _EntityRows(this.store, this.type, {Map<String, dynamic>? initial}) {
    if (initial != null) {
      _keys = initial.keys.toSet();
      for (final entry in initial.entries) {
        _cache[entry.key] = store.journal.wrap(entry.value, (
          'row',
          type,
          entry.key,
        ));
      }
    }
  }
  @override
  dynamic putIfAbsent(String key, dynamic Function() ifAbsent) {
    if (!containsKey(key)) this[key] = ifAbsent();
    return this[key];
  }

  @override
  bool containsKey(Object? key) {
    if (key is! String || _removed.contains(key)) return false;
    if (_keys != null) return _keys!.contains(key);
    return _cache.containsKey(key) ||
        store.database.select(
          'SELECT 1 FROM entity_records WHERE entity_type=? AND id=?',
          [type, key],
        ).isNotEmpty;
  }

  @override
  dynamic operator [](Object? key) {
    if (key is! String || _removed.contains(key)) return null;
    if (_keys != null && !_keys!.contains(key)) return null;
    if (_cache.containsKey(key)) return _cache[key];
    final rows = store.database.select(
      'SELECT payload FROM entity_records WHERE entity_type=? AND id=?',
      [type, key],
    );
    if (rows.isEmpty) return null;
    return _cache[key] = store.journal.wrap(
      jsonDecode(rows.single['payload'] as String),
      ('row', type, key),
    );
  }

  @override
  Iterable<String> get keys {
    _keys ??=
        store.database
            .select(
              'SELECT id FROM entity_records WHERE entity_type=? ORDER BY id',
              [type],
            )
            .map((row) => row['id'] as String)
            .toSet()
          ..addAll(_added)
          ..removeAll(_removed);
    return _keys!;
  }

  void _remember(String key) {
    final existed = containsKey(key), previous = this[key];
    final added = _added.contains(key), removed = _removed.contains(key);
    store.journal.record(('row', type, key), () {
      if (existed) {
        _cache[key] = previous;
        _keys?.add(key);
      } else {
        _cache.remove(key);
        _keys?.remove(key);
      }
      if (added) {
        _added.add(key);
      } else {
        _added.remove(key);
      }
      if (removed) {
        _removed.add(key);
      } else {
        _removed.remove(key);
      }
    });
  }

  @override
  void operator []=(String key, dynamic value) {
    final wrapped = store.journal.wrap(value, ('row', type, key));
    _remember(key);
    _cache[key] = wrapped;
    _added.add(key);
    _removed.remove(key);
    _keys?.add(key);
  }

  @override
  dynamic remove(Object? key) {
    if (key is! String || !containsKey(key)) return null;
    final previous = this[key];
    _remember(key);
    _cache.remove(key);
    _removed.add(key);
    _added.remove(key);
    _keys?.remove(key);
    return previous;
  }

  @override
  void clear() {
    for (final key in keys.toList()) {
      remove(key);
    }
  }

  void saved() {
    _added.clear();
    _removed.clear();
  }
}
