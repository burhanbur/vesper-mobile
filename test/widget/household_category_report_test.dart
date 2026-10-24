import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/household/widgets/household_unavailable_view.dart';

import '../fixtures/cached_finance.dart';
import '../fixtures/category_report_client.dart';

void main() {
  testWidgets(
    'actual UTC aggregates, cache/error/offline and month changes do not imply missing zero totals',
    (tester) async {
      final api = CategoryReportClient();
      final state = cachedFinanceState(client: api);
      seedReportGroups(state);
      state.householdReportPeriod = '2026-10';
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: HouseholdUnavailableView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saldo Kas Bersama'), findsOneWidget);
      final list = find.byType(ListView);
      await tester.scrollUntilVisible(
        find.text('2026-10'),
        250,
        scrollable: find
            .descendant(of: list, matching: find.byType(Scrollable))
            .first,
      );
      expect(find.text('Rp 100000'), findsNothing);
      expect(find.text('Rp 25000.25'), findsOneWidget);
      expect(find.textContaining('Diambil:'), findsOneWidget);
      api.fail = true;
      await state.loadHouseholdCategoryReport();
      await tester.pumpAndSettle();
      expect(find.textContaining('Laporan gagal dimuat:'), findsOneWidget);
      expect(find.text('Rp 25000.25'), findsOneWidget);
      state.toggleOfflineMode();
      await tester.pumpAndSettle();
      expect(
        find.text('Mode offline: menampilkan data grup tersimpan.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Bulan sebelumnya'));
      await tester.pumpAndSettle();
      expect(find.text('2026-09'), findsOneWidget);
      expect(find.text('Rp 25000.25'), findsNothing);
      expect(find.textContaining('Agregat belum tersedia'), findsOneWidget);
      expect(find.text('Rp 0'), findsNothing);
      expect(api.requests.length, 2);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
