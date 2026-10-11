import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/features/accounts/models/account.dart';
import 'package:vesper_mobile/features/accounts/widgets/account_picker_sheet.dart';

void main() {
  const accounts = [
    Account(
      id: 'investment',
      name: 'Bareksa',
      type: AccountType.investment,
      balance: 0,
      accountNumber: '',
    ),
    Account(
      id: 'cash',
      name: 'Dompet',
      type: AccountType.cash,
      balance: 0,
      accountNumber: '',
    ),
  ];

  testWidgets('Cash appears before investments regardless of account order', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AccountPickerSheet(
            accounts: accounts,
            accountUniverse: accounts,
            isBalanceHidden: false,
          ),
        ),
      ),
    );
    expect(find.text('Cash'), findsNWidgets(2));
    expect(find.text('Investasi'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Cash').first).dy,
      lessThan(tester.getTopLeft(find.text('Dompet')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Dompet')).dy,
      lessThan(tester.getTopLeft(find.text('Investasi')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Investasi')).dy,
      lessThan(tester.getTopLeft(find.text('Bareksa')).dy),
    );
    await tester.tap(find.text('Dompet'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empty sections are not displayed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountPickerSheet(
            accounts: [accounts.first],
            accountUniverse: accounts,
            isBalanceHidden: false,
          ),
        ),
      ),
    );
    expect(find.text('Cash'), findsNothing);
    expect(find.text('Investasi'), findsOneWidget);
  });
}
