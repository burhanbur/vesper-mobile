import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/features/investments/data/portfolio_repository.dart';
import 'package:vesper_mobile/features/reports/data/financial_export_repository.dart';

import '../fixtures/cached_finance.dart';

void main() {
  test('all account dropdown repositories exclude parent accounts with children', () {
    final state = cachedFinanceState();
    addTearDown(state.dispose);
    final repo = state.repository!;
    repo.atomic(() {
      repo.entities['account_types'] = {
        'cash-type': {
          'id': 'cash-type',
          'user_id': 'user',
          'category': 'CASH',
          'name': 'Bank',
        },
        'inv-type': {
          'id': 'inv-type',
          'user_id': 'user',
          'category': 'INVESTMENT',
          'name': 'Reksadana',
        },
      };
      repo.entities['accounts'] = {
        'cash-parent': {
          'id': 'cash-parent',
          'name': 'Bank Jago',
          'user_id': 'user',
          'currency': 'IDR',
          'account_type_id': 'cash-type',
          'balance': '0.00',
        },
        'cash-child': {
          'id': 'cash-child',
          'name': 'Kantong Utama',
          'parent_account_id': 'cash-parent',
          'user_id': 'user',
          'currency': 'IDR',
          'account_type_id': 'cash-type',
          'balance': '1500000.00',
        },
        'cash-leaf': {
          'id': 'cash-leaf',
          'name': 'BCA',
          'user_id': 'user',
          'currency': 'IDR',
          'account_type_id': 'cash-type',
          'balance': '5000000.00',
        },
        'inv-parent': {
          'id': 'inv-parent',
          'name': 'Bibit',
          'user_id': 'user',
          'currency': 'IDR',
          'account_type_id': 'inv-type',
          'balance': '0.00',
        },
        'inv-child': {
          'id': 'inv-child',
          'name': 'Syailendra Fixed Income',
          'parent_account_id': 'inv-parent',
          'user_id': 'user',
          'currency': 'IDR',
          'account_type_id': 'inv-type',
          'balance': '10000000.00',
        },
        'inv-leaf': {
          'id': 'inv-leaf',
          'name': 'Stockbit',
          'user_id': 'user',
          'currency': 'IDR',
          'account_type_id': 'inv-type',
          'balance': '2000000.00',
        },
      };
    });

    // 1. PortfolioRepository hides inv-parent
    final portfolioAccounts = PortfolioRepository(repo).accounts;
    expect(
      portfolioAccounts.map((a) => a.id).toSet(),
      {'inv-child', 'inv-leaf'},
    );
    expect(
      portfolioAccounts.firstWhere((a) => a.id == 'inv-child').parentName,
      'Bibit',
    );

    // 2. FinanceRepository.canTradeAccount hides both cash-parent and inv-parent
    expect(repo.canTradeAccount('cash-parent', 'CASH'), isFalse);
    expect(repo.canTradeAccount('cash-child', 'CASH'), isTrue);
    expect(repo.canTradeAccount('cash-leaf', 'CASH'), isTrue);
    expect(repo.canTradeAccount('inv-parent', 'INVESTMENT'), isFalse);
    expect(repo.canTradeAccount('inv-child', 'INVESTMENT'), isTrue);
    expect(repo.canTradeAccount('inv-leaf', 'INVESTMENT'), isTrue);

    // 3. FinancialExportRepository.leafAccounts hides both parents
    final exportLeafIds = FinancialExportRepository(
      repo,
    ).leafAccounts.map((a) => a['id']).toSet();
    expect(exportLeafIds, {'cash-child', 'cash-leaf', 'inv-child', 'inv-leaf'});

    // 4. AppState.selectableAccounts hides both parents
    expect(
      state.selectableAccounts.map((a) => a.id).toSet(),
      {'cash-child', 'cash-leaf', 'inv-child', 'inv-leaf'},
    );
  });
}
