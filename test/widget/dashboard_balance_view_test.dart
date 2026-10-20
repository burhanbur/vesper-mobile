import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/dashboard/models/dashboard_balance_view.dart';
import 'package:vesper_mobile/features/dashboard/widgets/net_worth_card.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import '../fixtures/cached_finance.dart';

void main() {
  test('balance modes use integer totals and persist per local repository', () {
    final state = cachedFinanceState();
    addTearDown(state.dispose);
    final repo = state.repository!;
    repo.atomic(() {
      final accounts = repo.entities['accounts'] as Map<String, dynamic>;
      accounts['investment'] = {
        'id': 'investment',
        'type': 'INVESTMENT',
        'balance': '50000',
      };
      accounts['debt'] = {
        'id': 'debt',
        'type': 'CREDIT_CARD',
        'balance': '-200000',
      };
      accounts['excluded'] = {
        'id': 'excluded',
        'type': 'CREDIT_CARD',
        'balance': '-999999',
        'is_include_total': false,
      };
      for (final account in accounts.values) {
        (account as Map<String, dynamic>)['name'] ??= account['id'];
      }
    });
    expect(state.dashboardBalance, -50000);
    expect(state.totalDebt, 200000);
    for (final entry in {
      DashboardBalanceView.cash: 100000,
      DashboardBalanceView.investments: 50000,
      DashboardBalanceView.debt: 200000,
      DashboardBalanceView.netWorth: -50000,
    }.entries) {
      state.selectDashboardBalanceView(entry.key);
      expect(state.dashboardBalance, entry.value);
    }
    state.selectDashboardBalanceView(DashboardBalanceView.debt);
    expect(repo.outbox, isEmpty);
    final reloaded = AppState(
      repository: FinanceRepository(repo.client, repo.store, repo.userId),
    );
    expect(reloaded.dashboardBalanceView, DashboardBalanceView.debt);
    // Both notifiers share a store; only the original owns its disposal here.
    reloaded.repository = null;
    reloaded.dispose();
    repo.atomic(() => repo.state['dashboard_balance_view'] = 'unknown');
    expect(state.dashboardBalanceView, DashboardBalanceView.netWorth);
  });

  testWidgets(
    'selector changes balance without navigating and respects privacy',
    (tester) async {
      final state = cachedFinanceState();
      addTearDown(state.dispose);
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: NetWorthCard())),
          ),
        ),
      );
      await tester.tap(find.text('Kekayaan Bersih'));
      await tester.pumpAndSettle();
      expect(find.text('Tampilkan'), findsOneWidget);
      await tester.tap(find.text('Utang'));
      await tester.pumpAndSettle();
      expect(state.dashboardBalanceView, DashboardBalanceView.debt);
      expect(find.text('Utang'), findsOneWidget);
      expect(find.text('Rp 0'), findsOneWidget);
      await tester.tap(find.byTooltip('Sembunyikan saldo'));
      await tester.pumpAndSettle();
      expect(find.text('Rp •••••••••'), findsOneWidget);
      expect(find.text('Rp 0'), findsNothing);
      await tester.tap(find.text('Utang'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kas'));
      await tester.pumpAndSettle();
      expect(state.dashboardBalanceView, DashboardBalanceView.cash);
      expect(find.text('Rp •••••••••'), findsOneWidget);
    },
  );
}
