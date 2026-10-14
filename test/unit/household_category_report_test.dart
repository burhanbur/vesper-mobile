import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/features/household/models/category_report.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import '../fixtures/cached_finance.dart';
import '../fixtures/category_report_client.dart';

void main() {
  test('success persists exact decimals and timestamp through real SQLite, offline does not fetch', () async {
    final api = CategoryReportClient();
    final state = cachedFinanceState(client: api);
    seedReportGroups(state);
    await state.loadHouseholdCategoryReport(period: '2026-10');
    final repo = state.repository!;
    final reopened = FinanceRepository(api, repo.store, repo.userId);
    final report = reopened.cachedCategoryReport('group', '2026-10')!;
    expect(report.categories.single.expense, '25000.25');
    expect(report.fetchedAt.isUtc, isTrue);
    expect(api.requests.single, '/groups/group/category-report?2026-10');
    state.toggleOfflineMode();
    await state.loadHouseholdCategoryReport();
    expect(api.requests.length, 1);
    expect(
      state.householdCategoryReport!.categories.single.name,
      'Shared food',
    );
    await state.loadHouseholdCategoryReport(period: '2026-09');
    expect(state.householdCategoryReport, isNull);
    state.dispose();
  });

  test(
    'failed refresh preserves cache; mismatched period never cached',
    () async {
      final api = CategoryReportClient();
      final state = cachedFinanceState(client: api);
      seedReportGroups(state);
      await state.loadHouseholdCategoryReport(period: '2026-10');
      api.fail = true;
      await state.loadHouseholdCategoryReport();
      expect(state.householdReportError, contains('tidak terjangkau'));
      expect(state.householdCategoryReport, isNotNull);
      api.fail = false;
      api.responsePeriod = '2026-10';
      await state.loadHouseholdCategoryReport(period: '2026-09');
      expect(state.householdReportError, contains('Periode'));
      expect(state.householdCategoryReport, isNull);
      expect(
        () => state.loadHouseholdCategoryReport(period: '2026-13'),
        throwsA(isA<ApiFailure>()),
      );
      state.dispose();
    },
  );

  test('single flight; stale group response cannot overwrite or cache another scope', () async {
    final api = CategoryReportClient()..pending = Completer<dynamic>();
    final state = cachedFinanceState(client: api);
    seedReportGroups(state);
    final old = state.loadHouseholdCategoryReport(period: '2026-10');
    final duplicate = state.loadHouseholdCategoryReport();
    await Future<void>.delayed(Duration.zero);
    expect(api.requests.length, 1);
    final pending = api.pending!;
    api.pending = null;
    state.switchHousehold('other');
    await state.loadHouseholdCategoryReport();
    pending.complete(reportPayload('2026-10', '999.00'));
    await Future.wait([old, duplicate]);
    expect(
      state.householdCategoryReport!.categories.single.expense,
      '25000.25',
    );
    expect(state.repository!.cachedCategoryReport('group', '2026-10'), isNull);
    state.dispose();
  });

  test('UTC period uses UTC calendar boundary', () {
    expect(
      utcReportPeriod(DateTime.parse('2026-11-01T00:30:00+07:00')),
      '2026-10',
    );
  });
}
