import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/features/investments/data/portfolio_controller.dart';
import 'package:vesper_mobile/features/investments/data/portfolio_repository.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import '../fixtures/cached_finance.dart';

Map<String, dynamic> position({String? date}) => {
  'instrument': {
    'id': 'instrument',
    'code': 'GOLD',
    'name': 'Gold',
    'currency': 'IDR',
  },
  'quantity_held': '123456789012.12345678',
  'avg_cost_price': '999999999999.12345678',
  if (date != null) ...{
    'account_id': 'own',
    'snapshot_date': date,
    'market_price': null,
    'market_value': null,
    'unrealized_pl': '-123456789012345678.12',
  },
};

class ReadClient extends ApiClient {
  final requests = <String>[];
  dynamic response = [position()];
  ApiFailure? failure;
  Completer<dynamic>? pending;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    expect(method, 'GET');
    expect(body, isNull);
    requests.add('$path:${query?['date']}');
    if (failure != null) throw failure!;
    return pending == null ? response : pending!.future;
  }
}

void seed(FinanceRepository repo) {
  repo.atomic(() {
    repo.entities['account_types'] = {
      'investment': {'id': 'investment', 'category': 'INVESTMENT'},
    };
    repo.entities['accounts'] = {
      for (final id in ['own', 'other', 'second'])
        id: {
          'id': id,
          'name': id,
          'user_id': id == 'other' ? 'someone' : 'user',
          'account_type_id': 'investment',
        },
    };
  });
}

void main() {
  test(
    'exact GET contracts, decimals, null valuation and durable scoped cache',
    () async {
      final api = ReadClient();
      final state = cachedFinanceState(client: api);
      addTearDown(state.dispose);
      final source = state.repository!;
      seed(source);
      final repo = PortfolioRepository(source);
      expect(repo.accounts.map((a) => a.id), ['own', 'second']);
      await expectLater(
        repo.fetch('other', null, isCurrent: () => true),
        throwsA(isA<ApiFailure>()),
      );
      final read = await repo.fetch('own', null, isCurrent: () => true);
      expect(read.positions.single.quantity, '123456789012.12345678');
      expect(read.positions.single.average, '999999999999.12345678');
      const date = '2026-10-15';
      api.response = [position(date: date)];
      final snapshot = await repo.fetch('own', date, isCurrent: () => true);
      expect(snapshot.positions.single.marketValue, isNull);
      expect(snapshot.positions.single.unrealizedPl, '-123456789012345678.12');
      expect(api.requests, [
        '/accounts/own/holdings:null',
        '/accounts/own/portfolio-snapshot:2026-10-15',
      ]);
      final reopened = PortfolioRepository(
        FinanceRepository(api, source.store, source.userId),
      );
      expect(reopened.cached('own', date)!.fetchedAt, snapshot.fetchedAt);
      expect(
        reopened.cached('own', null)!.positions.single.quantity,
        read.positions.single.quantity,
      );
      expect(reopened.cached('second', date), isNull);
      expect(source.outbox, isEmpty);
    },
  );

  test(
    'offline/error/empty and authorization states never fabricate zeroes',
    () async {
      final api = ReadClient();
      final state = cachedFinanceState(client: api);
      addTearDown(state.dispose);
      seed(state.repository!);
      final controller = PortfolioController(
        PortfolioRepository(state.repository!),
        () => true,
      );
      addTearDown(controller.dispose);
      await controller.select('own', null);
      state.repository!.offline = true;
      await controller.select('own', null);
      expect(controller.read, isNotNull);
      expect(controller.stale, isTrue);
      expect(api.requests.length, 1);
      await controller.select('second', null);
      expect(controller.read, isNull);
      state.repository!.offline = false;
      api.failure = const ApiFailure('Unavailable', statusCode: 503);
      await controller.select('own', null);
      expect(controller.read, isNotNull);
      expect(controller.error, 'Unavailable');
      api.failure = const ApiFailure('Denied', statusCode: 403);
      await controller.select('own', null);
      expect(controller.read, isNull);
      api.failure = null;
      api.response = [];
      await controller.select('own', null);
      expect(controller.read!.positions, isEmpty);
      expect(controller.stale, isFalse);
    },
  );

  test(
    'late account/session response neither displays nor caches data',
    () async {
      final api = ReadClient()..pending = Completer<dynamic>();
      final state = cachedFinanceState(client: api);
      addTearDown(state.dispose);
      seed(state.repository!);
      var current = true;
      final repo = PortfolioRepository(state.repository!);
      final controller = PortfolioController(repo, () => current);
      addTearDown(controller.dispose);
      final old = controller.select('own', null);
      await Future<void>.delayed(Duration.zero);
      final pending = api.pending!;
      api.pending = null;
      api.response = [];
      await controller.select('second', null);
      pending.complete([position()]);
      await old;
      expect(controller.accountId, 'second');
      expect(controller.read!.positions, isEmpty);
      expect(repo.cached('own', null), isNull);
      api.pending = Completer<dynamic>();
      final logout = controller.select('own', null);
      await Future<void>.delayed(Duration.zero);
      current = false;
      api.pending!.complete([position()]);
      await logout;
      expect(controller.read, isNull);
      expect(repo.cached('own', null), isNull);
    },
  );

  test(
    'invalid numeric and mismatched snapshot responses preserve old cache',
    () async {
      final api = ReadClient();
      final state = cachedFinanceState(client: api);
      addTearDown(state.dispose);
      seed(state.repository!);
      final repo = PortfolioRepository(state.repository!);
      await repo.fetch('own', null, isCurrent: () => true);
      api.response = [
        {...position(), 'quantity_held': 0.1},
      ];
      await expectLater(
        repo.fetch('own', null, isCurrent: () => true),
        throwsA(isA<ApiFailure>()),
      );
      expect(
        repo.cached('own', null)!.positions.single.quantity,
        '123456789012.12345678',
      );
      api.response = [position(date: '2026-10-14')];
      await expectLater(
        repo.fetch('own', '2026-10-15', isCurrent: () => true),
        throwsA(isA<ApiFailure>()),
      );
      expect(repo.cached('own', '2026-10-15'), isNull);
    },
  );
}
