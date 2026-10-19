import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/transactions/pages/transactions_page.dart';

import '../fixtures/cached_finance.dart';

void main() {
  testWidgets('TransactionsPage filters transactions by category', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    final state = cachedFinanceState()..currentUserId = 'user';
    addTearDown(state.dispose);
    final now = DateTime.now();

    state.repository!.atomic(() {
      state.repository!.entities['categories'] = <String, dynamic>{
        'food': {
          'id': 'food',
          'user_id': 'user',
          'name': 'Food',
          'type': 'EXPENSE',
          'version': '1',
        },
        'transport': {
          'id': 'transport',
          'user_id': 'user',
          'name': 'Transport',
          'type': 'EXPENSE',
          'version': '1',
        },
        'salary': {
          'id': 'salary',
          'user_id': 'user',
          'name': 'Salary',
          'type': 'INCOME',
          'version': '1',
        },
      };
      state.repository!.entities['transactions'] = {
        'tx-1': {
          'id': 'tx-1',
          'account_id': 'cash',
          'category_id': 'food',
          'amount': '50000.00',
          'type': 'EXPENSE',
          'description': 'Lunch',
          'transacted_at': DateTime(
            now.year,
            now.month,
            5,
          ).toUtc().toIso8601String(),
        },
        'tx-2': {
          'id': 'tx-2',
          'account_id': 'cash',
          'category_id': 'transport',
          'amount': '25000.00',
          'type': 'EXPENSE',
          'description': 'Train ticket',
          'transacted_at': DateTime(
            now.year,
            now.month,
            6,
          ).toUtc().toIso8601String(),
        },
        'tx-3': {
          'id': 'tx-3',
          'account_id': 'cash',
          'category_id': 'salary',
          'amount': '10000000.00',
          'type': 'INCOME',
          'description': 'Monthly Paycheck',
          'transacted_at': DateTime(
            now.year,
            now.month,
            1,
          ).toUtc().toIso8601String(),
        },
      };
    });

    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(home: TransactionsPage()),
      ),
    );
    await tester.pumpAndSettle();

    // Initially, Semua filter is active -> all 3 transactions visible
    expect(find.text('3 Transaksi'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Train ticket'), findsOneWidget);
    expect(find.text('Monthly Paycheck'), findsOneWidget);

    // "Semua Kategori" chip is present
    expect(find.text('Semua Kategori'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Food'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Transport'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Salary'), findsOneWidget);

    // Tap "Food" category chip
    await tester.tap(find.widgetWithText(ChoiceChip, 'Food'));
    await tester.pumpAndSettle();

    expect(find.text('1 Transaksi'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Train ticket'), findsNothing);
    expect(find.text('Monthly Paycheck'), findsNothing);

    // Tap "Semua Kategori" chip to reset category filter
    await tester.tap(find.text('Semua Kategori'));
    await tester.pumpAndSettle();

    expect(find.text('3 Transaksi'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Train ticket'), findsOneWidget);
    expect(find.text('Monthly Paycheck'), findsOneWidget);

    // Switch to "Pengeluaran" type filter
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pengeluaran'));
    await tester.pumpAndSettle();

    // Salary (income) should not be in the category chips anymore
    expect(find.text('2 Transaksi'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Food'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Transport'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Salary'), findsNothing);

    // Filter by Transport
    await tester.tap(find.widgetWithText(ChoiceChip, 'Transport'));
    await tester.pumpAndSettle();

    expect(find.text('1 Transaksi'), findsOneWidget);
    expect(find.text('Train ticket'), findsOneWidget);
    expect(find.text('Lunch'), findsNothing);

    // Tapping active chip again unselects it
    await tester.tap(find.widgetWithText(ChoiceChip, 'Transport'));
    await tester.pumpAndSettle();

    expect(find.text('2 Transaksi'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Train ticket'), findsOneWidget);
  });
}
