import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

void main() {
  group('Dynamic Monthly Net Worth Growth & Trend', () {
    test('Default empty state has 0.0% growth and flat trend', () {
      final store = LocalStore(sqlite3.openInMemory());
      addTearDown(store.close);
      final repo = FinanceRepository(ApiClient(), store, 'user-1');
      final appState = AppState(repository: repo);

      expect(appState.totalNetWorth, 0);
      expect(appState.monthIncome, 0);
      expect(appState.monthExpense, 0);
      expect(appState.monthNetSavings, 0);
      expect(appState.monthGrowthPercentage, 0.0);

      final trend = appState.monthNetWorthTrend;
      expect(trend, [0.0, 0.0]);
    });

    test('Positive income from zero wealth results in 100% growth and upward trend', () {
      final store = LocalStore(sqlite3.openInMemory());
      addTearDown(store.close);
      final repo = FinanceRepository(ApiClient(), store, 'user-1');
      final now = DateTime.now();
      repo.state = {
        'entities': {
          'accounts': {
            'acc-1': {
              'id': 'acc-1',
              'name': 'Dompet',
              'type': 'CASH',
              'balance': '1000000.00',
              'currency': 'IDR',
              'is_include_total': true,
              'version': 1,
            },
          },
          'categories': {
            'cat-1': {
              'id': 'cat-1',
              'name': 'Gaji',
              'type': 'INCOME',
              'user_id': 'user-1',
              'version': 1,
            },
          },
          'transactions': {
            'tx-1': {
              'id': 'tx-1',
              'account_id': 'acc-1',
              'category_id': 'cat-1',
              'type': 'INCOME',
              'amount': '1000000.00',
              'transacted_at': now.toUtc().toIso8601String(),
              'version': 1,
            },
          },
        },
        'outbox': <dynamic>[],
      };

      final appState = AppState(repository: repo);
      expect(appState.totalNetWorth, 1000000);
      expect(appState.monthIncome, 1000000);
      expect(appState.monthExpense, 0);
      expect(appState.monthNetSavings, 1000000);
      expect(appState.monthGrowthPercentage, 100.0);

      final trend = appState.monthNetWorthTrend;
      expect(trend.first, 0.0); // start of month was 0
      expect(trend.last, 1000000.0); // current net worth
    });

    test('Growth from starting balance calculates accurate percentage', () {
      final store = LocalStore(sqlite3.openInMemory());
      addTearDown(store.close);
      final repo = FinanceRepository(ApiClient(), store, 'user-1');
      final now = DateTime.now();

      // Started at 10.000.000, gained 500.000 this month -> Current = 10.500.000
      repo.state = {
        'entities': {
          'accounts': {
            'acc-1': {
              'id': 'acc-1',
              'name': 'BCA',
              'type': 'BANK',
              'balance': '10500000.00',
              'currency': 'IDR',
              'is_include_total': true,
              'version': 1,
            },
          },
          'categories': {
            'cat-1': {
              'id': 'cat-1',
              'name': 'Bonus',
              'type': 'INCOME',
              'user_id': 'user-1',
              'version': 1,
            },
          },
          'transactions': {
            'tx-1': {
              'id': 'tx-1',
              'account_id': 'acc-1',
              'category_id': 'cat-1',
              'type': 'INCOME',
              'amount': '500000.00',
              'transacted_at': now.toUtc().toIso8601String(),
              'version': 1,
            },
          },
        },
        'outbox': <dynamic>[],
      };

      final appState = AppState(repository: repo);
      expect(appState.totalNetWorth, 10500000);
      expect(appState.monthNetSavings, 500000);
      // startNetWorth = 10.500.000 - 500.000 = 10.000.000
      // Growth = (500.000 / 10.000.000) * 100% = 5.0%
      expect(appState.monthGrowthPercentage, closeTo(5.0, 0.001));
    });

    test('Negative growth when expenses exceed income', () {
      final store = LocalStore(sqlite3.openInMemory());
      addTearDown(store.close);
      final repo = FinanceRepository(ApiClient(), store, 'user-1');
      final now = DateTime.now();

      // Started at 10.000.000, spent 1.000.000 this month -> Current = 9.000.000
      repo.state = {
        'entities': {
          'accounts': {
            'acc-1': {
              'id': 'acc-1',
              'name': 'BCA',
              'type': 'BANK',
              'balance': '9000000.00',
              'currency': 'IDR',
              'is_include_total': true,
              'version': 1,
            },
          },
          'categories': {
            'cat-1': {
              'id': 'cat-1',
              'name': 'Belanja',
              'type': 'EXPENSE',
              'user_id': 'user-1',
              'version': 1,
            },
          },
          'transactions': {
            'tx-1': {
              'id': 'tx-1',
              'account_id': 'acc-1',
              'category_id': 'cat-1',
              'type': 'EXPENSE',
              'amount': '1000000.00',
              'transacted_at': now.toUtc().toIso8601String(),
              'version': 1,
            },
          },
        },
        'outbox': <dynamic>[],
      };

      final appState = AppState(repository: repo);
      expect(appState.totalNetWorth, 9000000);
      expect(appState.monthNetSavings, -1000000);
      // startNetWorth = 9.000.000 - (-1.000.000) = 10.000.000
      // Growth = (-1.000.000 / 10.000.000) * 100% = -10.0%
      expect(appState.monthGrowthPercentage, closeTo(-10.0, 0.001));

      final trend = appState.monthNetWorthTrend;
      expect(trend.first, 10000000.0);
      expect(trend.last, 9000000.0);
    });
  });
}
