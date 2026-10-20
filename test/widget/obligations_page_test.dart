import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/obligations/pages/obligations_page.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import '../unit/obligations_test.dart'
    show seedObligations, acceptProjection, cashId;

void main() {
  testWidgets(
    'offline obligation, installment and payment forms preserve invalid input and show history',
    (tester) async {
      final store = LocalStore(sqlite3.openInMemory());
      final repo = FinanceRepository(ApiClient(), store, 'owner')
        ..offline = true;
      seedObligations(repo);
      repo.atomic(
        () => repo.entities['categories'] = {
          'cost': {
            'id': 'cost',
            'name': 'Costs',
            'user_id': 'owner',
            'type': 'EXPENSE',
            'version': '1',
          },
        },
      );
      final state = AppState(repository: repo)..currentUserId = 'owner';
      addTearDown(state.dispose);
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: ObligationsPage()),
        ),
      );
      await tester.tap(find.text('Tambah pinjaman'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nama pihak'),
        'Person',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Pokok IDR'),
        '0.001',
      );
      await tester.tap(find.text('Simpan lokal'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(repo.outbox, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextField, 'Pokok IDR'),
        '1.01',
      );
      await tester.tap(find.text('Simpan lokal'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Pecahan tidak dibulatkan atau disimpan'),
        findsWidgets,
      );
      expect(repo.outbox, isEmpty);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Nama pihak'))
            .controller!
            .text,
        'Person',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Pokok IDR'),
        '100',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Jatuh tempo (YYYY-MM-DD, opsional)'),
        '2026-12-20',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Jadwal pokok cicilan (opsional)'),
        '2026-11-20=40\n2026-12-20=60',
      );
      await tester.tap(find.text('Simpan lokal'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.rows('obligations').single['counterparty'], 'Person');
      expect(
        repo.row('accounts', cashId)!['balance'],
        '1000.00',
      ); // Existing opening, no new funding.
      expect(repo.outbox.single['payload']['action'], 'OPEN');
      acceptProjection(repo);
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      expect(find.text('Sisa utang: ••••••'), findsOneWidget);
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Utang • Person'));
      await tester.tap(find.text('Utang • Person'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bayar / terima'));
      await tester.tap(find.text('Bayar / terima'));
      await tester.pumpAndSettle();
      final account = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Akun kas pembayaran',
      );
      await tester.tap(account);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Pokok dibayar IDR'),
        '40',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Bunga IDR'), '2');
      await tester.enterText(find.widgetWithText(TextField, 'Biaya IDR'), '1');
      for (final label in ['Kategori bunga', 'Kategori biaya']) {
        final picker = find.widgetWithText(
          DropdownButtonFormField<String>,
          label,
        );
        await tester.ensureVisible(picker);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Costs').last);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Simpan lokal'));
      await tester.pumpAndSettle();
      expect(repo.outbox.single['payload']['action'], 'REPAY');
      expect(repo.row('accounts', cashId)!['balance'], '957.00');
      expect(repo.rows('obligations').single['outstanding'], '60.00');
      expect(tester.takeException(), isNull);
    },
  );
}
