import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

class HistoryFeed extends ApiClient {
  bool failLast = false;
  bool malformed = false;
  final List<String> cursors = [];

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
    if (path != '/sync/pull') throw StateError(path);
    final cursor = query!['since_version'] as String;
    cursors.add(cursor);
    if (cursor == '0') {
      return {
        'changes': [
          {
            'entity_type': 'investment_transactions',
            'entity_id': 'buy',
            'operation': 'CREATE',
            'payload': {
              'id': 'buy',
              'account_id': 'invest',
              'instrument_id': 'stock',
              'type': 'BUY',
              'quantity': '2.00000000',
              'price_per_unit': '10.00000000',
              'transacted_at': '2026-10-15T00:00:00.000Z',
              'deleted_at': null,
            },
          },
        ],
        'next_version': '1',
        'has_more': true,
      };
    }
    if (failLast) throw const ApiFailure('Connection lost');
    return {
      'changes': [],
      'next_version': '2',
      'has_more': malformed ? null : false,
    };
  }
}

void main() {
  late LocalStore store;
  late HistoryFeed feed;
  late FinanceRepository repo;
  setUp(() {
    store = LocalStore(sqlite3.openInMemory());
    feed = HistoryFeed();
    repo = FinanceRepository(feed, store, 'user');
    repo.atomic(() {
      repo.entities['account_types'] = {
        'type': {'id': 'type', 'category': 'INVESTMENT', 'deleted_at': null},
      };
      repo.entities['accounts'] = <String, dynamic>{
        'invest': <String, dynamic>{
          'id': 'invest',
          'user_id': 'user',
          'account_type_id': 'type',
          'deleted_at': null,
        },
      };
    });
  });
  tearDown(() => store.close());

  test(
    'legacy cursor replays from zero and final checkpoint survives restart',
    () async {
      repo.atomic(() => repo.state['cursor'] = '99');
      expect(repo.hasCompleteInvestmentHistory, false);
      await repo.sync();
      expect(feed.cursors, ['0', '1']);
      repo = FinanceRepository(feed, store, 'user');
      expect(repo.hasCompleteInvestmentHistory, true);
      expect(
        repo.investmentHistory('invest').position('stock').quantity,
        '2.00000000',
      );
      expect(repo.supportsInvestmentTradeCommands, true);
    },
  );

  test(
    'interrupted pages stay unavailable after restart and resume safely',
    () async {
      feed.failLast = true;
      await expectLater(repo.sync(), throwsA(isA<ApiFailure>()));
      expect(repo.state['cursor'], '1');
      repo = FinanceRepository(feed, store, 'user');
      expect(repo.hasCompleteInvestmentHistory, false);
      expect(
        () => repo.investmentHistory('invest'),
        throwsA(isA<ApiFailure>()),
      );
      feed.failLast = false;
      await repo.sync();
      expect(feed.cursors, ['0', '1', '1']);
      expect(repo.hasCompleteInvestmentHistory, true);
    },
  );

  test('failed final commit cannot persist a complete checkpoint', () async {
    store.database.execute(
      "CREATE TRIGGER fail_final BEFORE UPDATE ON state WHEN json_extract(NEW.payload, '\$.cursor') = '2' BEGIN SELECT RAISE(ABORT, 'disk'); END",
    );
    await expectLater(repo.sync(), throwsA(isA<SqliteException>()));
    repo = FinanceRepository(feed, store, 'user');
    expect(repo.state['cursor'], '1');
    expect(repo.hasCompleteInvestmentHistory, false);
    store.database.execute('DROP TRIGGER fail_final');
    await repo.sync();
    expect(repo.hasCompleteInvestmentHistory, true);
  });

  test('malformed final page cannot mark partial history complete', () async {
    feed.malformed = true;
    await expectLater(repo.sync(), throwsA(isA<ApiFailure>()));
    expect(repo.state['cursor'], '1');
    expect(repo.hasCompleteInvestmentHistory, false);
  });

  test(
    'ownership deletion pending edits and cursor mismatch block projection',
    () async {
      await repo.sync();
      for (final patch in [
        {'user_id': 'other'},
        {'deleted_at': 'deleted'},
      ]) {
        final before = repo.row('accounts', 'invest')!;
        repo.entities['accounts']['invest'] = {...before, ...patch};
        expect(
          () => repo.investmentHistory('invest'),
          throwsA(isA<ApiFailure>()),
        );
        repo.entities['accounts']['invest'] = before;
      }
      repo.outbox.add({'entity_type': 'accounts', 'entity_id': 'invest'});
      expect(
        () => repo.investmentHistory('invest'),
        throwsA(isA<ApiFailure>()),
      );
      repo.outbox.clear();
      repo.state['cursor'] = '3';
      expect(repo.hasCompleteInvestmentHistory, false);
    },
  );
}
