import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/accounts/widgets/balance_adjustment_dialog.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

void main() {
  late LocalStore store;
  late FinanceRepository repo;
  late AppState state;
  setUp(() {
    store = LocalStore(sqlite3.openInMemory());
    repo = FinanceRepository(ApiClient(), store, 'user');
    repo.atomic(() {
      repo.entities['accounts'] = <String, dynamic>{
        'account': <String, dynamic>{
          'id': 'account',
          'name': 'Cash',
          'user_id': 'user',
          'balance': '1000000.00',
        },
      };
    });
    state = AppState(repository: repo)..currentUserId = 'user';
    state.toggleOfflineMode();
  });
  tearDown(() {
    state.dispose();
    store.close();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    BalanceAdjustmentDialog(state: state, accountId: 'account'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Prepopulates current target and saves signed income offline', (
    tester,
  ) async {
    await open(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Rp 1.000.000',
    );
    await tester.enterText(find.byType(TextField), '2000000');
    await tester.pump();
    expect(find.textContaining('Pemasukan: +'), findsOneWidget);
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(repo.row('accounts', 'account')!['balance'], '2000000.00');
    expect(
      repo.rows('transactions').single['description'],
      'Penyesuaian saldo',
    );
    expect(store.read(), repo.state);
  });

  testWidgets(
    'Rejects fractional input, previews expense, and prevents stale save',
    (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), '1.5');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), '500000');
      await tester.pump();
      expect(find.textContaining('Pengeluaran: -'), findsOneWidget);
      state.adjustAccountBalance('account', 1500000);
      await tester.pump();
      expect(find.textContaining('Saldo berubah.'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(repo.rows('transactions'), hasLength(1));
    },
  );

  testWidgets('Equal target closes without mutation', (tester) async {
    await open(tester);
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(repo.outbox, isEmpty);
    expect(find.byType(BalanceAdjustmentDialog), findsNothing);
  });
}
