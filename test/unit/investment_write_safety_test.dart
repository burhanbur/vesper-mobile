import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/network/api_client.dart';

import '../fixtures/cached_finance.dart';

void main() {
  test(
    'settlement cash rows cannot be edited or deleted without a trade relation',
    () {
      final state = cachedFinanceState();
      addTearDown(state.dispose);
      final repo = state.repository!;
      for (final type in ['EXPENSE', 'INCOME']) {
        repo.atomic(() {
          repo.entities['transactions'] = <String, dynamic>{
            'settlement': {
              'id': 'settlement',
              'account_id': 'cash',
              'category_id': null,
              'transfer_id': null,
              'type': type,
              'amount': '21.00',
              'version': '1',
            },
          };
        });
        final before = repo.store.read();
        for (final offline in [false, true]) {
          repo.offline = offline;
          for (final operation in ['UPDATE', 'DELETE', 'CREATE']) {
            expect(
              () => repo.mutate(
                'transactions',
                operation,
                operation == 'DELETE'
                    ? null
                    : {'category_id': 'food', 'amount': '1.00'},
                id: 'settlement',
                balanceDelta: {'cash': 20},
              ),
              throwsA(isA<ApiFailure>()),
            );
            expect(repo.store.read(), before);
            expect(repo.outbox, isEmpty);
          }
        }
      }
    },
  );

  test('ordinary categorized transactions remain editable', () {
    final state = cachedFinanceState();
    addTearDown(state.dispose);
    final repo = state.repository!;
    repo.atomic(() {
      repo.entities['transactions'] = <String, dynamic>{
        'ordinary': {'id': 'ordinary', 'category_id': 'food', 'version': '1'},
      };
    });
    repo.mutate('transactions', 'UPDATE', {
      'description': 'Updated',
    }, id: 'ordinary');
    expect(repo.row('transactions', 'ordinary')!['description'], 'Updated');
    expect(repo.outbox, hasLength(1));
  });

  test(
    'investment writes cannot bypass missing sync via generic repository',
    () async {
      final state = cachedFinanceState();
      addTearDown(state.dispose);
      final repo = state.repository!;
      final before = repo.store.read();
      expect(repo.supportsInvestmentTradeCommands, isTrue);
      expect(
        () =>
            repo.mutate('investment_transactions', 'CREATE', {'quantity': '1'}),
        throwsA(isA<ApiFailure>()),
      );
      for (final type in ['INVESTMENT_BUY', 'INVESTMENT_SELL']) {
        expect(
          () => repo.mutate('transactions', 'CREATE', {'type': type}),
          throwsA(isA<ApiFailure>()),
        );
      }
      for (final offline in [false, true]) {
        repo.offline = offline;
        await expectLater(
          repo.writeOnline('POST', '/investment-transactions', {}),
          throwsA(isA<ApiFailure>()),
        );
      }
      expect(repo.store.read(), before);
      expect(repo.outbox, isEmpty);
    },
  );
}
