import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/dashboard/pages/dashboard_page.dart';
import 'package:vesper_mobile/features/dashboard/pages/net_worth_assessment_page.dart';
import 'package:vesper_mobile/features/dashboard/widgets/net_worth_card.dart';
import 'package:vesper_mobile/features/dashboard/models/dashboard_balance_view.dart';

import '../fixtures/cached_finance.dart';

void main() {
  testWidgets('net worth card never presents cash flow as genuine history', (
    tester,
  ) async {
    final state = cachedFinanceState();
    addTearDown(state.dispose);
    state.selectDashboardBalanceView(DashboardBalanceView.netWorth);
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(home: Scaffold(body: NetWorthCard())),
      ),
    );
    expect(find.byType(LineChart), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    expect(
      find.textContaining('grafik historis kekayaan belum tersedia'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dashboard opens a separate partial server assessment and offline retry is safe',
    (tester) async {
      final state = cachedFinanceState();
      addTearDown(state.dispose);
      state.repository!.offline = true;
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: MaterialApp(
            home: DashboardPage(
              onNavigateToTransactions: () {},
              onNavigateToInvestments: () {},
              onNavigateToReports: () {},
              onNavigateToHousehold: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Periksa valuasi server (parsial)'));
      await tester.pumpAndSettle();
      expect(find.byType(NetWorthAssessmentPage), findsOneWidget);
      expect(find.textContaining('bukan total household'), findsOneWidget);
      await tester.tap(find.text('Muat penilaian'));
      await tester.pumpAndSettle();
      expect(
        find.text('Penilaian belum tersedia. Periksa koneksi lalu coba lagi.'),
        findsOneWidget,
      );
      expect(state.totalNetWorth, 100000);
      expect(tester.takeException(), isNull);
    },
  );
}
