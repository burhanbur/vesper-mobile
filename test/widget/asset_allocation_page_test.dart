import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/asset_allocation/data/asset_allocation_repository.dart';
import 'package:vesper_mobile/features/asset_allocation/pages/asset_allocation_page.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import '../unit/asset_allocation_test.dart'
    show AllocationClient, allocationFixture, allocationTargets;

void main() {
  testWidgets(
    'cached allocation shows concentration/target deviations, hides amounts and validates target totals',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = LocalStore(sqlite3.openInMemory());
      final source = FinanceRepository(AllocationClient(), store, 'owner')
        ..offline = true;
      source.atomic(() {
        source.state['asset_allocation_cache'] = {
          'schema': 1,
          'user_id': 'owner',
          'snapshot': allocationFixture(),
        };
      });
      AssetAllocationRepository(source).saveTargets(allocationTargets());
      final state = AppState(repository: source)..currentUserId = 'owner';
      state.toggleOfflineMode();
      addTearDown(() {
        state.dispose();
        store.close();
      });
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: AssetAllocationPage()),
        ),
      );
      expect(find.text('Cache snapshot server — dapat usang'), findsOneWidget);
      expect(
        find.textContaining('deviasi: -10.00 poin persentase'),
        findsOneWidget,
      );
      expect(find.textContaining('Instrumen terbesar: GOLD'), findsOneWidget);
      expect(find.textContaining('USANG'), findsOneWidget);
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      expect(find.textContaining('50.00%'), findsNothing);
      expect(find.textContaining('50.00 IDR'), findsNothing);
      expect(find.textContaining('-10.00'), findsNothing);
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Atur target alokasi'));
      await tester.pumpAndSettle();
      final cash = find.widgetWithText(TextField, 'Kas & kas investasi (%)');
      await tester.enterText(cash, '61');
      await tester.tap(find.text('Simpan target'));
      await tester.pumpAndSettle();
      expect(find.textContaining('tepat 100%').last, findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(AssetAllocationRepository(source).targets!['CASH'], '60.00');
      await tester.enterText(cash, '60');
      await tester.tap(find.text('Simpan target'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(source.outbox, isEmpty);
      expect(source.rows('transactions'), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'phone partial snapshot withholds weights and session changes block stale target dialog',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = LocalStore(sqlite3.openInMemory());
      final source = FinanceRepository(AllocationClient(), store, 'owner')
        ..offline = true;
      source.atomic(() {
        source.state['asset_allocation_cache'] = {
          'schema': 1,
          'user_id': 'owner',
          'snapshot': allocationFixture(partial: true),
        };
      });
      final state = AppState(repository: source)..currentUserId = 'owner';
      state.toggleOfflineMode();
      addTearDown(() {
        state.dispose();
        store.close();
      });
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: AssetAllocationPage()),
        ),
      );
      expect(
        find.textContaining('parsial; persentase dan deviasi ditahan'),
        findsOneWidget,
      );
      expect(find.textContaining('50.00%'), findsNothing);
      await tester.tap(find.text('Atur target alokasi'));
      await tester.pumpAndSettle();
      state.currentUserId = 'other';
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan target'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sesi telah berubah'), findsOneWidget);
      expect(source.state['asset_allocation_targets'], isNull);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Masuk untuk membuka alokasi aset.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
