import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/bills/pages/bills_page.dart';
import 'package:vesper_mobile/features/dashboard/models/dashboard_insights.dart';
import 'package:vesper_mobile/features/dashboard/pages/dashboard_page.dart';
import 'package:vesper_mobile/features/dashboard/widgets/dashboard_insights_panel.dart';
import 'package:vesper_mobile/features/reports/pages/budget_page.dart';

import '../fixtures/dashboard_insights.dart';

DashboardInsights sampleInsights() => DashboardInsights(
  spending: SpendingInsight(
    current: BigInt.from(118000000),
    previous: BigInt.from(100000000),
    currentStart: DateTime.utc(2026, 10),
    previousStart: DateTime.utc(2026, 9),
    comparedDays: 23,
    hasPreviousEntries: true,
  ),
  bills: UpcomingBillsInsight(
    count: 3,
    estimatedCount: 1,
    total: BigInt.from(180000000),
    nextTitle: 'Internet rumah',
  ),
  budgets: [
    BudgetAttentionInsight(
      'Makan & minum',
      BigInt.from(100000000),
      BigInt.from(85000000),
    ),
  ],
);

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'insights fit 320px at scale $scale and all three rows are actionable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final taps = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DashboardInsightsPanel(
                  insights: sampleInsights(),
                  hidden: false,
                  onBills: () => taps.add('bills'),
                  onSpending: () => taps.add('spending'),
                  onBudgets: () => taps.add('budgets'),
                ),
              ),
            ),
          ),
        );
        expect(find.text('18,00% lebih tinggi'), findsOneWidget);
        expect(find.text('3 tagihan · Rp 1.800.000'), findsOneWidget);
        expect(find.text('Sisa Rp 150.000'), findsOneWidget);
        for (final id in ['bills', 'spending', 'budgets']) {
          final row = find.byKey(ValueKey('dashboard_insight_$id'));
          await tester.ensureVisible(row);
          await tester.tap(row);
          await tester.pumpAndSettle();
          expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
        }
        expect(taps, ['bills', 'spending', 'budgets']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'privacy hides amounts and derived percentages, including semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardInsightsPanel(
              insights: sampleInsights(),
              hidden: true,
              onBills: () {},
              onSpending: () {},
              onBudgets: () {},
            ),
          ),
        ),
      );
      expect(find.textContaining('18,00%'), findsNothing);
      expect(find.textContaining('85%'), findsNothing);
      expect(find.textContaining('150.000'), findsNothing);
      expect(find.textContaining('1.800.000'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp(r'18,00%|85%|150\.000|1\.800\.000')),
        findsNothing,
      );
    semantics.dispose();
    },
  );

  testWidgets(
    'incomplete/review data withholds numbers rather than showing zero',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardInsightsPanel(
              insights: DashboardInsights(
                bills: UpcomingBillsInsight(
                  count: 2,
                  estimatedCount: 0,
                  total: BigInt.from(999000),
                  needsReview: true,
                ),
              ),
              hidden: false,
              onBills: () {},
              onSpending: () {},
              onBudgets: () {},
            ),
          ),
        ),
      );
      expect(find.text('Periksa jadwal tagihan'), findsOneWidget);
      expect(find.text('Belum dapat dibandingkan'), findsOneWidget);
      expect(find.text('Belum dapat dihitung'), findsOneWidget);
      expect(find.textContaining('Rp'), findsNothing);
    },
  );

  testWidgets('dashboard links open bills, budget and spending destination', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = insightRepository();
    final state = AppState(repository: source)..currentUserId = 'user';
    state.toggleOfflineMode();
    addTearDown(source.store.close);
    addTearDown(state.dispose);
    var reports = 0;
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: MaterialApp(
          home: DashboardPage(
            onNavigateToTransactions: () {},
            onNavigateToInvestments: () {},
            onNavigateToReports: () => reports++,
            onNavigateToHousehold: () {},
          ),
        ),
      ),
    );
    for (final id in ['bills', 'budgets']) {
      final row = find.byKey(ValueKey('dashboard_insight_$id'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        id == 'bills' ? find.byType(BillsPage) : find.byType(BudgetPage),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    final spending = find.byKey(const ValueKey('dashboard_insight_spending'));
    await tester.ensureVisible(spending);
    await tester.tap(spending);
    await tester.pumpAndSettle();
    expect(reports, 1);
    expect(tester.takeException(), isNull);
  });
}
