import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/dart.dart';

import 'snapshot_cipher.dart';
import 'snapshot_key_store.dart';
import '../core/security/local_data_failure.dart';
import 'indexed_store_native.dart';
import 'transaction_query.dart';

/// A user-scoped SQLite snapshot and transactional outbox. No credentials.
class LocalStore {
  final Database database;
  final SnapshotCipher? cipher;
  final IndexedStore? _indexed;
  int _legacyRevision = 0;
  LocalStore(this.database, {this.cipher}) : _indexed = null {
    database.execute('PRAGMA secure_delete=ON');
    database.execute('PRAGMA temp_store=MEMORY');
    database.execute('PRAGMA synchronous=FULL');
    database.execute('PRAGMA journal_mode=WAL');
    database.execute(
      'CREATE TABLE IF NOT EXISTS state (id INTEGER PRIMARY KEY CHECK(id=1), payload TEXT NOT NULL)',
    );
    if (cipher != null) _migrateEncryption();
  }

  LocalStore._indexed(IndexedStore store)
    : database = store.database,
      cipher = null,
      _indexed = store;

  factory LocalStore.indexed(
    Database database, {
    required List<int> key,
    required String userId,
  }) => LocalStore._indexed(IndexedStore(database, key, userId));

  bool get isIndexed => _indexed != null;
  int get revision => _indexed?.revision ?? _legacyRevision;
  void atomicState(void Function() action) => _indexed!.atomic(action);
  TransactionPage transactionPage(TransactionQuery query) =>
      _indexed!.transactionPage(query);
  TransactionSummary transactionSummary(DateTime start, DateTime end) =>
      _indexed!.transactionSummary(start, end);

  static final Map<String, Future<void>> _opening = {};

  static Future<LocalStore> open(String userId) async {
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(userId)) {
      throw ArgumentError('Invalid user ID');
    }
    final directory = await getApplicationSupportDirectory();
    return openInDirectory(userId, directory.path);
  }

  /// Injectable directory/storage keep migration failure tests off real data.
  static Future<LocalStore> openInDirectory(
    String userId,
    String directoryPath, {
    FlutterSecureStorage storage = const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
    Future<void> Function()? beforeActivate,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(userId)) {
      throw ArgumentError('Invalid user ID');
    }
    final gate = Completer<void>();
    final gateKey = '$directoryPath:$userId';
    final previous = _opening[gateKey];
    _opening[gateKey] = gate.future;
    if (previous != null) await previous;
    try {
      return await _openIndexed(userId, directoryPath, storage, beforeActivate);
    } catch (_) {
      throw const LocalDataFailure();
    } finally {
      gate.complete();
      if (identical(_opening[gateKey], gate.future)) _opening.remove(gateKey);
    }
  }

  static Future<LocalStore> _openIndexed(
    String userId,
    String directoryPath,
    FlutterSecureStorage storage,
    Future<void> Function()? beforeActivate,
  ) async {
    final directory = Directory(directoryPath);
    await Directory(directory.path).create(recursive: true);
    if (Platform.isIOS) {
      await const MethodChannel('vesper/storage-protection')
          .invokeMethod<void>('protect', directory.path);
    }
    final legacyPath = p.join(directory.path, 'vesper-$userId.sqlite');
    final indexedPath = p.join(directory.path, 'vesper-$userId.v3.sqlite');
    final pointerKey = 'vesper.storage-version.v1.$userId';
    final pointer = await storage.read(key: pointerKey);
    if (pointer != null && pointer != '3') {
      throw StateError('Unsupported active storage version');
    }
    if (pointer == '3' && !File(indexedPath).existsSync()) {
      throw StateError(
        'Active indexed database missing; original source retained',
      );
    }
    final database = sqlite3.open(legacyPath);
    var keyLock = false;
    late List<int> key;
    try {
      // Serialize first-key creation across handles/processes. Contention fails
      // without writing a second key; callers can retry opening this database.
      database.execute('BEGIN IMMEDIATE');
      keyLock = true;
      final exists = database
          .select(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='state'",
          )
          .isNotEmpty;
      final rows = exists
          ? database.select('SELECT payload FROM state WHERE id=1')
          : null;
      final payload = rows == null || rows.isEmpty
          ? null
          : rows.first['payload'] as String;
      final version =
          database.select('PRAGMA user_version').first.values.first as int;
      key = await SnapshotKeyStore(storage: storage).load(
        userId,
        encrypted:
            pointer != null ||
            (File(indexedPath).existsSync() &&
                File(indexedPath).lengthSync() > 0) ||
            version > 0 ||
            (payload?.startsWith(SnapshotCipher.prefix) ?? false),
      );
      database.execute('COMMIT');
      keyLock = false;
    } finally {
      if (keyLock) database.execute('ROLLBACK');
      database.close();
    }
    if (pointer == null) {
      // The expensive one-time legacy decode/validation/copy runs away from
      // the UI isolate. Activation is the only switch of authority.
      final sourceHash = await Isolate.run(
        _MigrationJob(legacyPath, indexedPath, key, userId).run,
      );
      await beforeActivate?.call();
      final sourceGuard = sqlite3.open(legacyPath);
      try {
        sourceGuard.execute('BEGIN IMMEDIATE');
        if (_legacyPayloadDigest(sourceGuard) != sourceHash) {
          throw StateError('Migration source changed before activation');
        }
        // Block a legacy writer until secure activation has completed. A writer
        // in the copy-to-activation gap is detected without losing either file.
        await storage.write(key: pointerKey, value: '3');
        if (await storage.read(key: pointerKey) != '3') {
          throw StateError('Storage activation could not be verified');
        }
      } finally {
        sourceGuard.close();
      }
    }
    final indexedDatabase = sqlite3.open(indexedPath);
    try {
      final indexed = IndexedStore(indexedDatabase, key, userId);
      if (!indexed.initialized) {
        throw StateError('Indexed database migration incomplete');
      }
      if (Platform.isIOS) {
        // Apply to sidecars created by SQLite too. Parent attributes also
        // protect sidecars subsequently recreated on this device.
        await const MethodChannel('vesper/storage-protection')
            .invokeMethod<void>('protect', directory.path);
      }
      return LocalStore._indexed(indexed);
    } catch (_) {
      indexedDatabase.close();
      rethrow;
    }
  }

  void _migrateEncryption() {
    final version =
        database.select('PRAGMA user_version').first.values.first as int;
    if (version > 2) throw StateError('Unsupported local database version');
    final rows = database.select('SELECT payload FROM state WHERE id=1');
    final payload = rows.isEmpty ? null : rows.first['payload'] as String;
    if (payload != null) {
      final encrypted = payload.startsWith(SnapshotCipher.prefix);
      if (version > 0 && !encrypted) {
        throw const FormatException('Encrypted financial snapshot expected');
      }
      // Validate before changing anything; corruption never becomes an empty DB.
      final plaintext = encrypted ? cipher!.decrypt(payload) : payload;
      if (jsonDecode(plaintext) is! Map<String, dynamic>) {
        throw const FormatException('Invalid financial snapshot');
      }
      if (version == 0) {
        final envelope = encrypted ? payload : cipher!.encrypt(plaintext);
        database.execute('BEGIN IMMEDIATE');
        try {
          database.execute('UPDATE state SET payload=? WHERE id=1', [envelope]);
          database.execute('PRAGMA user_version=1');
          database.execute('COMMIT');
        } catch (_) {
          database.execute('ROLLBACK');
          rethrow;
        }
      }
    } else if (version == 0) {
      database.execute('PRAGMA user_version=1');
    }
    if (version < 2) {
      // v1 is a durable restart checkpoint: encrypted commit is complete, but
      // old logical plaintext pages/WAL still need cleanup. Never delete files.
      _truncateWal();
      database.execute('VACUUM');
      _truncateWal();
      database.execute('PRAGMA user_version=2');
      _truncateWal();
    }
  }

  void _truncateWal() {
    if (database.select('PRAGMA wal_checkpoint(TRUNCATE)').first.values.first !=
        0) {
      throw StateError(
        'Financial data migration is busy; retry after closing other app instances',
      );
    }
  }

  Map<String, dynamic> read() {
    if (_indexed != null) return _indexed.state;
    final rows = database.select('SELECT payload FROM state WHERE id=1');
    if (rows.isEmpty) {
      return {
        'entities': <String, dynamic>{},
        'outbox': <dynamic>[],
        'cursor': '0',
      };
    }
    return Map<String, dynamic>.from(
      jsonDecode(
        cipher == null
            ? rows.first['payload'] as String
            : cipher!.decrypt(rows.first['payload'] as String),
      ) as Map,
    );
  }

  void write(Map<String, dynamic> state) {
    if (_indexed != null) {
      if (identical(state, _indexed.state)) {
        _indexed.commit();
      } else {
        _indexed.atomic(() {
          _indexed.state
            ..clear()
            ..addAll(state);
        });
      }
      return;
    }
    final json = jsonEncode(state);
    final payload = cipher?.encrypt(json) ?? json;
    database.execute('BEGIN IMMEDIATE');
    try {
      database.execute(
        'INSERT INTO state(id,payload) VALUES(1,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
        [payload],
      );
      database.execute('COMMIT');
      _legacyRevision++;
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  void close() {
    database.close();
    cipher?.dispose();
  }
}

class _MigrationJob {
  final String legacyPath, destination, userId;
  final List<int> key;
  const _MigrationJob(this.legacyPath, this.destination, this.key, this.userId);
  String run() => _migrateIndexed(legacyPath, destination, key, userId);
}

dynamic _canonicalJson(dynamic value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return <String, dynamic>{
      for (final key in keys) key: _canonicalJson(value[key]),
    };
  }
  if (value is List) return value.map(_canonicalJson).toList();
  return value;
}

String _snapshotDigest(Map<String, dynamic> value) =>
    _digest(jsonEncode(_canonicalJson(value)));

String _digest(String value) => const DartSha256()
    .hashSync(utf8.encode(value))
    .bytes
    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
    .join();

String _legacyPayloadDigest(Database database) => _digest(
  '${database.select('SELECT payload FROM state WHERE id=1').firstOrNull?['payload']}',
);

String _migrateIndexed(
  String legacyPath,
  String destination,
  List<int> key,
  String userId,
) {
  final legacyDatabase = sqlite3.open(legacyPath);
  LocalStore? legacy;
  Database? indexedDatabase;
  try {
    legacy = LocalStore(legacyDatabase, cipher: SnapshotCipher(key, userId));
    legacyDatabase.execute('BEGIN IMMEDIATE');
    final snapshot = legacy.read();
    if (snapshot['entities'] is! Map ||
        snapshot['outbox'] is! List ||
        snapshot['cursor'] is! String) {
      throw const FormatException('Invalid migration source');
    }
    final digest = _snapshotDigest(snapshot);
    indexedDatabase = sqlite3.open(destination);
    final indexed = IndexedStore(indexedDatabase, key, userId);
    indexed.importSnapshot(snapshot, digest);
    if (_snapshotDigest(indexed.state) != digest) {
      throw StateError('Indexed migration validation failed');
    }
    indexedDatabase.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    return _legacyPayloadDigest(legacyDatabase);
  } finally {
    indexedDatabase?.close();
    if (legacy != null) {
      legacy.close();
    } else {
      legacyDatabase.close();
    }
  }
}
