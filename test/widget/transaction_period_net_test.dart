import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/transactions/pages/transactions_page.dart';

import '../fixtures/cached_finance.dart';

void main() {
  for (final income in [200, 500, 700]) {
    testWidgets(
      'Monthly net with income $income excludes transfers and hides safely',
      (tester) async {
        final state = cachedFinanceState()..currentUserId = 'user';
        addTearDown(state.dispose);
        state.repository!.atomic(() {
          state.repository!.entities['transactions'] = {
            for (final entry in {
              'INCOME': income,
              'EXPENSE': 500,
              'TRANSFER': 9000,
            }.entries)
              entry.key: {
                'id': entry.key,
                'account_id': 'cash',
                'category_id': entry.key == 'INCOME' ? 'salary' : 'food',
                'type': entry.key,
                'amount': '${entry.value}.00',
                'transacted_at': DateTime.now().toUtc().toIso8601String(),
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
        final summary = find.byKey(const ValueKey('transaction_period_net'));
        expect(
          find.descendant(
            of: summary,
            matching: find.text(
              income < 500
                  ? 'Defisit bulan ini'
                  : income > 500
                  ? 'Surplus bulan ini'
                  : 'Seimbang bulan ini',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: summary,
            matching: find.text(
              income < 500
                  ? '-Rp 300'
                  : income > 500
                  ? '+Rp 200'
                  : 'Rp 0',
            ),
          ),
          findsOneWidget,
        );
        state.toggleHideBalance();
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: summary,
            matching: find.text('Surplus / Defisit'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: summary, matching: find.text('••••••')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
