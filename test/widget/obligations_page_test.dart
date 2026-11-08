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
  for (final receivable in [false, true]) {
    testWidgets(
      'new loan moves cash in the chosen direction offline: receivable=$receivable',
      (tester) async {
        final store = LocalStore(sqlite3.openInMemory());
        final repo = FinanceRepository(ApiClient(), store, 'owner')
          ..offline = true;
        seedObligations(repo);
        final state = AppState(repository: repo)..currentUserId = 'owner';
        addTearDown(state.dispose);
        await tester.pumpWidget(
          AppStateScope(
            state: state,
            child: const MaterialApp(home: ObligationsPage()),
          ),
        );
        await tester.tap(find.byTooltip('Tambah utang / piutang'));
        await tester.pumpAndSettle();
        if (receivable) {
          await tester.tap(
            find.widgetWithText(DropdownButtonFormField<String>, 'Jenis'),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Orang berutang ke saya').last);
          await tester.pumpAndSettle();
        }
        await tester.enterText(
          find.widgetWithText(
            TextField,
            receivable ? 'Yang berutang ke saya' : 'Saya berutang kepada',
          ),
          'Budi',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Jumlah pinjaman'),
          '100',
        );
        final funding = find.widgetWithText(
          DropdownButtonFormField<String>,
          receivable ? 'Uang keluar dari' : 'Uang masuk ke',
        );
        await tester.ensureVisible(funding);
        await tester.tap(funding);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cash').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();
        expect(
          repo.row('accounts', cashId)!['balance'],
          receivable ? '900.00' : '1100.00',
        );
        expect(
          repo.rows('obligations').single['kind'],
          receivable ? 'RECEIVABLE' : 'PAYABLE',
        );
        expect(repo.outbox.single['payload']['installments'], isEmpty);
        expect(repo.rows('transactions').single['type'], 'TRANSFER');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final balance in ['1000000.00', '-1000000.00']) {
    testWidgets(
      'legacy balance $balance opens a mapped record without new cash',
      (tester) async {
        final store = LocalStore(sqlite3.openInMemory());
        final repo = FinanceRepository(ApiClient(), store, 'owner')
          ..offline = true;
        seedObligations(repo);
        repo.atomic(
          () => repo.entities['accounts']![cashId]!['balance'] = balance,
        );
        final state = AppState(repository: repo)..currentUserId = 'owner';
        addTearDown(state.dispose);
        await tester.pumpWidget(
          AppStateScope(
            state: state,
            child: const MaterialApp(
              home: ObligationsPage(initialLinkedAccountId: cashId),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(
          find.text(
            balance.startsWith('-')
                ? 'Saya berutang'
                : 'Orang berutang ke saya',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(
                find.widgetWithText(TextField, 'Jumlah pinjaman'),
              )
              .controller!
              .text,
          '1.000.000',
        );
        expect(
          tester
              .widget<TextField>(
                find.widgetWithText(TextField, 'Jumlah pinjaman'),
              )
              .decoration!
              .prefixText,
          'Rp ',
        );
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
          isNull,
        );
        await tester.enterText(
          find.widgetWithText(
            TextField,
            balance.startsWith('-')
                ? 'Saya berutang kepada'
                : 'Yang berutang ke saya',
          ),
          'Budi',
        );
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();
        final record = repo.rows('obligations').single;
        expect(
          record['kind'],
          balance.startsWith('-') ? 'PAYABLE' : 'RECEIVABLE',
        );
        expect(record['linked_account_id'], cashId);
        expect(record['outstanding'], '1000000.00');
        expect(repo.outbox.single['payload']['principal'], '1000000.00');
        expect(
          find.text(
            balance.startsWith('-')
                ? 'Sisa utang: Rp 1.000.000'
                : 'Sisa piutang: Rp 1.000.000',
          ),
          findsOneWidget,
        );
        expect(repo.row('accounts', cashId)!['balance'], balance);
        expect(repo.rows('transactions'), isEmpty);
        expect(repo.outbox.single['payload']['cash_account_id'], isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

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
      await tester.tap(find.byTooltip('Tambah utang / piutang'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Saya berutang kepada'),
        'Person',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Jumlah pinjaman'),
        '0.001',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(repo.outbox, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextField, 'Jumlah pinjaman'),
        '1.01',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Pecahan tidak dibulatkan atau disimpan'),
        findsWidgets,
      );
      expect(repo.outbox, isEmpty);
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Jumlah pinjaman'),
            )
            .controller!
            .text,
        '1,01',
      );
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Saya berutang kepada'),
            )
            .controller!
            .text,
        'Person',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Jumlah pinjaman'),
        '100',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Jatuh tempo (YYYY-MM-DD, opsional)'),
        '2026-12-20',
      );
      expect(find.text('Jadwal pokok cicilan (opsional)'), findsNothing);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(repo.rows('obligations').single['counterparty'], 'Person');
      expect(
        repo.row('accounts', cashId)!['balance'],
        '1000.00',
      ); // Existing opening, no new funding.
      expect(repo.outbox.single['payload']['action'], 'OPEN');
      expect(find.text('Sisa utang: Rp 100'), findsOneWidget);
      expect(find.text('Sisa piutang: Rp 0'), findsOneWidget);
      acceptProjection(repo);
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      expect(find.text('Sisa utang: ••••••'), findsOneWidget);
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Utang • Person'));
      await tester.tap(find.text('Utang • Person'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bayar / cicil'));
      await tester.tap(find.text('Bayar / cicil'));
      await tester.pumpAndSettle();
      final account = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Bayar dari rekening',
      );
      await tester.tap(account);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Jumlah pembayaran'),
        '40',
      );
      expect(find.text('Bunga IDR'), findsNothing);
      await tester.tap(find.text('Ada bunga atau biaya tambahan'));
      await tester.pumpAndSettle();
      for (final label in ['Bunga IDR', 'Biaya IDR']) {
        await tester.enterText(
          find.widgetWithText(TextField, label),
          '1000.01',
        );
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();
        expect(repo.outbox, isEmpty);
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.textContaining(
              'Pecahan tidak dibulatkan atau disimpan',
            ),
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, label))
              .controller!
              .text,
          '1.000,01',
        );
        await tester.enterText(find.widgetWithText(TextField, label), '0');
      }
      await tester.enterText(
        find.widgetWithText(TextField, 'Bunga IDR'),
        '2000',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Biaya IDR'),
        '1000',
      );
      for (final label in ['Bunga IDR', 'Biaya IDR']) {
        expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, label))
              .decoration!
              .prefixText,
          'Rp ',
        );
      }
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Bunga IDR'))
            .controller!
            .text,
        '2.000',
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Biaya IDR'))
            .controller!
            .text,
        '1.000',
      );
      // The payment below needs sufficient cash for its grouped interest/fee.
      repo.atomic(
        () => repo.entities['accounts']![cashId]!['balance'] = '10000.00',
      );
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
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repo.outbox.single['payload']['action'], 'REPAY');
      expect(repo.outbox.single['payload']['principal'], '40.00');
      expect(repo.outbox.single['payload']['interest'], '2000.00');
      expect(repo.outbox.single['payload']['fee'], '1000.00');
      expect(repo.row('accounts', cashId)!['balance'], '6960.00');
      expect(repo.rows('obligations').single['outstanding'], '60.00');
      expect(tester.takeException(), isNull);
    },
  );
}
