import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/features/reports/models/budget.dart';

import '../fixtures/cached_finance.dart';

void main() {
  group('BudgetItem formatting and models', () {
    test('formats raw decimal allowances without floating point errors', () {
      final item = BudgetItem(
        id: 'b-1',
        categoryId: 'cat-1',
        categoryName: 'Makanan',
        icon: 'restaurant',
        allocatedAmount: 1500000,
        spentAmount: 750000,
        periodType: 'MONTHLY',
        anchorDate: DateTime.utc(2026, 1, 1),
        period: '2026-03',
        rawAllowance: '1500000.50',
        rawSpent: '750000.00',
      );

      expect(item.allocatedDisplay, 'Rp 1.500.000,50');
      expect(item.spentDisplay, 'Rp 750.000');
      expect(item.remainingDisplay, 'Rp 750.000');
      expect(item.progressPercentage, closeTo(0.5, 0.001));
      expect(item.isOverBudget, isFalse);
    });

    test('detects over-budget and limits clamp correctly', () {
      final item = BudgetItem(
        id: 'b-2',
        categoryId: 'cat-2',
        categoryName: 'Belanja',
        icon: 'shopping_cart',
        allocatedAmount: 1000000,
        spentAmount: 1800000,
        periodType: 'MONTHLY',
        anchorDate: DateTime.utc(2026, 1, 1),
      );

      expect(item.isOverBudget, isTrue);
      expect(item.remainingAmount, -800000);
      expect(item.progressPercentage, 1.5);
    });
  });

  group('AppState budget period progress and local fallback', () {
    test('budgetsForPeriod returns cached period progress when available', () {
      final state = cachedFinanceState();
      addTearDown(state.dispose);
      final repo = state.repository!;

      repo.atomic(() {
        repo.entities['categories'] = {
          'cat-food': {
            'id': 'cat-food',
            'name': 'Makanan & Minuman',
            'type': 'EXPENSE',
          },
        };
        repo.entities['budgets'] = {
          'b-food': {
            'id': 'b-food',
            'category_id': 'cat-food',
            'anchor_date': '2026-01-15',
            'period_type': 'MONTHLY',
            'current_amount': '2000000.00',
          },
        };
        repo.state['progress:b-food:2026-03'] = {
          'period': '2026-03',
          'allowance': '2000000.00',
          'total_amount': '650000.00',
          'period_days': 31,
        };
      });

      final items = state.budgetsForPeriod(
        period: '2026-03',
        periodType: 'MONTHLY',
      );
      expect(items.length, 1);
      final b = items.first;
      expect(b.id, 'b-food');
      expect(b.allocatedAmount, 2000000);
      expect(b.spentAmount, 650000);
      expect(b.isLocalEstimate, isFalse);
      expect(b.periodDays, 31);
    });

    test(
      'budgetsForPeriod aggregates local transactions when cache is absent',
      () {
        final state = cachedFinanceState();
        addTearDown(state.dispose);
        final repo = state.repository!;

        repo.atomic(() {
          repo.entities['categories'] = {
            'cat-transport': {
              'id': 'cat-transport',
              'name': 'Transportasi',
              'type': 'EXPENSE',
            },
          };
          repo.entities['budgets'] = {
            'b-transport': {
              'id': 'b-transport',
              'category_id': 'cat-transport',
              'anchor_date': '2026-01-01',
              'period_type': 'MONTHLY',
              'current_amount': '1000000.00',
            },
          };
          repo.entities['transactions'] = {
            // Inside 2026-03 (anchor day 1 -> 2026-03-01 to 2026-04-01)
            'tx-1': {
              'id': 'tx-1',
              'type': 'EXPENSE',
              'amount': '-150000.00',
              'category_id': 'cat-transport',
              'transacted_at': '2026-03-05T10:00:00.000Z',
              'account_id': 'acc-1',
            },
            'tx-2': {
              'id': 'tx-2',
              'type': 'EXPENSE',
              'amount': '-250000.00',
              'category_id': 'cat-transport',
              'transacted_at': '2026-03-20T14:30:00.000Z',
              'account_id': 'acc-1',
            },
            // Outside 2026-03 (in February)
            'tx-3': {
              'id': 'tx-3',
              'type': 'EXPENSE',
              'amount': '-500000.00',
              'category_id': 'cat-transport',
              'transacted_at': '2026-02-28T09:00:00.000Z',
              'account_id': 'acc-1',
            },
            // Income transaction should not count
            'tx-4': {
              'id': 'tx-4',
              'type': 'INCOME',
              'amount': '1000000.00',
              'category_id': 'cat-transport',
              'transacted_at': '2026-03-10T11:00:00.000Z',
              'account_id': 'acc-1',
            },
          };
        });

        final items = state.budgetsForPeriod(
          period: '2026-03',
          periodType: 'MONTHLY',
        );
        expect(items.length, 1);
        final b = items.first;
        expect(b.allocatedAmount, 1000000);
        expect(b.spentAmount, 400000); // 150000 + 250000
        expect(b.isLocalEstimate, isTrue);
        expect(b.periodRange, isNotNull);
        expect(b.periodRange!.start, DateTime.utc(2026, 3, 1));
        expect(b.periodRange!.end, DateTime.utc(2026, 4, 1));
      },
    );
  });
}
