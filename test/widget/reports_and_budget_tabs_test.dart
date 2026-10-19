import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/reports/pages/budget_page.dart';
import 'package:vesper_mobile/features/reports/pages/reports_page.dart';
import 'package:vesper_mobile/core/utils/date_formatter.dart';

import '../fixtures/cached_finance.dart';

void main() {
  group('Reports & Budget Interactive Tabs Test', () {
    testWidgets('ReportsPage tab switching verification', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = cachedFinanceState();
      addTearDown(appState.dispose);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      appState.repository!.atomic(() {
        appState.repository!.entities['transactions'] = {
          for (final row in [
            ['expense', 'EXPENSE', 'food', '123.00'],
            ['income', 'INCOME', 'salary', '456.00'],
            ['transfer', 'TRANSFER', '', '999.00'],
          ])
            row[0]: {
              'id': row[0],
              'account_id': 'cash',
              'type': row[1],
              'category_id': row[2],
              'amount': row[3],
              'transacted_at': DateTime(
                now.year,
                now.month,
                2,
              ).toUtc().toIso8601String(),
            },
        };
      });
      await tester.pumpWidget(
        AppStateScope(
          state: appState,
          child: const MaterialApp(home: ReportsPage()),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initial tab: Ringkasan
      expect(find.text('Surplus / Neraca Periode'), findsOneWidget);
      expect(find.text('Rp 333'), findsOneWidget);
      expect(find.text('Rp 456'), findsOneWidget);
      expect(find.text('Rp 123'), findsNWidgets(2));
      expect(find.text('Rp 999'), findsNothing);

      // 2. Tap Pengeluaran Tab by Key
      await tester.tap(find.byKey(const ValueKey('reports_tab_1')));
      await tester.pumpAndSettle();

      expect(find.text('Total Pengeluaran Periode'), findsOneWidget);
      expect(find.text('Food'), findsNWidgets(2));
      expect(find.text('Rp 123'), findsNWidgets(2));
      expect(find.text('Rincian Kategori Pengeluaran'), findsOneWidget);
      expect(find.text('Surplus / Neraca Periode'), findsNothing);
      expect(find.text('Salary'), findsNothing);

      // 3. Tap Pemasukan Tab by Key
      await tester.tap(find.byKey(const ValueKey('reports_tab_2')));
      await tester.pumpAndSettle();

      expect(find.text('Total Pemasukan Periode'), findsOneWidget);
      expect(find.text('Salary'), findsNWidgets(2));
      expect(find.text('Rp 456'), findsNWidgets(2));
      expect(find.text('Food'), findsNothing);
      expect(find.text('Rp 999'), findsNothing);
      expect(find.text('Rincian Sumber Pemasukan'), findsOneWidget);

      // 4. Switch back to Ringkasan Tab
      await tester.tap(find.byKey(const ValueKey('reports_tab_0')));
      await tester.pumpAndSettle();

      expect(find.text('Surplus / Neraca Periode'), findsOneWidget);
      expect(find.text('Rp 333'), findsOneWidget);
    });

    testWidgets('BudgetPage tab switching between Bulanan and Tahunan', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = cachedFinanceState();
      addTearDown(appState.dispose);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      await tester.pumpWidget(
        AppStateScope(
          state: appState,
          child: const MaterialApp(home: BudgetPage()),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Default Bulanan
      expect(find.text(DateFormatter.formatMonthYear(now)), findsOneWidget);
      expect(find.text('Total Budget Bulanan'), findsOneWidget);
      expect(find.text('Target Tabungan Tahunan ${now.year}'), findsNothing);

      // 2. Tap Tahunan Tab
      await tester.tap(find.text('Tahunan'));
      await tester.pumpAndSettle();

      expect(find.text('Tahun ${now.year}'), findsOneWidget);
      expect(find.text('Total Budget Tahunan (12 Bulan)'), findsOneWidget);
      expect(find.text('Target Tabungan Tahunan ${now.year}'), findsOneWidget);
      expect(find.text('Total Budget Bulanan'), findsNothing);

      // 3. Tap Chevron next year
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Tahun ${now.year + 1}'), findsOneWidget);

      // 4. Tap Bulanan Tab again
      await tester.tap(find.text('Bulanan'));
      await tester.pumpAndSettle();

      expect(find.text(DateFormatter.formatMonthYear(now)), findsOneWidget);
      expect(find.text('Total Budget Bulanan'), findsOneWidget);
    });
  });
}
