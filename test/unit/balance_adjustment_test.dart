import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/accounts/models/balance_adjustment.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

class TestClient extends ApiClient {
  bool rejectCategory = false;
  bool failPush = false;
  Completer<void>? registration;
  final List<List<dynamic>> batches = [];
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    if (path == '/devices') {
      await registration?.future;
      return {};
    }
    if (path == '/sync/push') {
      final items = body!['items'] as List;
      batches.add(items);
      if (failPush) throw const ApiFailure('Server sementara tidak tersedia.');
      return {
        'results': [
          for (var i = 0; i < items.length; i++)
            {
              'index': i,
              'status':
                  rejectCategory && items[i]['entity_type'] == 'categories'
                  ? 'rejected'
                  : 'applied',
            },
        ],
      };
    }
    if (path == '/sync/pull') {
      return {
        'changes': [
          {
            'entity_type': 'accounts',
            'entity_id': 'account',
            'operation': 'UPDATE',
            'payload': {
              'id': 'account',
              'user_id': 'user',
              'balance': '1000000.00',
            },
          },
        ],
        'next_version': '1',
        'has_more': false,
      };
    }
    throw StateError(path);
  }

  @override
  Future<List<Map<String, dynamic>>> list(
    String path, {
    Map<String, dynamic>? query,
  }) async => [
    {'id': 'account', 'user_id': 'user', 'balance': '1000000.00'},
  ];
}

void main() {
  late LocalStore store;
  late FinanceRepository repo;
  late AppState state;
  late TestClient client;
  setUp(() {
    store = LocalStore(sqlite3.openInMemory());
    client = TestClient();
    repo = FinanceRepository(client, store, 'user');
    repo.atomic(() {
      repo.entities['accounts'] = <String, dynamic>{
        'account': <String, dynamic>{
          'id': 'account',
          'name': 'Cash',
          'user_id': 'user',
          'balance': '1000000.00',
        },
      };
    });
    state = AppState(repository: repo)..currentUserId = 'user';
    state.toggleOfflineMode();
  });
  tearDown(() {
    state.dispose();
    store.close();
  });

  test(
    'Increase is income, decrease is expense and categories reuse by type',
    () {
      state.adjustAccountBalance('account', 2000000);
      expect(repo.rows('transactions').single['type'], 'INCOME');
      expect(repo.rows('transactions').single['amount'], '1000000.00');
      state.adjustAccountBalance('account', 1000000);
      state.adjustAccountBalance('account', 500000);
      final expenses = repo
          .rows('transactions')
          .where((r) => r['type'] == 'EXPENSE')
          .toList();
      expect(expenses.last['amount'], '500000.00');
      expect(expenses.first['category_id'], expenses.last['category_id']);
      expect(repo.rows('categories'), hasLength(2));
      expect(repo.rows('accounts').single['balance'], '500000.00');
      expect(store.read(), repo.state);
    },
  );
  test(
    'Adjustment payload matches the strict backend transaction contract',
    () {
      state.adjustAccountBalance('account', 2000000);
      final payload = repo.outbox.last['payload'] as Map;
      expect(payload.keys.toSet(), {
        'account_id',
        'category_id',
        'type',
        'amount',
        'transacted_at',
        'description',
      });
      expect(
        payload['transacted_at'],
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$')),
      );
      expect(payload['category_id'], repo.rows('categories').single['id']);
      expect(state.transactions.single.ledgerAmount, 1000000);
      expect(state.transactions.single.categoryName, 'Lainnya');
    },
  );
  test('Transient push failure stays pending and retries category before transaction', () async {
    state.adjustAccountBalance('account', 2000000);
    repo.offline = false;
    client.failPush = true;
    await expectLater(repo.sync(), throwsA(isA<ApiFailure>()));
    expect(repo.isSyncing, false);
    expect(repo.outbox.map((item) => item['status']), ['pending', 'pending']);
    expect(repo.outbox.first['attempts'], 1);
    expect(repo.outbox.last['attempts'], 0);
    expect(repo.row('accounts', 'account')!['balance'], '2000000.00');
    expect(store.read(), repo.state);
    client.failPush = false;
    await repo.sync();
    expect(client.batches.map((batch) => batch.single['entity_type']), [
      'categories',
      'categories',
      'transactions',
    ]);
    expect(repo.outbox, isEmpty);
  });
  test('Zero is no op, negative target allowed', () {
    final before = jsonEncode(repo.state);
    expect(state.adjustAccountBalance('account', 1000000), false);
    expect(jsonEncode(repo.state), before);
    state.adjustAccountBalance('account', -500000);
    expect(repo.rows('transactions').single['amount'], '1500000.00');
    expect(repo.rows('accounts').single['balance'], '-500000.00');
  });
  test(
    'Pending local delta is included; no direct account update is queued',
    () {
      state.adjustAccountBalance('account', 2000000);
      state.adjustAccountBalance('account', 2500000, expectedBalance: 2000000);
      expect(repo.rows('transactions').last['amount'], '500000.00');
      expect(repo.outbox.where((e) => e['entity_type'] == 'accounts'), isEmpty);
      expect(repo.rows('categories').single['name'], 'Lainnya');
    },
  );
  test('Stale preview, missing account, failed ledger and pending account edit reject atomically', () {
    final before = jsonEncode(repo.state);
    expect(
      () => state.adjustAccountBalance('account', 2000000, expectedBalance: 0),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => state.adjustAccountBalance('missing', 2000000),
      throwsA(isA<ApiFailure>()),
    );
    expect(jsonEncode(repo.state), before);
    state.adjustAccountBalance('account', 2000000);
    repo.outbox.last['status'] = 'conflict';
    final conflicted = jsonEncode(repo.state);
    expect(
      () => state.adjustAccountBalance('account', 3000000),
      throwsA(isA<ApiFailure>()),
    );
    expect(jsonEncode(repo.state), conflicted);
    repo.outbox.clear();
    repo.outbox.add({
      'entity_type': 'accounts',
      'entity_id': 'account',
      'status': 'pending',
    });
    expect(
      () => state.adjustAccountBalance('account', 3000000),
      throwsA(isA<ApiFailure>()),
    );
  });
  test('Loading blocks writes; integer safe limit remains exact', () {
    state.loading = true;
    expect(
      () => state.adjustAccountBalance('account', 2000000),
      throwsA(isA<ApiFailure>()),
    );
    expect(repo.outbox, isEmpty);
    state.loading = false;
    state.adjustAccountBalance('account', maxSafeRupiah);
    expect(repo.row('accounts', 'account')!['balance'], '$maxSafeRupiah.00');
    expect(
      repo.rows('transactions').single['amount'],
      '${maxSafeRupiah - 1000000}.00',
    );
  });
  test('Foreign owner is rejected without mutation', () {
    repo.atomic(() {
      (repo.entities['accounts'] as Map)['account']['user_id'] = 'other';
    });
    expect(
      () => state.adjustAccountBalance('account', 2000000),
      throwsA(isA<ApiFailure>()),
    );
    expect(repo.outbox, isEmpty);
  });
  test('Safe integer target and difference bounds', () {
    expect(parseAdjustmentTarget('-9007199254740991'), -maxSafeRupiah);
    for (final text in ['9007199254740992', '1.5', '1e6', '1,000']) {
      expect(() => parseAdjustmentTarget(text), throwsA(isA<ApiFailure>()));
    }
    expect(
      () => adjustmentDifference(-maxSafeRupiah, maxSafeRupiah),
      throwsA(isA<ApiFailure>()),
    );
  });
  test(
    'Exact-name fallback is deterministic; stored identity survives rename',
    () {
      repo.atomic(() {
        repo.entities['categories'] = {
          for (final id in ['b', 'a'])
            id: {
              'id': id,
              'name': 'Lainnya',
              'type': 'INCOME',
              'user_id': 'user',
            },
        };
      });
      state.adjustAccountBalance('account', 2000000);
      expect(repo.rows('transactions').single['category_id'], 'a');
      repo.atomic(() {
        (repo.entities['categories'] as Map)['a']['name'] = 'Renamed';
      });
      state.adjustAccountBalance('account', 3000000);
      expect(repo.rows('transactions').last['category_id'], 'a');
      expect(repo.rows('categories'), hasLength(2));
    },
  );
  test(
    'Persistence failure rolls back categories, identity, balance and outbox',
    () {
      final before = jsonEncode(repo.state);
      store.database.execute(
        "CREATE TRIGGER fail_save BEFORE UPDATE ON state BEGIN SELECT RAISE(ABORT, 'fail'); END",
      );
      expect(
        () => state.adjustAccountBalance('account', 2000000),
        throwsA(anything),
      );
      expect(jsonEncode(repo.state), before);
      expect(jsonEncode(store.read()), before);
    },
  );
  test(
    'Active sync blocks adjustment until account snapshot is settled',
    () async {
      client.registration = Completer<void>();
      repo.offline = false;
      final syncing = repo.sync();
      expect(repo.isSyncing, true);
      expect(
        () => state.adjustAccountBalance('account', 2000000),
        throwsA(isA<ApiFailure>()),
      );
      expect(repo.outbox, isEmpty);
      client.registration!.complete();
      await syncing;
      expect(repo.isSyncing, false);
    },
  );
  test('Seeded expense default is reused and transfer ledger is untouched', () {
    repo.atomic(() {
      repo.entities['categories'] = <String, dynamic>{
        'expense-default': <String, dynamic>{
          'id': 'expense-default',
          'name': 'Lain-lain',
          'type': 'EXPENSE',
          'user_id': 'user',
        },
      };
      repo.entities['transactions'] = <String, dynamic>{
        'transfer': <String, dynamic>{
          'id': 'transfer',
          'type': 'TRANSFER',
          'account_id': 'account',
          'amount': '-100.00',
          'transfer_id': 'linked',
        },
      };
    });
    final transfer = repo.row('transactions', 'transfer');
    state.adjustAccountBalance('account', 500000);
    expect(repo.row('transactions', 'transfer'), transfer);
    expect(repo.rows('transactions').last['category_id'], 'expense-default');
    expect(repo.rows('categories'), hasLength(1));
    expect(repo.outbox.single['entity_type'], 'transactions');
    repo.atomic(() {
      (repo.entities['accounts'] as Map)['account']['deleted_at'] =
          '2026-10-11T00:00:00Z';
    });
    final before = jsonEncode(repo.state);
    expect(
      () => state.adjustAccountBalance('account', 400000),
      throwsA(isA<ApiFailure>()),
    );
    expect(jsonEncode(repo.state), before);
  });
  test('Rejected category blocks transaction, refresh and pull retain pending delta', () async {
    state.adjustAccountBalance('account', 2000000);
    final transactionId = repo.rows('transactions').single['id'];
    client.rejectCategory = true;
    repo.offline = false;
    await repo.sync();
    expect(client.batches, hasLength(1));
    expect(client.batches.single.single['entity_type'], 'categories');
    expect(repo.rows('accounts').single['balance'], '2000000.00');
    await repo.refreshList('accounts', '/accounts');
    expect(repo.rows('accounts').single['balance'], '2000000.00');
    repo.atomic(() {
      repo.outbox.first['status'] = 'pending';
    });
    client.rejectCategory = false;
    await repo.sync();
    expect(client.batches.last.single['entity_id'], transactionId);
    expect(client.batches[1].single['entity_type'], 'categories');
    expect(repo.outbox, isEmpty);
  });
}
