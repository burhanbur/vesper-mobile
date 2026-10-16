import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import '../fixtures/cached_finance.dart';

class _Client extends ApiClient {
  bool supportsCompact = true, failSync = false;
  ApiFailure? failure;
  int transactionReads = 0;
  final pulls = <Map<String, dynamic>>[];
  Map<String, dynamic> transaction(String id, String amount) => {
    'id': id,
    'account_id': 'cash',
    'category_id': 'food',
    'type': 'EXPENSE',
    'amount': amount,
    'transacted_at': '2026-10-16T00:00:00.000Z',
  };
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
    if (path == '/sync/push') throw const ApiFailure('Push interrupted');
    if (path == '/sync/pull') {
      pulls.add(Map.of(query!));
      if (!supportsCompact && query.containsKey('compact')) {
        throw const ApiFailure('Unsupported query', statusCode: 422);
      }
      if (failure != null) throw failure!;
      if (failSync) throw const ApiFailure('Pull interrupted');
      return {
        'changes': [
          {
            'entity_type': 'transactions',
            'entity_id': 'remote',
            'operation': 'UPDATE',
            'payload': transaction('remote', '15.00'),
          },
        ],
        'next_version': '1',
        'has_more': false,
      };
    }
    if (path == '/transactions') {
      transactionReads++;
      return [transaction('remote', '10.00')];
    }
    if (path == '/accounts') {
      return [
        {'id': 'cash', 'name': 'Cash', 'balance': '100.00', 'user_id': 'user'},
      ];
    }
    return [];
  }
}

void main() {
  test(
    'old strict server falls back once without changing the requested cursor',
    () async {
      final client = _Client()..supportsCompact = false;
      final state = cachedFinanceState(client: client);
      final repo = state.repository!;
      try {
        await repo.sync();
        expect(client.pulls.map((query) => query['compact']), ['true', null]);
        expect(client.pulls.map((query) => query['since_version']), ['0', '0']);
        await repo.sync();
        expect(client.pulls.last.containsKey('compact'), isFalse);
        expect(repo.row('transactions', 'remote')!['amount'], '15.00');
      } finally {
        state.dispose();
      }
    },
  );

  test('rate limits and errors from an accepted compact server do not downgrade or advance cursor', () async {
    final client = _Client();
    final state = cachedFinanceState(client: client);
    final repo = state.repository!;
    try {
      client.failure = const ApiFailure('Rate limited', statusCode: 429);
      await expectLater(repo.sync(), throwsA(isA<ApiFailure>()));
      expect(client.pulls, hasLength(1));
      expect(repo.state['cursor'], '0');
      client.failure = null;
      await repo.sync();
      client.failure = const ApiFailure('Cursor invalid', statusCode: 422);
      await expectLater(repo.sync(), throwsA(isA<ApiFailure>()));
      expect(client.pulls, hasLength(3));
      expect(client.pulls.every((query) => query['compact'] == 'true'), isTrue);
      expect(repo.state['cursor'], '1');
    } finally {
      state.dispose();
    }
  });

  testWidgets(
    'complete transaction baseline survives restart and avoids full REST reads after incremental sync',
    (tester) async {
      final client = _Client();
      final state = cachedFinanceState(client: client);
      try {
        await state.login(userId: 'user');
        expect(client.transactionReads, 1);
        expect(state.repository!.hasTransactionSnapshot, isTrue);
        state.repository = FinanceRepository(
          client,
          state.repository!.store,
          'user',
        );
        await state.refresh();
        expect(client.transactionReads, 1);
        expect(
          state.repository!.row('transactions', 'remote')!['amount'],
          '15.00',
        );
        // An incompatible/other-user marker cannot suppress the first snapshot.
        state.repository!.atomic(
          () => state.repository!.state['transaction_snapshot_coverage'] = {
            'schema': 1,
            'user_id': 'other',
            'complete': true,
          },
        );
        await state.refresh();
        expect(client.transactionReads, 2);
      } finally {
        state.dispose();
        await tester.pump();
      }
    },
  );

  testWidgets(
    'failed sync still refreshes REST baseline and retains unresolved local commands',
    (tester) async {
      final client = _Client();
      final state = cachedFinanceState(client: client);
      final repo = state.repository!;
      try {
        await state.login(userId: 'user');
        repo.atomic(() {
          repo.entities['transactions']['local'] = client.transaction(
            'local',
            '7.00',
          );
          repo.outbox.add({
            'id': 'queue',
            'entity_type': 'transactions',
            'entity_id': 'local',
            'operation': 'CREATE',
            'payload': client.transaction('local', '7.00'),
            'client_version': '0',
            'status': 'pending',
            'attempts': 0,
          });
        });
        await state.refresh();
        expect(client.transactionReads, 2);
        expect(repo.row('transactions', 'local')!['amount'], '7.00');
        expect(repo.outbox.single['entity_id'], 'local');
        expect(state.dataError, isNotNull);
      } finally {
        state.dispose();
        await tester.pump();
      }
    },
  );

  test(
    'failed snapshot persistence does not create a complete baseline marker',
    () async {
      final state = cachedFinanceState(client: _Client());
      final repo = state.repository!;
      try {
        repo.store.database.execute(
          "CREATE TRIGGER fail_snapshot BEFORE UPDATE ON state BEGIN SELECT RAISE(ABORT, 'disk full'); END",
        );
        await expectLater(
          repo.refreshList('transactions', '/transactions'),
          throwsA(isA<SqliteException>()),
        );
        expect(repo.hasTransactionSnapshot, isFalse);
        expect(repo.rows('transactions'), isEmpty);
      } finally {
        state.dispose();
      }
    },
  );
}
