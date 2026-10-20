import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/finance_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';

import '../fixtures/cached_finance.dart';

// WM-01 characterization only. These assertions document current limitations;
// replace them with the intended contracts when WM-02/WM-03/WM-04 are delivered.
void main() {
  test(
    'baseline net worth uses included account balances, not portfolio cache',
    () {
      final state = cachedFinanceState();
      addTearDown(state.dispose);
      final repo = state.repository!;
      repo.atomic(() {
        final accounts = repo.entities['accounts'] as Map;
        for (final row in [
          ['investment', 'INVESTMENT', '500.00', true],
          ['debt', 'LOAN', '-200.00', true],
          ['excluded', 'BANK', '900.00', false],
        ]) {
          accounts[row[0]] = {
            'id': row[0],
            'user_id': 'user',
            'name': row[0],
            'type': row[1],
            'balance': row[2],
            'is_include_total': row[3],
            'version': '1',
          };
        }
        repo.entities['investment_read_cache'] = {
          'investment:2026-10-20': {
            'data': [],
            'fetched_at': '2026-10-20T00:00:00Z',
          },
        };
      });
      expect(state.investments, isEmpty);
      expect(state.totalLiquidCash, 100000);
      expect(state.totalInvestmentValue, 500);
      expect(state.totalDebt, 200);
      expect(state.totalNetWorth, 100300);
    },
  );

  test('baseline budget projects the single cached progress per budget', () {
    final state = cachedFinanceState();
    addTearDown(state.dispose);
    final repo = state.repository!;
    repo.atomic(() {
      repo.entities['budgets'] = {
        'budget': {
          'id': 'budget',
          'category_id': 'food',
          'period_type': 'MONTHLY',
          'anchor_date': '2026-01-15',
          'current_amount': '1000.00',
        },
      };
      repo.state['progress:budget'] = {
        'period': '2026-09',
        'allowance': '750.00',
        'total_amount': '125.00',
      };
    });
    expect(state.budgets.single.allocatedAmount, 750);
    expect(state.budgets.single.spentAmount, 125);
    expect(state.totalBudgetSpent, 125);
  });

  test('WM-04 offline budget save persists durably to local SQLite', () async {
    final state = cachedFinanceState();
    addTearDown(state.dispose);
    final repo = state.repository!;
    repo.offline = true;

    final result = await state.setCategoryBudget(
      categoryName: 'Food',
      allocatedAmount: 1000,
    );

    expect(result.isDurableLocal, isTrue);
    expect(result.isSyncedOnline, isFalse);
    expect(result.categoryName, 'Food');
    expect(result.allocatedAmount, 1000);
    expect(result.feedbackMessage, contains('tersimpan di perangkat'));

    // Durable local storage verified
    final budgetRows = repo.rows('budgets');
    expect(budgetRows.length, 1);
    expect(budgetRows.first['category_id'], 'food');
    expect(budgetRows.first['current_amount'], '1000.00');
    expect(budgetRows.first['sync_status'], 'pending');

    // In-memory state updated
    expect(state.budgets.any((b) => b.categoryId == 'food'), isTrue);
  });

  test(
    'integer Rupiah adapter rejects fractional amounts rather than rounding',
    () {
      expect(rupiah('123.00'), 123);
      expect(() => rupiah('123.50'), throwsA(isA<ApiFailure>()));
    },
  );
}
