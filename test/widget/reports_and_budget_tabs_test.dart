import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/reports/pages/budget_page.dart';
import 'package:vesper_mobile/features/reports/pages/reports_page.dart';

void main() {
  group('Reports & Budget Interactive Tabs Test', () {
    testWidgets('ReportsPage tab switching verification', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      await tester.pumpWidget(
        AppStateScope(
          state: appState,
          child: const MaterialApp(
            home: ReportsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initial tab: Ringkasan
      expect(find.text('Surplus / Neraca Bulan Ini'), findsOneWidget);
      expect(find.text('Perbandingan Bulanan'), findsOneWidget);
      expect(find.text('Kategori Terbesar'), findsOneWidget);

      // 2. Tap Pengeluaran Tab by Key
      await tester.tap(find.byKey(const ValueKey('reports_tab_1')));
      await tester.pumpAndSettle();

      expect(find.text('Total Pengeluaran Bulan Ini'), findsOneWidget);
      expect(find.text('Tren Pengeluaran (6 Bulan Terakhir)'), findsOneWidget);
      expect(find.text('Rincian Kategori Pengeluaran'), findsOneWidget);
      expect(find.text('Surplus / Neraca Bulan Ini'), findsNothing);

      // 3. Tap Pemasukan Tab by Key
      await tester.tap(find.byKey(const ValueKey('reports_tab_2')));
      await tester.pumpAndSettle();

      expect(find.text('Total Pemasukan Bulan Ini'), findsOneWidget);
      expect(find.text('Tren Pemasukan (6 Bulan Terakhir)'), findsOneWidget);
      expect(find.text('Rincian Sumber Pemasukan'), findsOneWidget);
      expect(find.text('Evaluasi Alokasi Pemasukan (50/30/20)'), findsOneWidget);

      // 4. Switch back to Ringkasan Tab
      await tester.tap(find.byKey(const ValueKey('reports_tab_0')));
      await tester.pumpAndSettle();

      expect(find.text('Surplus / Neraca Bulan Ini'), findsOneWidget);
      expect(find.text('Perbandingan Bulanan'), findsOneWidget);
    });

    testWidgets('BudgetPage tab switching between Bulanan and Tahunan', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      await tester.pumpWidget(
        AppStateScope(
          state: appState,
          child: const MaterialApp(
            home: BudgetPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Default Bulanan
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('Total Budget Bulanan'), findsOneWidget);
      expect(find.text('Target Tabungan Tahunan 2026'), findsNothing);

      // 2. Tap Tahunan Tab
      await tester.tap(find.text('Tahunan'));
      await tester.pumpAndSettle();

      expect(find.text('Tahun 2026'), findsOneWidget);
      expect(find.text('Total Budget Tahunan (12 Bulan)'), findsOneWidget);
      expect(find.text('Target Tabungan Tahunan 2026'), findsOneWidget);
      expect(find.text('Total Budget Bulanan'), findsNothing);

      // 3. Tap Chevron next year
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Tahun 2027'), findsOneWidget);

      // 4. Tap Bulanan Tab again
      await tester.tap(find.text('Bulanan'));
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('Total Budget Bulanan'), findsOneWidget);
    });
  });
}
