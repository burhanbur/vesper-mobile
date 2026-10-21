import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/emergency_funds/pages/emergency_fund_page.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import '../unit/emergency_fund_test.dart' show seedEmergency;

void main() {
  testWidgets(
    'manual setup, invalid baseline, account selection, history fallback and session privacy',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = LocalStore(sqlite3.openInMemory());
      final source = FinanceRepository(ApiClient(), store, 'owner')
        ..offline = true;
      seedEmergency(source);
      final state = AppState(repository: source)..currentUserId = 'owner';
      state.toggleOfflineMode();
      addTearDown(() {
        state.dispose();
        store.close();
      });
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: EmergencyFundPage()),
        ),
      );
      await tester.tap(find.text('Atur dana darurat'));
      await tester.pumpAndSettle();
      final baseline = find.widgetWithText(
        TextField,
        'Pengeluaran wajib per bulan (IDR)',
      );
      await tester.enterText(baseline, '0');
      await tester.tap(find.text('Simpan lokal'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Baseline harus positif'), findsOneWidget);
      expect(source.outbox, isEmpty);
      await tester.enterText(baseline, '300');
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Cash'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Food'));
      await tester.tap(find.text('Simpan lokal'));
      await tester.pumpAndSettle();
      expect(find.text('Cakupan saat ini: 3.33 bulan'), findsOneWidget);
      expect(find.text('Kekurangan target: 800.00 IDR'), findsOneWidget);
      expect(source.rows('emergency_plans').single['account_ids'], ['cash']);
      expect(source.row('accounts', 'cash')!['balance'], '1000.00');
      expect(source.rows('transactions'), isEmpty);
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      expect(find.text('Cakupan saat ini: ••••••'), findsOneWidget);
      expect(find.textContaining('300.00 IDR'), findsNothing);
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      source.atomic(() {
        source.outbox.clear();
        source.entities['emergency_plans'] = <String, dynamic>{
          for (final p in source.rows('emergency_plans'))
            p['id'] as String: {...p, 'version': '1'},
        };
      });
      await tester.tap(find.text('Ubah pengaturan'));
      await tester.pumpAndSettle();
      final modes = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.decoration.labelText == 'Baseline pengeluaran wajib',
      );
      await tester.tap(modes);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Estimasi dari histori').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan lokal'));
      await tester.pumpAndSettle();
      expect(find.text('Baseline estimasi — histori lokal'), findsOneWidget);
      expect(find.text('Cakupan saat ini: Belum tersedia'), findsOneWidget);
      expect(find.textContaining('Masukkan baseline manual'), findsOneWidget);
      state.currentUserId = 'other';
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(
            home: EmergencyFundPage(key: ValueKey('other')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Masuk untuk membuka rencana dana darurat.'),
        findsOneWidget,
      );
      expect(find.text('Cash'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
