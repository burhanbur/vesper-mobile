import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/investments/pages/investment_lifecycle_page.dart';
import 'package:vesper_mobile/features/investments/widgets/offline_investment_trade_form.dart';

import '../fixtures/cached_finance.dart';

void main() {
  testWidgets('offline instrument and quote saves, dividend entry and privacy', (
    tester,
  ) async {
    const investment = '11111111-1111-4111-8111-111111111111';
    const cash = '22222222-2222-4222-8222-222222222222';
    const instrument = '33333333-3333-4333-8333-333333333333';
    final state = cachedFinanceState()..currentUserId = 'user';
    addTearDown(state.dispose);
    final repo = state.repository!;
    repo.offline = true;
    repo.atomic(() {
      repo.entities['account_types'] = {
        'invest': {'id': 'invest', 'user_id': 'user', 'category': 'INVESTMENT'},
        'cash': {'id': 'cash', 'user_id': 'user', 'category': 'CASH'},
      };
      repo.entities['accounts'] = {
        investment: {
          'id': investment,
          'name': 'Portfolio',
          'user_id': 'user',
          'currency': 'IDR',
          'account_type_id': 'invest',
          'balance': '0.00',
        },
        cash: {
          'id': cash,
          'name': 'Cash',
          'user_id': 'user',
          'currency': 'IDR',
          'account_type_id': 'cash',
          'balance': '100.00',
        },
      };
      repo.entities['instruments'] = {
        instrument: {
          'id': instrument,
          'code': 'TEST',
          'name': 'Test asset',
          'type': 'STOCK',
          'currency': 'IDR',
        },
      };
      repo.state['investment_history_coverage'] = {
        'schema': 1,
        'user_id': 'user',
        'complete': true,
        'cursor': repo.state['cursor'],
      };
    });
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(home: InvestmentLifecyclePage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah instrumen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan lokal'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Kode'), 'NEW');
    await tester.enterText(find.widgetWithText(TextField, 'Nama'), 'New asset');
    await tester.tap(find.text('Simpan lokal'));
    await tester.pumpAndSettle();
    expect(repo.pendingInvestmentCatalog, hasLength(1));
    expect(repo.rows('instruments'), hasLength(2));
    expect(find.byType(AlertDialog), findsNothing);

    final quoteAction = find.descendant(
      of: find.widgetWithText(ListTile, 'NEW • New asset'),
      matching: find.text('Harga'),
    );
    await tester.scrollUntilVisible(
      quoteAction,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Sorted catalogue: NEW is first. Quotes can be queued behind its creation.
    await tester.tap(quoteAction);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Harga IDR (maks. 8 desimal)'),
      '12.34567890',
    );
    await tester.tap(find.text('Simpan lokal'));
    await tester.pumpAndSettle();
    expect(repo.pendingInvestmentCatalog, hasLength(2));

    await tester.scrollUntilVisible(
      find.text('Beli / Jual / Dividen'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Beli / Jual / Dividen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DIVIDEN'));
    await tester.pumpAndSettle();
    final pickers = find.descendant(
      of: find.byType(OfflineInvestmentTradeForm),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    for (final selection in [
      (0, 'Portfolio'),
      (1, 'Test asset'),
      (2, 'Cash'),
    ]) {
      await tester.ensureVisible(pickers.at(selection.$1));
      await tester.tap(pickers.at(selection.$1));
      await tester.pumpAndSettle();
      await tester.tap(find.text(selection.$2).last);
      await tester.pumpAndSettle();
    }
    final form = find.byType(OfflineInvestmentTradeForm);
    final fields = find.descendant(of: form, matching: find.byType(TextField));
    await tester.enterText(fields.at(0), '2');
    await tester.enterText(fields.at(1), '1.005');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Simpan lokal'),
          )
          .onPressed,
      isNotNull,
      reason: tester
          .widgetList<Text>(
            find.descendant(of: form, matching: find.byType(Text)),
          )
          .map((t) => t.data)
          .join('\n'),
    );
    await tester.ensureVisible(find.text('Simpan lokal'));
    await tester.tap(find.text('Simpan lokal'));
    await tester.pumpAndSettle();
    expect(repo.outbox.single['payload']['type'], 'DIVIDEND');
    expect(repo.row('accounts', cash)!['balance'], '102.01');
    expect(find.byType(OfflineInvestmentTradeForm), findsNothing);
    expect(find.text('Dividen bersih: IDR 2.01'), findsOneWidget);
    state.toggleHideBalance();
    await tester.pumpAndSettle();
    expect(find.textContaining('IDR 2.01'), findsNothing);
    expect(find.text('Dividen bersih: ••••••'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
