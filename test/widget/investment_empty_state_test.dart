import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/investments/widgets/investment_trade_modal.dart';

void main() {
  testWidgets(
    'Investment safety dialog supports large text on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState();
      addTearDown(state.dispose);
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => InvestmentTradeModal.show(context),
                  child: const Text('Aset Baru'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Aset Baru'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Transaksi Belum Tersedia'), findsOneWidget);
      await tester.ensureVisible(find.text('Mengerti'));
      await tester.tap(find.text('Mengerti'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
    expect(find.text('Transaksi Belum Tersedia'), findsOneWidget);
    expect(
      find.textContaining('tidak ada transaksi yang disimpan'),
      findsOneWidget,
    );
    await tester.tap(find.text('Mengerti'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
