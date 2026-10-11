import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/transactions/pages/transactions_page.dart';
import 'package:vesper_mobile/features/transactions/widgets/add_transaction_modal.dart';

void main() {
  testWidgets(
    'Save stays visible before and after scrolling and above keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
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
                    onPressed: () => AddTransactionModal.show(context),
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('transaction_save_button'));
      expect(save.hitTestable(), findsOneWidget);
      final before = tester.getTopLeft(save);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(save), before);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(460));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Transaction header has search without duplicate add action', (
    tester,
  ) async {
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(home: TransactionsPage()),
      ),
    );
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline_rounded), findsNothing);
  });
}
