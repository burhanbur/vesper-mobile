import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/accounts/pages/account_detail_page.dart';
import 'package:vesper_mobile/features/transactions/pages/transactions_page.dart';

import '../fixtures/cached_finance.dart';

void main() {
  for (final accountDetail in [false, true]) {
    testWidgets(
      '${accountDetail ? 'account' : 'transaction'} history exposes every page and resets on filter changes',
      (tester) async {
        final state = cachedFinanceState()..currentUserId = 'user';
        state.toggleOfflineMode();
        addTearDown(state.dispose);
        final now = DateTime.now();
        state.repository!.atomic(() {
          state.repository!.entities['transactions'] = {
            for (var i = 0; i < 205; i++)
              'tx-${i.toString().padLeft(3, '0')}': {
                'id': 'tx-${i.toString().padLeft(3, '0')}',
                'account_id': 'cash',
                'category_id': 'food',
                'amount': '1.00',
                'type': 'EXPENSE',
                'description': 'Purchase $i',
                'transacted_at': DateTime(
                  now.year,
                  now.month,
                  2,
                ).add(Duration(seconds: i)).toUtc().toIso8601String(),
              },
          };
        });
        await tester.pumpWidget(
          AppStateScope(
            state: state,
            child: MaterialApp(
              home: accountDetail
                  ? AccountDetailPage(accountId: 'cash', onSettings: () {})
                  : const TransactionsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Purchase 204'), findsOneWidget);
        Future<void> next() async {
          final button = find.byTooltip('Halaman transaksi berikutnya');
          await tester.scrollUntilVisible(
            button,
            1000,
            maxScrolls: 40,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(button);
          await tester.pumpAndSettle();
        }

        await next();
        expect(find.text('Purchase 104'), findsOneWidget);
        await next();
        expect(find.text('Purchase 4'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byTooltip('Halaman transaksi berikutnya'),
          500,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton &&
                      widget.tooltip == 'Halaman transaksi berikutnya',
                ),
              )
              .onPressed,
          isNull,
        );
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Halaman transaksi sebelumnya'));
        await tester.pumpAndSettle();
        expect(find.text('Purchase 104'), findsOneWidget);
        if (!accountDetail) {
          await tester.tap(find.widgetWithText(ChoiceChip, 'Pemasukan'));
          await tester.pumpAndSettle();
          expect(find.text('Halaman 1 · 0 ditampilkan'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
