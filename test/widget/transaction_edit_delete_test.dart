import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';
import 'package:vesper_mobile/features/transactions/models/transaction.dart';
import 'package:vesper_mobile/features/transactions/widgets/transaction_item_tile.dart';

class _LocalClient extends ApiClient {
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async => throw StateError('No network in transaction tests');
}

void main() {
  testWidgets(
    'Transaction tile detail shows edit and delete, and deletes correctly',
    (tester) async {
      final store = LocalStore(sqlite3.openInMemory());
      final repo = FinanceRepository(_LocalClient(), store, 'user');
      repo.atomic(() {
        repo.entities['accounts'] = {
          'acc_1': {
            'id': 'acc_1',
            'name': 'Dompet',
            'user_id': 'user',
            'balance': '100000.00',
          },
        };
        repo.entities['categories'] = {
          'cat_1': {
            'id': 'cat_1',
            'name': 'Makan',
            'type': 'EXPENSE',
            'user_id': 'user',
          },
        };
        repo.entities['transactions'] = {
          'tx_1': {
            'id': 'tx_1',
            'account_id': 'acc_1',
            'category_id': 'cat_1',
            'type': 'EXPENSE',
            'amount': '25000.00',
            'transacted_at': '2026-10-01T12:00:00.000Z',
            'description': 'Makan siang',
            'version': '1',
            'user_id': 'user',
          },
        };
      });

      final state = AppState(repository: repo)..currentUserId = 'user';
      state.toggleOfflineMode();
      addTearDown(state.dispose);
      addTearDown(store.close);

      final tx = state.transactions.first;

      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(body: TransactionItemTile(transaction: tx)),
          ),
        ),
      );

      // Tap the tile to open detail bottom sheet
      await tester.tap(find.text('Makan siang'));
      await tester.pumpAndSettle();

      // Verify detail sheet is displayed with "Ubah" and "Hapus" buttons
      expect(find.text('Detail Transaksi'), findsOneWidget);
      expect(find.text('Ubah'), findsOneWidget);
      expect(find.text('Hapus'), findsOneWidget);

      // Tap "Hapus"
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();

      // Confirm dialog
      expect(find.text('Hapus Transaksi?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Hapus'));
      await tester.pumpAndSettle();

      // After deletion: transactions list empty and account balance refunded
      expect(state.transactions.isEmpty, isTrue);
      // 100,000 + 25,000 = 125,000
      expect(state.getAccountById('acc_1')!.balance, 125000);
    },
  );

  testWidgets(
    'Transfer tile detail shows edit and delete, and deletes transfer atomically',
    (tester) async {
      final store = LocalStore(sqlite3.openInMemory());
      final repo = FinanceRepository(_LocalClient(), store, 'user');
      repo.atomic(() {
        repo.entities['accounts'] = {
          'acc_1': {
            'id': 'acc_1',
            'name': 'Dompet',
            'user_id': 'user',
            'currency': 'IDR',
            'balance': '100000.00',
            'version': '1',
          },
          'acc_2': {
            'id': 'acc_2',
            'name': 'Tabungan',
            'user_id': 'user',
            'currency': 'IDR',
            'balance': '50000.00',
            'version': '1',
          },
        };
      });

      final state = AppState(repository: repo)..currentUserId = 'user';
      state.toggleOfflineMode();
      addTearDown(state.dispose);
      addTearDown(store.close);

      state.addTransaction(
        type: TransactionType.transfer,
        amount: 20000,
        accountId: 'acc_1',
        toAccountId: 'acc_2',
        categoryName: '',
        date: DateTime.utc(2026, 10, 1),
        note: 'Transfer ke tabungan',
      );

      expect(state.transactions, hasLength(2));
      expect(state.getAccountById('acc_1')!.balance, 80000);
      expect(state.getAccountById('acc_2')!.balance, 70000);

      final transferTx = state.transactions.first;

      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(body: TransactionItemTile(transaction: transferTx)),
          ),
        ),
      );

      // Tap the tile to open detail bottom sheet
      await tester.tap(find.text('Transfer ke tabungan').first);
      await tester.pumpAndSettle();

      // Verify detail sheet is displayed with "Ubah" and "Hapus" buttons for transfer!
      expect(find.text('Detail Transaksi'), findsOneWidget);
      expect(find.text('Ubah'), findsOneWidget);
      expect(find.text('Hapus'), findsOneWidget);

      // Tap "Hapus"
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();

      // Confirm dialog for transfer
      expect(find.text('Hapus Transfer?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Hapus'));
      await tester.pumpAndSettle();

      // After deletion: both transfer legs deleted and both account balances restored!
      expect(state.transactions.isEmpty, isTrue);
      expect(state.getAccountById('acc_1')!.balance, 100000);
      expect(state.getAccountById('acc_2')!.balance, 50000);
    },
  );

  testWidgets(
    'Transfer tile detail allows editing and updating transfer atomically',
    (tester) async {
      final store = LocalStore(sqlite3.openInMemory());
      final repo = FinanceRepository(_LocalClient(), store, 'user');
      repo.atomic(() {
        repo.entities['accounts'] = {
          'acc_1': {
            'id': 'acc_1',
            'name': 'Dompet',
            'user_id': 'user',
            'currency': 'IDR',
            'balance': '100000.00',
            'version': '1',
          },
          'acc_2': {
            'id': 'acc_2',
            'name': 'Tabungan',
            'user_id': 'user',
            'currency': 'IDR',
            'balance': '50000.00',
            'version': '1',
          },
        };
      });

      final state = AppState(repository: repo)..currentUserId = 'user';
      state.toggleOfflineMode();
      addTearDown(state.dispose);
      addTearDown(store.close);

      state.addTransaction(
        type: TransactionType.transfer,
        amount: 20000,
        accountId: 'acc_1',
        toAccountId: 'acc_2',
        categoryName: '',
        date: DateTime.utc(2026, 10, 1),
        note: 'Transfer awal',
      );

      final transferTx = state.transactions.first;

      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(body: TransactionItemTile(transaction: transferTx)),
          ),
        ),
      );

      // Tap tile to open detail bottom sheet
      await tester.tap(find.text('Transfer awal').first);
      await tester.pumpAndSettle();

      // Tap "Ubah"
      await tester.tap(find.text('Ubah'));
      await tester.pumpAndSettle();

      // Edit modal should open with title "Ubah Transaksi"
      expect(find.text('Ubah Transaksi'), findsOneWidget);
      expect(find.text('Simpan Perubahan'), findsOneWidget);

      // Update amount
      final amountFinder = find.widgetWithText(TextFormField, 'Rp 20.000');
      if (amountFinder.evaluate().isNotEmpty) {
        await tester.enterText(amountFinder, '35000');
      } else {
        await tester.enterText(find.byType(TextFormField).first, '35000');
      }
      await tester.pumpAndSettle();

      // Tap "Simpan Perubahan"
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      // Balances should be adjusted to reflect 35,000 transfer:
      // acc_1: 100,000 - 35,000 = 65,000
      // acc_2: 50,000 + 35,000 = 85,000
      expect(state.getAccountById('acc_1')!.balance, 65000);
      expect(state.getAccountById('acc_2')!.balance, 85000);
      expect(state.transactions.first.amount, 35000);
    },
  );
}
