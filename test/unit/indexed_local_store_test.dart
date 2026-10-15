import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/core/security/local_data_failure.dart';
import 'package:vesper_mobile/database/local_store_native.dart';
import 'package:vesper_mobile/database/transaction_query.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import '../fixtures/security_fakes.dart';

void main() {
  final key = List<int>.generate(32, (index) => index);
  Map<String, dynamic> snapshot({int count = 10}) => {
    'entities': {
      'accounts': {
        'cash': {'id': 'cash', 'balance': '9007199254740993.01'},
      },
      'categories': {
        'food': {'id': 'food', 'name': 'Épicerie', 'type': 'EXPENSE'},
      },
      'transactions': {
        for (var index = 0; index < count; index++)
          'tx-$index': {
            'id': 'tx-$index',
            'account_id': 'cash',
            'category_id': 'food',
            'amount': '${index + 1}.00',
            'type': 'EXPENSE',
            'description': 'private-marker household item $index',
            'transacted_at': DateTime.utc(
              2026,
              10,
              1,
            ).add(Duration(microseconds: index)).toIso8601String(),
          },
      },
      'unknown-opaque-table': [1, 'preserve'],
    },
    'cursor': '9007199254740994',
    'outbox': [
      for (final status in ['pending', 'rejected', 'conflict', 'acknowledged'])
        {
          'id': status,
          'status': status,
          'payload': {'quantity': '1.00000001'},
        },
    ],
    'investment_command_snapshots': {
      'cash': {
        'payload': {'balance': '123.45'},
      },
    },
    'unknown': {
      'nested': [true, null, 'preserve'],
    },
  };

  Directory temporary() {
    final directory = Directory.systemTemp.createTempSync(
      'vesper-indexed-test-',
    );
    if (directory.parent.absolute.path != Directory.systemTemp.absolute.path) {
      throw StateError('Unexpected directory');
    }
    addTearDown(() => directory.deleteSync(recursive: true));
    return directory;
  }

  test('indexed native store preserves all exact values and writes only changed rows', () {
    final path = '${temporary().path}${Platform.pathSeparator}indexed.sqlite';
    final store = LocalStore.indexed(
      sqlite3.open(path),
      key: key,
      userId: 'user',
    );
    final original = snapshot(count: 1000);
    store.write(original);
    final repo = FinanceRepository(ApiClient(), store, 'user');
    store.database.execute('CREATE TABLE audit(id TEXT)');
    store.database.execute(
      'CREATE TRIGGER audit_rows AFTER UPDATE ON entity_records BEGIN INSERT INTO audit VALUES(new.id); END',
    );
    repo.atomic(() {
      repo.entities['transactions']['tx-500']['description'] = 'edited';
      repo.entities['accounts']['cash']['balance'] = '9007199254740992.00';
      repo.outbox[0]['payload']['quantity'] = '2.00000000';
      repo.state['cursor'] = '9007199254740995';
    });
    expect(store.database.select('SELECT * FROM audit'), hasLength(2));
    expect(repo.state['unknown'], original['unknown']);
    final committed = jsonDecode(jsonEncode(repo.state));
    store.close();
    final reopened = LocalStore.indexed(
      sqlite3.open(path),
      key: key,
      userId: 'user',
    );
    expect(reopened.read(), committed);
    reopened.close();
    for (final suffix in ['', '-wal', '-shm']) {
      final file = File('$path$suffix');
      if (file.existsSync()) {
        expect(
          latin1.decode(file.readAsBytesSync()),
          isNot(contains('private-marker')),
        );
      }
    }
  });

  test('failed multi-row/outbox commit rolls back nested maps, lists, balances and disk together', () {
    final store = LocalStore.indexed(
      sqlite3.open('${temporary().path}${Platform.pathSeparator}case.sqlite'),
      key: key,
      userId: 'user',
    );
    addTearDown(store.close);
    final original = snapshot();
    store.write(original);
    final repo = FinanceRepository(ApiClient(), store, 'user');
    store.database.execute(
      "CREATE TRIGGER fail_outbox BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT, 'disk full'); END",
    );
    expect(
      () => repo.atomic(() {
        repo.entities['transactions'].remove('tx-0');
        repo.entities['transactions']['tx-1']['description'] = 'changed';
        repo.entities['accounts']['cash']['balance'] = '0.00';
        repo.outbox.removeWhere((item) => item['status'] == 'pending');
        repo.outbox.add({'id': 'new', 'status': 'pending'});
        repo.state['unknown']['nested'].insert(1, 'changed');
        repo.state.remove('investment_command_snapshots');
        repo.state['cursor'] = '0';
      }),
      throwsA(isA<SqliteException>()),
    );
    expect(repo.state, original);
    expect(
      store.database
          .select(
            "SELECT json_extract(payload,'\$.balance') AS balance FROM entity_records WHERE id='cash'",
          )
          .single['balance'],
      '9007199254740993.01',
    );
    store.database.execute('DROP TRIGGER fail_outbox');
    repo.atomic(
      () => repo.entities['transactions']['tx-1']['description'] = 'retry',
    );
    expect(repo.entities['transactions']['tx-1']['description'], 'retry');
  });

  test('bounded keyset queries preserve microsecond ordering, filters, tombstones and Unicode search', () {
    final store = LocalStore.indexed(
      sqlite3.open('${temporary().path}${Platform.pathSeparator}case.sqlite'),
      key: key,
      userId: 'user',
    );
    addTearDown(store.close);
    store.write(snapshot(count: 205));
    final first = store.transactionPage(const TransactionQuery());
    expect(first.rows, hasLength(100));
    expect(first.rows.first['id'], 'tx-204');
    final second = store.transactionPage(TransactionQuery(after: first.next));
    final third = store.transactionPage(TransactionQuery(after: second.next));
    expect(second.rows, hasLength(100));
    expect(third.rows, hasLength(5));
    expect(third.next, isNull);
    expect(
      {
        ...first.rows,
        ...second.rows,
        ...third.rows,
      }.map((row) => row['id']).toSet(),
      hasLength(205),
    );
    expect(
      store.transactionPage(const TransactionQuery(search: 'épicerie')).rows,
      hasLength(100),
    );
    expect(
      store.transactionPage(const TransactionQuery(search: '%')).rows,
      isEmpty,
    );
    expect(
      store.transactionPage(const TransactionQuery(accountId: 'other')).rows,
      isEmpty,
    );
    expect(
      store.transactionPage(const TransactionQuery(type: 'INCOME')).rows,
      isEmpty,
    );
    expect(
      store
          .transactionPage(TransactionQuery(start: DateTime.utc(2026, 11)))
          .rows,
      isEmpty,
    );
    store.atomicState(
      () => store.read()['entities']['transactions']['tx-204']['deleted_at'] =
          '2026-10-15T00:00:00.000Z',
    );
    expect(
      store.transactionPage(const TransactionQuery()).rows.first['id'],
      'tx-203',
    );
  });

  test('migration retains original source and resumes after failed activation without losing outbox', () async {
    final directory = temporary();
    final legacy = LocalStore(
      sqlite3.open(
        '${directory.path}${Platform.pathSeparator}vesper-user.sqlite',
      ),
    );
    final original = snapshot();
    legacy.write(original);
    legacy.close();
    final security = MemorySecurityStorage();
    await expectLater(
      LocalStore.openInDirectory(
        'user',
        directory.path,
        storage: security,
        beforeActivate: () async => throw StateError('interrupted'),
      ),
      throwsA(isA<LocalDataFailure>()),
    );
    expect(security.values['vesper.storage-version.v1.user'], isNull);
    expect(
      File('${directory.path}${Platform.pathSeparator}vesper-user.sqlite')
          .existsSync(),
      isTrue,
    );
    final migrated = await LocalStore.openInDirectory(
      'user',
      directory.path,
      storage: security,
    );
    expect(migrated.isIndexed, isTrue);
    expect(migrated.read(), original);
    migrated.atomicState(() => migrated.read()['cursor'] = '9007199254740995');
    migrated.close();
    final restarted = await LocalStore.openInDirectory(
      'user',
      directory.path,
      storage: security,
    );
    expect(restarted.read()['cursor'], '9007199254740995');
    expect(restarted.read()['outbox'], original['outbox']);
    restarted.close();
    final persisted = Map.of(security.values);
    security.values.remove('vesper.snapshot-key.v1.user');
    await expectLater(
      LocalStore.openInDirectory('user', directory.path, storage: security),
      throwsA(isA<LocalDataFailure>()),
    );
    expect(security.values.containsKey('vesper.snapshot-key.v1.user'), isFalse);
    security.values.addAll(persisted);
    final restored = await LocalStore.openInDirectory(
      'user',
      directory.path,
      storage: security,
    );
    expect(restored.read()['cursor'], '9007199254740995');
    restored.close();
  });

  test('month totals use exact cents and update after edits, deletes and failed commits', () {
    final store = LocalStore.indexed(
      sqlite3.open(
        '${temporary().path}${Platform.pathSeparator}summary.sqlite',
      ),
      key: key,
      userId: 'user',
    );
    addTearDown(store.close);
    final original = snapshot(count: 0);
    original['entities']['transactions'] = {
      'income': {
        'id': 'income',
        'amount': '9007199254740993.01',
        'type': 'INCOME',
        'transacted_at': '2026-10-02T12:00:00Z',
      },
      'expense': {
        'id': 'expense',
        'amount': '1.02',
        'type': 'EXPENSE',
        'transacted_at': '2026-10-02T12:00:00Z',
      },
      'transfer': {
        'id': 'transfer',
        'amount': '-25.00',
        'type': 'TRANSFER',
        'transacted_at': '2026-10-02T12:00:00Z',
      },
    };
    store.write(original);
    final repo = FinanceRepository(ApiClient(), store, 'user');
    TransactionSummary summary() => store.transactionSummary(
      DateTime.utc(2026, 10),
      DateTime.utc(2026, 11),
    );
    expect(summary().income, '9007199254740993.01');
    expect(summary().expense, '1.02');
    expect(summary().dailyNet[2], '9007199254740991.99');
    repo.atomic(
      () => repo.entities['transactions']['expense']['amount'] = '2.03',
    );
    expect(summary().expense, '2.03');
    repo.atomic(
      () => repo.entities['transactions']['income']['transacted_at'] =
          '2026-11-02T12:00:00Z',
    );
    expect(summary().income, '0.00');
    store.database.execute(
      "CREATE TRIGGER fail_summary BEFORE UPDATE ON store_info BEGIN SELECT RAISE(ABORT, 'disk'); END",
    );
    expect(
      () => repo.atomic(
        () => repo.entities['transactions']['expense']['amount'] = '99.99',
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(summary().expense, '2.03');
    store.database.execute('DROP TRIGGER fail_summary');
    repo.atomic(() => repo.entities['transactions'].remove('expense'));
    expect(summary().expense, '0.00');
    expect(summary().dailyNet[2], '0.00');
    repo.atomic(
      () => repo.entities['transactions'] = {
        'replacement': original['entities']['transactions']['expense'],
      },
    );
    expect(summary().expense, '1.02');
  });

  test('wrong owner, wrong key and stale concurrent writer preserve committed data', () {
    final path =
        '${temporary().path}${Platform.pathSeparator}concurrent.sqlite';
    final first = LocalStore.indexed(
      sqlite3.open(path),
      key: key,
      userId: 'user',
    );
    first.write(snapshot());
    final second = LocalStore.indexed(
      sqlite3.open(path),
      key: key,
      userId: 'user',
    );
    final repo = FinanceRepository(ApiClient(), second, 'user');
    first.atomicState(() => first.read()['cursor'] = '123');
    expect(
      () => repo.atomic(() => repo.state['cursor'] = '999'),
      throwsStateError,
    );
    expect(repo.state['cursor'], '9007199254740994');
    second.close();
    first.close();
    for (final wrong in [false, true]) {
      final database = sqlite3.open(path);
      try {
        expect(
          () => LocalStore.indexed(
            database,
            key: wrong ? List.filled(32, 99) : key,
            userId: wrong ? 'user' : 'other',
          ),
          throwsA(anything),
        );
      } finally {
        database.close();
      }
    }
    final verified = LocalStore.indexed(
      sqlite3.open(path),
      key: key,
      userId: 'user',
    );
    expect(verified.read()['cursor'], '123');
    verified.close();
  });

  test('activation detects a legacy writer and retains both copies', () async {
    final directory = temporary();
    final security = MemorySecurityStorage();
    final legacyPath =
        '${directory.path}${Platform.pathSeparator}vesper-user.sqlite';
    final legacy = LocalStore(sqlite3.open(legacyPath));
    legacy.write(snapshot());
    legacy.close();
    await expectLater(
      LocalStore.openInDirectory(
        'user',
        directory.path,
        storage: security,
        beforeActivate: () async {
          final writer = sqlite3.open(legacyPath);
          try {
            writer.execute(
              "UPDATE state SET payload=payload||'changed' WHERE id=1",
            );
          } finally {
            writer.close();
          }
        },
      ),
      throwsA(isA<LocalDataFailure>()),
    );
    expect(security.values['vesper.storage-version.v1.user'], isNull);
    expect(File(legacyPath).existsSync(), isTrue);
    expect(
      File('${directory.path}${Platform.pathSeparator}vesper-user.v3.sqlite')
          .existsSync(),
      isTrue,
    );
  });

  test(
    'active pointer with a missing destination never replays the old outbox',
    () async {
      final directory = temporary();
      final security = MemorySecurityStorage();
      final store = await LocalStore.openInDirectory(
        'user',
        directory.path,
        storage: security,
      );
      store.write(snapshot());
      store.close();
      final destination = File(
        '${directory.path}${Platform.pathSeparator}vesper-user.v3.sqlite',
      );
      final retained = File('${destination.path}.retained');
      destination.renameSync(retained.path);
      await expectLater(
        LocalStore.openInDirectory('user', directory.path, storage: security),
        throwsA(isA<LocalDataFailure>()),
      );
      expect(destination.existsSync(), isFalse);
      retained.renameSync(destination.path);
      final recovered = await LocalStore.openInDirectory(
        'user',
        directory.path,
        storage: security,
      );
      expect(recovered.read()['outbox'], snapshot()['outbox']);
      recovered.close();
    },
  );
}
