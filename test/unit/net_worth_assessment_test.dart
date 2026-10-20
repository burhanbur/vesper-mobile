import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/features/dashboard/models/net_worth_assessment.dart';

import '../fixtures/cached_finance.dart';

Map<String, dynamic> snapshot() => {
  'scope': 'owner',
  'currency': 'IDR',
  'snapshot_date': '2026-10-20',
  'observed_at': '2026-10-20T12:00:00Z',
  'status': 'partial',
  'balance_basis': 'current_recorded_ledger',
  'attribution': 'unavailable',
  'known_assets': '9007199254740993.01',
  'known_balance_liabilities': '2.00',
  'known_net_worth': '9007199254740991.01',
  'net_worth': null,
  'cash_balance': '10.00',
  'investment_cash_balance': '-2.00',
  'holdings_value': '9007199254740983.01',
  'missing_components': ['liabilities', 'receivables'],
  'excluded_account_count': 2,
  'accounts': [],
  'holdings': [
    {
      'instrument_id': 'instrument',
      'market_value': null,
      'price_date': null,
      'price_source': null,
      'stale': null,
      'unavailable_reason': 'missing_price',
    },
    {
      'instrument_id': 'old',
      'market_value': '12.34',
      'price_date': '2026-09-01',
      'price_source': 'manual',
      'stale': true,
      'unavailable_reason': null,
    },
  ],
};

void main() {
  Map<String, dynamic> complete() => {
    ...snapshot(),
    'status': 'complete',
    'known_assets': '1000.00',
    'known_balance_liabilities': '0.00',
    'known_net_worth': '940.00',
    'net_worth': '940.00',
    'obligation_liabilities': '60.00',
    'receivables_value': '40.00',
    'cash_balance': '960.00',
    'investment_cash_balance': '0.00',
    'holdings_value': '0.00',
    'holdings': [],
    'missing_components': ['attribution_unavailable'],
  };
  test(
    'WM06 complete assessment includes debt and receivables with exact totals',
    () {
      final model = NetWorthAssessment.fromJson(complete());
      expect(model.complete, true);
      expect(model.amounts['net_worth'], '940.00');
      expect(model.amounts['obligation_liabilities'], '60.00');
      expect(model.amounts['receivables_value'], '40.00');
    },
  );
  test('complete status cannot hide missing components or inconsistent financial totals', () {
    for (final fields in [
      {'net_worth': '940.01'},
      {'receivables_value': null},
      {
        'missing_components': ['liabilities_unmodeled'],
      },
      {'holdings': snapshot()['holdings']},
    ]) {
      expect(
        () => NetWorthAssessment.fromJson({...complete(), ...fields}),
        throwsA(isA<ApiFailure>()),
      );
    }
  });
  test(
    'captured history preserves original observation and partial amounts',
    () {
      final model = NetWorthAssessment.fromJson(
        snapshot()..['balance_basis'] = 'captured_recorded_ledger',
      );
      expect(model.isHistoricalObservation, isTrue);
      expect(model.observedAt, '2026-10-20T12:00:00Z');
      expect(model.amounts['known_net_worth'], '9007199254740991.01');
      expect(model.amounts['net_worth'], isNull);
    },
  );

  for (final switchOwner in [true, false]) {
    test(
      'in-flight assessment rejects ${switchOwner ? 'owner' : 'session'} change',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api/v1'));
        final pending = Completer<void>();
        final started = Completer<void>();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              started.complete();
              await pending.future;
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'success': true, 'data': snapshot()},
                ),
              );
            },
          ),
        );
        final state = cachedFinanceState(client: ApiClient(dio: dio));
        addTearDown(state.dispose);
        final result = state.fetchNetWorthAssessment(DateTime(2026, 10, 20));
        final rejected = expectLater(result, throwsA(isA<ApiFailure>()));
        await started.future;
        if (switchOwner) {
          state.currentUserId = 'another-owner';
        } else {
          // Same owner, detached repository: the previous session is no longer valid.
          state.repository = null;
        }
        pending.complete();
        await rejected;
      },
    );
  }

  test('preserves exact decimals, missing valuations and stale prices', () {
    final model = NetWorthAssessment.fromJson(snapshot());
    expect(model.amounts['known_assets'], '9007199254740993.01');
    expect(model.amounts['net_worth'], isNull);
    expect(model.holdings.first.marketValue, isNull);
    expect(model.holdings.last.stale, isTrue);
    expect(model.excludedAccountCount, 2);
    expect(model.missingComponents, ['liabilities', 'receivables']);
  });
  test('rejects malformed scope, currency, amounts and dates', () {
    for (final change in <String, dynamic>{
      'scope': 'household',
      'balance_basis': 'end_of_day',
      'currency': 'USD',
      'known_assets': 1.5,
      'known_net_worth': '1.00\n',
      'snapshot_date': '2026-02-30',
      'observed_at': 'yesterday',
      'net_worth': '100.00',
      'holdings': [false],
      'missing_components': [12],
    }.entries) {
      expect(
        () => NetWorthAssessment.fromJson(
          snapshot()..[change.key] = change.value,
        ),
        throwsA(isA<ApiFailure>()),
        reason: change.key,
      );
    }
    expect(
      () => NetWorthAssessment.fromJson({'data': snapshot()}),
      throwsA(isA<ApiFailure>()),
    );
  });
  test('historical unavailability never becomes a zero valuation', () {
    final payload = snapshot()
      ..['status'] = 'unavailable'
      ..['balance_basis'] = 'unavailable'
      ..['holdings'] = [];
    for (final key in [
      'known_assets',
      'known_balance_liabilities',
      'known_net_worth',
      'cash_balance',
      'investment_cash_balance',
      'holdings_value',
    ]) {
      payload[key] = null;
    }
    final model = NetWorthAssessment.fromJson(payload);
    expect(model.unavailable, isTrue);
    expect(model.amounts.values, everyElement(isNull));
  });
  test(
    'state to repository uses actual client envelope and read-only request',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api/v1'));
      var requests = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            expect(options.method, 'GET');
            expect(options.path, '/net-worth/snapshots');
            expect(options.queryParameters, {
              'currency': 'IDR',
              'date': '2026-10-20',
            });
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'data': snapshot()},
              ),
            );
          },
        ),
      );
      final state = cachedFinanceState(client: ApiClient(dio: dio));
      addTearDown(state.dispose);
      final previousBalance = state.totalNetWorth;
      final previousQueue = state.repository!.outbox.length;
      final model = await state.fetchNetWorthAssessment(DateTime(2026, 10, 20));
      expect(model.snapshotDate, '2026-10-20');
      expect(state.totalNetWorth, previousBalance);
      expect(state.repository!.outbox.length, previousQueue);
      state.repository!.offline = true;
      await expectLater(
        state.fetchNetWorthAssessment(null),
        throwsA(isA<ApiFailure>()),
      );
      expect(requests, 1);
    },
  );
  test('rejects a response for a different requested date', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api/v1'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'data': snapshot()},
            ),
          );
        },
      ),
    );
    final state = cachedFinanceState(client: ApiClient(dio: dio));
    addTearDown(state.dispose);
    await expectLater(
      state.fetchNetWorthAssessment(DateTime(2026, 10, 19)),
      throwsA(isA<ApiFailure>()),
    );
  });
}
