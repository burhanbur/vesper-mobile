import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/investments/models/investment.dart';
import 'package:vesper_mobile/features/investments/widgets/offline_investment_trade_form.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

void main() {
  testWidgets(
    'recovery requires confirmation and retains the original command',
    (tester) async {
      final store = LocalStore(sqlite3.openInMemory());
      final repo = FinanceRepository(ApiClient(), store, 'actor')
        ..offline = true;
      repo.atomic(() {
        repo.outbox.add(<String, dynamic>{
          'id': 'queue',
          'entity_id': 'trade',
          'entity_type': 'investment_transactions',
          'operation': 'CREATE',
          'status': 'rejected',
          'payload': <String, dynamic>{'quantity': '1.00000000'},
        });
      });
      final state = AppState(repository: repo);
      addTearDown(state.dispose);
      addTearDown(store.close);
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(
            home: Scaffold(
              body: OfflineInvestmentTradeForm(
                initialType: InvestmentTradeType.buy,
              ),
            ),
          ),
        ),
      );
      final retry = find.text('Coba ulang command asli');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(repo.outbox.single['status'], 'rejected');
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(repo.outbox.single['status'], 'rejected');
      await tester.tap(retry);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coba ulang'));
      await tester.pumpAndSettle();
      final restarted = FinanceRepository(ApiClient(), store, 'actor');
      expect(restarted.outbox.single['id'], 'queue');
      expect(restarted.outbox.single['entity_id'], 'trade');
      expect(restarted.outbox.single['status'], 'pending');
      expect(restarted.outbox.single['payload'], {'quantity': '1.00000000'});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('incomplete offline history disables saving without a crash', (
    tester,
  ) async {
    final store = LocalStore(sqlite3.openInMemory());
    final repo = FinanceRepository(ApiClient(), store, 'actor')..offline = true;
    final state = AppState(repository: repo);
    addTearDown(state.dispose);
    addTearDown(store.close);
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(
          home: Scaffold(
            body: OfflineInvestmentTradeForm(
              initialType: InvestmentTradeType.buy,
            ),
          ),
        ),
      ),
    );
    expect(
      find.text('Selesaikan sinkronisasi awal sebelum mencatat investasi.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(repo.outbox, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('decimal BUY form saves a durable offline command', (
    tester,
  ) async {
    const portfolio = '11111111-1111-4111-8111-111111111111';
    const cash = '22222222-2222-4222-8222-222222222222';
    const instrument = '33333333-3333-4333-8333-333333333333';
    final store = LocalStore(sqlite3.openInMemory());
    final repo = FinanceRepository(ApiClient(), store, 'actor')..offline = true;
    repo.atomic(() {
      repo.entities['account_types'] = {
        'invest': {
          'id': 'invest',
          'user_id': 'actor',
          'category': 'INVESTMENT',
        },
        'cash': {'id': 'cash', 'user_id': 'actor', 'category': 'CASH'},
      };
      repo.entities['accounts'] = {
        portfolio: {
          'id': portfolio,
          'name': 'Portfolio test',
          'user_id': 'actor',
          'account_type_id': 'invest',
          'currency': 'IDR',
          'balance': '0.00',
        },
        cash: {
          'id': cash,
          'name': 'Cash test',
          'user_id': 'actor',
          'account_type_id': 'cash',
          'currency': 'IDR',
          'balance': '100.00',
        },
      };
      repo.entities['instruments'] = {
        instrument: {'id': instrument, 'name': 'Stock test', 'currency': 'IDR'},
      };
      repo.state['investment_history_coverage'] = {
        'schema': 1,
        'user_id': 'actor',
        'complete': true,
        'cursor': repo.state['cursor'],
      };
    });
    final state = AppState(repository: repo);
    addTearDown(state.dispose);
    addTearDown(store.close);
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const OfflineInvestmentTradeForm(
                      initialType: InvestmentTradeType.buy,
                    ),
                  ),
                  child: const Text('Open trade'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open trade'));
    await tester.pumpAndSettle();
    for (final choice in [
      (0, 'Portfolio test'),
      (1, 'Stock test'),
      (2, 'Cash test'),
    ]) {
      await tester.tap(
        find.byType(DropdownButtonFormField<String>).at(choice.$1),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(choice.$2).last);
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextField).at(0), '1');
    await tester.enterText(find.byType(TextField).at(1), '10.005');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simpan lokal'));
    await tester.tap(find.text('Simpan lokal'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final restarted = FinanceRepository(ApiClient(), store, 'actor');
    expect(restarted.outbox, hasLength(1));
    expect(restarted.outbox.single['payload']['price_per_unit'], '10.005');
    expect(restarted.row('accounts', cash)!['balance'], '89.99');
    expect(
      restarted.investmentHistory(portfolio).position(instrument).quantity,
      '1.00000000',
    );
  });
}
