import 'package:fl_chart/fl_chart.dart';
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
      expect(find.byType(PieChart), findsOneWidget);
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      expect(find.byType(PieChart), findsNothing);
      expect(find.textContaining('50.00%'), findsNothing);
      expect(find.textContaining('50.00 IDR'), findsNothing);
      expect(find.textContaining('-10.00'), findsNothing);
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Atur target alokasi'));
      await tester.pumpAndSettle();
      expect(find.text('Total target: 100.00% / 100%'), findsOneWidget);
      final cash = find.widgetWithText(TextField, 'Kas & kas investasi (%)');
      await tester.enterText(cash, '61');
      await tester.pumpAndSettle();
      expect(find.text('Total target: 101.00% / 100%'), findsOneWidget);
      await tester.tap(find.text('Simpan target'));
      await tester.pumpAndSettle();
      expect(find.textContaining('tepat 100%').last, findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(AssetAllocationRepository(source).targets!['CASH'], '60.00');
      await tester.enterText(cash, '60');
      await tester.tap(find.text('Simpan target'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
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
      expect(find.text('Subtotal Aset Tervaluasi'), findsOneWidget);
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

  testWidgets(
    'tab navigation seamlessly switches between Ringkasan, Kelas Aset, and Instrumen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
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

      // Verify Ringkasan tab is default
      expect(find.text('Ringkasan'), findsOneWidget);
      expect(find.text('Kelas Aset'), findsOneWidget);
      expect(find.text('Instrumen'), findsOneWidget);
      expect(find.text('Total Aset Positif'), findsOneWidget);
      expect(find.text('Distribusi Kelas Aset'), findsOneWidget);

      // Switch to Kelas Aset tab via TabBar
      await tester.tap(find.text('Kelas Aset'));
      await tester.pumpAndSettle();
      expect(find.text('Per kelas aset'), findsOneWidget);
      expect(
        find.text('Bandingkan realisasi aset dengan target pribadi'),
        findsOneWidget,
      );

      // Switch to Instrumen tab via TabBar
      await tester.tap(find.text('Instrumen'));
      await tester.pumpAndSettle();
      expect(find.text('Daftar instrumen'), findsOneWidget);
      expect(find.textContaining('1 Instrumen'), findsOneWidget);

      // Switch back to Ringkasan
      await tester.tap(find.text('Ringkasan'));
      await tester.pumpAndSettle();
      expect(find.text('Distribusi Kelas Aset'), findsOneWidget);

      // Tap 'Lihat Semua' button on Ringkasan tab switches to Kelas Aset
      await tester.tap(find.text('Lihat Semua'));
      await tester.pumpAndSettle();
      expect(find.text('Per kelas aset'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Atur kelas akun bottom sheet updates account asset_class offline-first and queues sync',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = LocalStore(sqlite3.openInMemory());
      final source = FinanceRepository(AllocationClient(), store, 'owner')
        ..offline = true;
      source.atomic(() {
        source.entities['account_types'] = {
          'type_inv': {
            'id': 'type_inv',
            'user_id': 'owner',
            'name': 'Investasi',
            'category': 'INVESTMENT',
          },
        };
        source.entities['accounts'] = {
          'acc_bibit': {
            'id': 'acc_bibit',
            'user_id': 'owner',
            'account_type_id': 'type_inv',
            'name': 'Bibit',
            'currency': 'IDR',
            'balance': '5000000.00',
            'is_credit_card': false,
            'is_visible': true,
            'is_include_total': true,
            'version': '1',
          },
        };
        source.state['asset_allocation_cache'] = {
          'schema': 1,
          'user_id': 'owner',
          'snapshot': allocationFixture(),
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

      await tester.tap(find.text('Atur kelas akun'));
      await tester.pumpAndSettle();
      expect(find.text('Atur kelas aset akun'), findsOneWidget);
      expect(find.text('Bibit'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('allocation_account_class_acc_bibit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reksa dana').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan kelas'));
      await tester.pumpAndSettle();

      expect(state.getAccountById('acc_bibit')!.assetClass, 'MUTUAL_FUND');
      expect(
        source.outbox.any(
          (item) =>
              item['entity_type'] == 'accounts' &&
              item['entity_id'] == 'acc_bibit' &&
              item['operation'] == 'UPDATE' &&
              (item['payload'] as Map)['asset_class'] == 'MUTUAL_FUND',
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
