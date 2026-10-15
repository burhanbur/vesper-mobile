import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';
import 'package:vesper_mobile/features/transactions/models/transaction.dart';

class TransferClient extends ApiClient {
  bool loseResponse = true;
  String status = 'applied';
  bool wrongId = false;
  bool emptyPull = false;
  final List<String> deliveries = [];
  Map<String, dynamic>? command;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    if (path == '/devices') return {};
    if (path == '/sync/push') {
      final items = body!['items'] as List;
      expect(items, hasLength(1));
      command = Map<String, dynamic>.from(items.single as Map);
      deliveries.add(jsonEncode(command));
      if (loseResponse) throw const ApiFailure('Lost response');
      return {
        'results': [
          {
            'index': 0,
            'entity_id': wrongId ? 'wrong' : command!['entity_id'],
            'status': status,
            'server_data': status == 'applied'
                ? {
                    'id': command!['entity_id'],
                    ...command!['payload'] as Map,
                    'version': '8',
                  }
                : null,
          },
        ],
      };
    }
    if (path == '/sync/pull') {
      if (emptyPull || query?['since_version'] == '2') {
        return {'changes': [], 'next_version': '2', 'has_more': false};
      }
      final payload = command!['payload'] as Map;
      final second = query!['since_version'] == '1';
      return {
        'changes': [
          for (final account in ['from', 'to'])
            {
              'entity_type': 'accounts',
              'entity_id': account,
              'operation': 'UPDATE',
              'version': '999',
              'payload': {
                'id': account,
                'currency': 'IDR',
                'balance': account == 'from' ? '75.00' : '45.00',
                'version': '7',
              },
            },
          {
            'entity_type': 'transactions',
            'entity_id':
                payload[second ? 'to_transaction_id' : 'from_transaction_id'],
            'operation': 'CREATE',
            'payload': {
              'id':
                  payload[second ? 'to_transaction_id' : 'from_transaction_id'],
              'account_id': second ? 'to' : 'from',
              'type': 'TRANSFER',
              'amount': second ? '25.00' : '-25.00',
              'transfer_id': command!['entity_id'],
              'transacted_at': payload['transacted_at'],
              'version': '9',
            },
          },
        ],
        'next_version': second ? '2' : '1',
        'has_more': !second,
      };
    }
    throw StateError(path);
  }

  @override
  Future<List<Map<String, dynamic>>> list(
    String path, {
    Map<String, dynamic>? query,
  }) async => [];
}

class PartialTransferClient extends ApiClient {
  bool pullRequested = false;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    if (path == '/devices') return {};
    if (path == '/sync/push') {
      final items = body!['items'] as List;
      expect(items, hasLength(2));
      return {
        'results': [
          {
            'index': 0,
            'entity_id': items.first['entity_id'],
            'status': 'applied',
          },
        ],
      };
    }
    pullRequested = true;
    throw StateError('Incomplete acknowledgement must stop before pull: $path');
  }
}

void main() {
  late LocalStore store;
  late FinanceRepository repo;
  late TransferClient client;
  final date = DateTime.utc(2026, 10, 15, 10, 0, 0, 123, 456);
  String create({int amount = 25, String to = 'to', String? note}) =>
      repo.createTransfer(
        fromAccountId: 'from',
        toAccountId: to,
        amount: amount,
        date: date,
        description: note,
      );
  setUp(() {
    store = LocalStore(sqlite3.openInMemory());
    client = TransferClient();
    repo = FinanceRepository(client, store, 'user');
    repo.atomic(() {
      repo.entities['accounts'] = {
        for (final id in ['from', 'to'])
          id: {
            'id': id,
            'name': id,
            'user_id': 'user',
            'currency': 'IDR',
            'balance': id == 'from' ? '100.00' : '20.00',
            'version': '1',
          },
      };
    });
  });
  tearDown(() => store.close());

  test(
    'offline state creates one durable command and paired signed ledgers',
    () {
      final state = AppState(repository: repo)..currentUserId = 'user';
      state.toggleOfflineMode();
      state.addTransaction(
        type: TransactionType.transfer,
        amount: 25,
        accountId: 'from',
        toAccountId: 'to',
        categoryName: '',
        date: date,
      );
      expect(repo.outbox, hasLength(1));
      final item = repo.outbox.single as Map;
      expect(item['entity_type'], 'transfers');
      expect(item['operation'], 'CREATE');
      expect(item['client_version'], '0');
      final p = item['payload'] as Map;
      expect(p.keys.toSet(), {
        'from_account_id',
        'to_account_id',
        'from_transaction_id',
        'to_transaction_id',
        'amount',
        'transacted_at',
        'description',
      });
      expect({
        item['entity_id'],
        p['from_transaction_id'],
        p['to_transaction_id'],
      }, hasLength(3));
      expect(p['transacted_at'], '2026-10-15T10:00:00.123Z');
      expect(repo.rows('transactions').map((r) => r['amount']), [
        '-25.00',
        '25.00',
      ]);
      expect(
        state.transactions.every((t) => t.syncStatus == SyncStatus.pending),
        true,
      );
      expect(repo.row('accounts', 'from')!['balance'], '75.00');
      expect(repo.row('accounts', 'to')!['balance'], '45.00');
      expect(store.read(), repo.state);
      state.dispose();
    },
  );

  test('SQLite failure rolls back command, both rows, balances and memory', () {
    final before = jsonEncode(repo.state);
    store.database.execute(
      "CREATE TRIGGER fail_save BEFORE UPDATE ON state BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
    );
    expect(create, throwsA(isA<SqliteException>()));
    expect(jsonEncode(repo.state), before);
    expect(store.read(), repo.state);
    store.database.execute('DROP TRIGGER fail_save');
    create();
    expect(repo.outbox, hasLength(1));
    expect(repo.rows('transactions'), hasLength(2));
  });

  test('lost response and restart replay identical IDs; split pulls upsert without double balance', () async {
    create(note: '  savings  ');
    await expectLater(repo.sync(), throwsA(isA<ApiFailure>()));
    expect(repo.outbox.single['attempts'], 1);
    repo = FinanceRepository(client, store, 'user');
    // A list refresh after a lost acknowledgement must preserve both legs/balances.
    await repo.refreshList('transactions', '/transactions');
    await repo.refreshList('accounts', '/accounts');
    expect(repo.rows('transactions'), hasLength(2));
    expect(repo.row('accounts', 'from')!['balance'], '75.00');
    client.loseResponse = false;
    await repo.sync();
    expect(client.deliveries[0], client.deliveries[1]);
    expect(repo.outbox, isEmpty);
    expect(repo.rows('transactions'), hasLength(2));
    expect(repo.row('accounts', 'from')!['balance'], '75.00');
    expect(repo.row('accounts', 'to')!['balance'], '45.00');
    expect(repo.row('accounts', 'from')!['version'], '7');
    expect(repo.state['cursor'], '2');
    await repo.sync();
    expect(repo.rows('transactions'), hasLength(2));
    expect(repo.row('accounts', 'to')!['balance'], '45.00');
  });

  test('conflicts retain command and cannot be rebased or discarded as a single leg', () async {
    create();
    client
      ..loseResponse = false
      ..status = 'conflict';
    await repo.sync();
    expect(repo.outbox.single['status'], 'conflict');
    expect(repo.row('accounts', 'from')!['balance'], '75.00');
    for (final mine in [true, false]) {
      expect(
        () => repo.resolve(repo.outbox.single['id'] as String, useMine: mine),
        throwsA(isA<ApiFailure>()),
      );
    }
    expect(repo.outbox, hasLength(1));
  });

  test('pull is not acknowledgement; later replay restores balances past consumed pages', () async {
    create();
    client
      ..loseResponse = false
      ..status = 'rejected';
    await repo.sync();
    expect(repo.outbox, hasLength(1));
    expect(repo.state['cursor'], '2');
    repo = FinanceRepository(client, store, 'user');
    // Explicit retry preserves the immutable CREATE/0 command, not a rebase.
    repo.atomic(() => repo.outbox.single['status'] = 'pending');
    client.status = 'applied';
    await repo.sync();
    expect(repo.outbox, isEmpty);
    expect(repo.rows('transactions'), hasLength(2));
    expect(repo.row('accounts', 'from')!['balance'], '75.00');
    expect(client.deliveries[0], client.deliveries[1]);
  });

  test('pull page persistence failure rolls back page and cursor', () async {
    create();
    client.loseResponse = false;
    // Ack persists first; a trigger fails only when a page advances the cursor.
    store.database.execute(
      "CREATE TRIGGER fail_page BEFORE UPDATE ON state WHEN json_extract(NEW.payload, '\$.cursor') = '1' BEGIN SELECT RAISE(ABORT, 'page failure'); END",
    );
    await expectLater(repo.sync(), throwsA(isA<SqliteException>()));
    expect(repo.state['cursor'], '0');
    expect(store.read(), repo.state);
    expect(repo.rows('transactions'), hasLength(2));
    store.database.execute('DROP TRIGGER fail_page');
    await repo.sync();
    expect(repo.state['cursor'], '2');
  });

  test('mismatched acknowledgement cannot remove durable command', () async {
    create();
    client
      ..loseResponse = false
      ..wrongId = true;
    await expectLater(repo.sync(), throwsA(isA<ApiFailure>()));
    expect(repo.outbox, hasLength(1));
    expect(store.read(), repo.state);
  });

  test('incomplete push acknowledgement rolls back all removals and survives restart', () async {
    create();
    create(amount: 10);
    final partialClient = PartialTransferClient();
    repo = FinanceRepository(partialClient, store, 'user');
    final commands = jsonEncode(repo.outbox);
    final ledgers = jsonEncode(repo.rows('transactions'));
    await expectLater(repo.sync(), throwsA(isA<ApiFailure>()));
    expect(jsonEncode(repo.outbox), commands);
    expect(jsonEncode(repo.rows('transactions')), ledgers);
    expect(repo.row('accounts', 'from')!['balance'], '65.00');
    expect(repo.row('accounts', 'to')!['balance'], '55.00');
    expect(repo.state['cursor'], '0');
    expect(partialClient.pullRequested, false);
    expect(store.read(), repo.state);
    repo = FinanceRepository(partialClient, store, 'user');
    expect(jsonEncode(repo.outbox), commands);
    expect(repo.rows('transactions'), hasLength(4));
  });

  test('invalid amounts, accounts, currencies and notes make no writes', () {
    final before = jsonEncode(repo.state);
    for (final amount in [0, -1, 9007199254740992]) {
      expect(() => create(amount: amount), throwsA(isA<ApiFailure>()));
    }
    for (final to in ['from', 'missing']) {
      expect(() => create(to: to), throwsA(isA<ApiFailure>()));
    }
    expect(() => create(note: 'x' * 5001), throwsA(isA<ApiFailure>()));
    expect(jsonEncode(repo.state), before);
    for (final patch in [
      {'currency': 'USD'},
      {'deleted_at': 'deleted'},
      {'balance': '20.50'},
    ]) {
      repo.entities['accounts']['to'].addAll(patch);
      expect(create, throwsA(isA<ApiFailure>()));
      repo.entities['accounts']['to'] = {
        'id': 'to',
        'currency': 'IDR',
        'balance': '20.00',
      };
    }
    expect(repo.outbox, isEmpty);
  });

  test('negative balances allowed and direct transfer leg writes rejected', () {
    create(amount: 125);
    expect(repo.row('accounts', 'from')!['balance'], '-25.00');
    final id = repo.rows('transactions').first['id'] as String;
    expect(
      () => repo.mutate('transactions', 'DELETE', null, id: id),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () => repo.mutate('transactions', 'CREATE', {'type': 'TRANSFER'}),
      throwsA(isA<ApiFailure>()),
    );
  });
}
