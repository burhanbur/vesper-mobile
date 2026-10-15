import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/features/investments/models/investment.dart';
import 'package:vesper_mobile/features/transactions/models/transaction.dart';

import '../fixtures/cached_finance.dart';

void main() {
  group('Repository-backed finance rules', () {
    late AppState state;
    setUp(() {
      state = cachedFinanceState()..currentUserId = 'user';
      state.toggleOfflineMode();
    });
    tearDown(() => state.dispose());

    test(
      'Excluded parents and investment accounts do not inflate liquid cash',
      () {
        final repo = state.repository!;
        repo.atomic(() {
          repo.entities['account_types'] = {
            'investment': {
              'id': 'investment',
              'name': 'Investment',
              'category': 'INVESTMENT',
            },
          };
          (repo.entities['accounts'] as Map).addAll(<String, dynamic>{
            'parent': {
              'id': 'parent',
              'name': 'Parent',
              'balance': '300.00',
              'is_include_total': false,
            },
            'pocket-a': {
              'id': 'pocket-a',
              'name': 'Pocket A',
              'balance': '100.00',
              'parent_account_id': 'parent',
            },
            'pocket-b': {
              'id': 'pocket-b',
              'name': 'Pocket B',
              'balance': '200.00',
              'parent_account_id': 'parent',
            },
            'investment': {
              'id': 'investment',
              'name': 'Investment',
              'balance': '500.00',
              'account_type_id': 'investment',
            },
          });
        });
        expect(state.getAccountById('parent')!.isIncludeTotal, isFalse);
        expect(state.getChildrenForAccount('parent').map((a) => a.balance), [
          100,
          200,
        ]);
        expect(state.totalLiquidCash, 100300);
        expect(repo.store.read(), repo.state);
      },
    );

    test('Cached transfers are excluded from income and expense; missing destination fails safely', () {
      final repo = state.repository!;
      final date = DateTime.now().toUtc().toIso8601String();
      repo.atomic(() {
        repo.entities['transactions'] = {
          for (final row in [
            ['income', 'INCOME', '1000.00'],
            ['expense', 'EXPENSE', '200.00'],
            ['out', 'TRANSFER', '-500.00'],
            ['in', 'TRANSFER', '500.00'],
          ])
            row[0]: {
              'id': row[0],
              'account_id': 'cash',
              'type': row[1],
              'amount': row[2],
              'transacted_at': date,
              if (row[1] == 'TRANSFER') 'transfer_id': 'pair',
            },
        };
      });
      expect(state.monthIncome, 1000);
      expect(state.monthExpense, 200);
      final before = repo.store.read();
      expect(
        () => state.addTransaction(
          type: TransactionType.transfer,
          amount: 500,
          accountId: 'cash',
          toAccountId: 'other',
          categoryName: 'Transfer Antar Akun',
          date: DateTime.now(),
        ),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'message',
            contains('dua akun berbeda'),
          ),
        ),
      );
      expect(state.monthIncome, 1000);
      expect(state.monthExpense, 200);
      expect(repo.state, before);
      expect(repo.store.read(), before);
      expect(repo.outbox, isEmpty);
    });

    test('Categories are scoped to account owner and transaction type', () {
      final repo = state.repository!;
      repo.atomic(() {
        (repo.entities['accounts'] as Map)['other'] = {
          'id': 'other',
          'name': 'Other owner',
          'user_id': 'other-user',
          'balance': '0.00',
        };
        (repo.entities['categories'] as Map)['other-food'] = {
          'id': 'other-food',
          'user_id': 'other-user',
          'name': 'Groceries',
          'type': 'EXPENSE',
        };
      });
      expect(state.getCategoriesForAccount('cash', isIncome: false), ['Food']);
      expect(state.getCategoriesForAccount('cash', isIncome: true), ['Salary']);
      expect(state.getCategoriesForAccount('other', isIncome: false), [
        'Groceries',
      ]);
      expect(state.getCategoriesForAccount('other', isIncome: true), isEmpty);
      expect(
        state.getCategoriesForAccount('missing', isIncome: false),
        isEmpty,
      );
    });

    test(
      'Unavailable investment trades never fabricate holdings or debit cash',
      () {
        final repo = state.repository!;
        final before = repo.store.read();
        expect(state.investments, isEmpty);
        for (final type in InvestmentTradeType.values) {
          expect(
            () => state.recordInvestmentTrade(
              accountId: 'missing',
              instrumentId: 'missing',
              tradeType: type,
              quantity: '0.005',
              pricePerUnit: '1000000000',
              fee: '10000',
              cashAccountId: 'cash',
            ),
            throwsA(
              isA<ApiFailure>().having(
                (e) => e.message,
                'message',
                contains('akun IDR'),
              ),
            ),
          );
        }
        expect(state.getAccountById('cash')!.balance, 100000);
        expect(state.investments, isEmpty);
        expect(repo.outbox, isEmpty);
        expect(repo.state, before);
        expect(repo.store.read(), before);
      },
    );

    test(
      'Use Mine retries the existing conflict with the server version durably',
      () {
        final repo = state.repository!;
        repo.mutate('categories', 'UPDATE', {'name': 'Local food'}, id: 'food');
        final id = repo.outbox.single['id'] as String;
        repo.atomic(() {
          repo.outbox.single['status'] = 'conflict';
          repo.outbox.single['error'] = 'Version conflict';
          repo.outbox.single['server_data'] = {
            'id': 'food',
            'name': 'Server food',
            'user_id': 'user',
            'type': 'EXPENSE',
            'version': '4',
          };
        });
        expect(state.conflictCount, 1);
        state.resolveConflictUseMine(id);
        expect(state.conflictCount, 0);
        expect(repo.outbox, hasLength(1));
        expect(repo.outbox.single['id'], id);
        expect(repo.outbox.single['status'], 'pending');
        expect(repo.outbox.single['client_version'], '4');
        expect(repo.outbox.single['payload'], {'name': 'Local food'});
        expect(repo.outbox.single.containsKey('error'), isFalse);
        expect(repo.row('categories', 'food')!['name'], 'Local food');
        expect(repo.store.read(), repo.state);
      },
    );
  });
}
