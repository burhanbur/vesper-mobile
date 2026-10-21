import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/bills/pages/bills_page.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import '../unit/bills_test.dart' show seedBills, billId, cashId;

void main() {
  testWidgets(
    'payment requires confirmation, moves cash once and appears in history',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = LocalStore(sqlite3.openInMemory());
      final source = FinanceRepository(ApiClient(), store, 'owner')
        ..offline = true;
      seedBills(source);
      source.atomic(() {
        final bill = source.row('bill_schedules', billId)!;
        source.entities['bill_schedules'][billId] = {
          ...bill,
          'frequency': 'ONCE',
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
          child: const MaterialApp(home: BillsPage()),
        ),
      );
      await tester.tap(find.text('Catat pembayaran'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(source.outbox, isEmpty);
      expect(source.row('accounts', cashId)!['balance'], '1000.00');
      await tester.tap(find.text('Catat pembayaran'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Konfirmasi'));
      await tester.pumpAndSettle();
      expect(source.row('accounts', cashId)!['balance'], '900.00');
      expect(source.rows('transactions'), hasLength(1));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riwayat pembayaran / dilewati').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('PAID'), findsOneWidget);
      expect(find.text('Catat pembayaran'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'invalid schedule amount stays in dialog and a changed session hides bills',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = LocalStore(sqlite3.openInMemory());
      final source = FinanceRepository(ApiClient(), store, 'owner')
        ..offline = true;
      seedBills(source);
      final state = AppState(repository: source)..currentUserId = 'owner';
      state.toggleOfflineMode();
      addTearDown(() {
        state.dispose();
        store.close();
      });
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: BillsPage()),
        ),
      );
      await tester.tap(find.text('Buat jadwal'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Judul'),
        'Internet',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Nominal IDR bulat'),
        'oops',
      );
      await tester.tap(find.text('Simpan jadwal'));
      await tester.pumpAndSettle();
      expect(source.outbox, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      state.currentUserId = 'other';
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: BillsPage(key: ValueKey('other'))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Masuk untuk membuka tagihan.'), findsOneWidget);
      expect(find.text('Rent'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
