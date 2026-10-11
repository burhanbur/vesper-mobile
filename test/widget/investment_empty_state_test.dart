import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/investments/widgets/investment_trade_modal.dart';

void main() {
  testWidgets('Empty portfolio shows explanation instead of throwing', (
    tester,
  ) async {
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => InvestmentTradeModal.show(context),
                  child: const Text('Aset Baru'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aset Baru'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Belum ada aset investasi'), findsOneWidget);
    await tester.tap(find.text('Mengerti'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
