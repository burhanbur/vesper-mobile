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
      final actual = find.widgetWithText(TextField, 'Nominal aktual IDR bulat');
      expect(tester.widget<TextField>(actual).controller!.text, '100');
      expect(tester.widget<TextField>(actual).decoration!.prefixText, 'Rp ');
      await tester.enterText(actual, '1000,01');
      expect(tester.widget<TextField>(actual).controller!.text, '1.000,01');
      await tester.tap(find.text('Konfirmasi'));
      await tester.pumpAndSettle();
      expect(source.outbox, isEmpty);
      expect(source.row('accounts', cashId)!['balance'], '1000.00');
      await tester.enterText(actual, '100');
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
      await tester.tap(find.byTooltip('Buat jadwal'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Judul'),
        'Internet',
      );
      final amount = find.widgetWithText(TextField, 'Nominal IDR bulat');
      await tester.enterText(amount, '1000000,01');
      expect(tester.widget<TextField>(amount).controller!.text, '1.000.000,01');
      expect(tester.widget<TextField>(amount).decoration!.prefixText, 'Rp ');
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(
                TextField,
                'Ingatkan sebelum jatuh tempo (0–30 hari)',
              ),
            )
            .inputFormatters,
        isNull,
      );
      await tester.tap(find.text('Simpan jadwal'));
      await tester.pumpAndSettle();
      expect(source.outbox, isEmpty);
      expect(find.byType(BottomSheet), findsOneWidget);
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

  testWidgets(
    'delete schedule requires confirmation and deletes schedule locally',
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
      await tester.pumpAndSettle();

      // Open schedule modal via 'Kelola jadwal' on the occurrence card
      final manageButton = find.byTooltip('Kelola jadwal').first;
      expect(manageButton, findsOneWidget);
      await tester.tap(manageButton);
      await tester.pumpAndSettle();

      // Inside the schedule modal, delete action exists
      expect(find.text('Ubah pengingat / arsip'), findsOneWidget);
      final deleteInHeader = find.byTooltip('Hapus jadwal');
      expect(deleteInHeader, findsOneWidget);

      // Tap delete in header
      await tester.tap(deleteInHeader);
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Hapus Jadwal Tagihan?'), findsOneWidget);

      // Cancel deletion
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Batal'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        source.rows('bill_schedules').where((b) => b['id'] == billId),
        isNotEmpty,
      );

      // Tap delete again and confirm
      await tester.tap(deleteInHeader);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Hapus'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        source
            .rows('bill_schedules')
            .where((b) => b['id'] == billId && b['deleted_at'] == null),
        isEmpty,
      );
      expect(
        source.outbox.any(
          (e) =>
              e['entity_type'] == 'bill_schedules' &&
              e['entity_id'] == billId &&
              e['operation'] == 'DELETE',
        ),
        isTrue,
      );
      expect(find.text('Jadwal tagihan berhasil dihapus.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
