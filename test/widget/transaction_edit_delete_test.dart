import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';
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
}
