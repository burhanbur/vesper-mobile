import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/accounts/models/credit_card_summary.dart';
import 'package:vesper_mobile/features/goals/data/goals_repository.dart';
import 'package:vesper_mobile/features/household/data/group_pocket_repository.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

class _AccountSnapshotClient extends ApiClient {
  @override
  Future<List<Map<String, dynamic>>> list(
    String path, {
    Map<String, dynamic>? query,
  }) async => [
    {
      'id': 'card',
      'user_id': 'user',
      'balance': '-2000000.25',
      'version': '9007199254740993125',
      'is_credit_card': true,
      'credit_limit': null,
    },
  ];
}

void main() {
  test('exact debt, contractual limit, credit and whole-IDR validation', () {
    final summary = CreditCardSummary('-1200000.00', '1000000.00');
    expect(accountDecimal(summary.remaining!), '-200000.00');
    expect(CreditCardSummary('500000.00', '1000000.00').remaining, accountMinor('1000000.00'));
    expect(CreditCardSummary('0.01', null).remaining, isNull);
    expect(accountDecimal(accountMinor('-999999999999999999.99')), '-999999999999999999.99');
    expect(creditLimitInput(''), isNull);
    expect(creditLimitInput('1000000'), '1000000.00');
    for (final value in ['0', '-1', '1.25', '1,25']) {
      expect(() => creditLimitInput(value), throwsFormatException);
    }
  });

  late LocalStore store;
  late FinanceRepository repo;
  setUp(() {
    store = LocalStore(sqlite3.openInMemory());
    repo = FinanceRepository(ApiClient(), store, 'user');
    repo.atomic(() {
      repo.entities['account_types'] = {'bank': {'id': 'bank', 'name': 'Bank', 'user_id': 'user', 'category': 'CASH'}};
      repo.entities['accounts'] = {
        'bank': {'id': 'bank', 'name': 'Bank', 'user_id': 'user', 'account_type_id': 'bank', 'currency': 'IDR', 'balance': '5000000.00', 'version': '9007199254740993123', 'is_credit_card': false, 'credit_limit': null},
        'card': {'id': 'card', 'name': 'Not a name heuristic', 'user_id': 'user', 'account_type_id': 'bank', 'currency': 'IDR', 'balance': '-2000000.00', 'version': '9007199254740993124', 'is_credit_card': true, 'credit_limit': '1000000.00'},
      };
    });
  });
  tearDown(() => store.close());

  test('ordinary repayment and expenses preserve overpayment across restart', () {
    repo.createTransfer(fromAccountId: 'bank', toAccountId: 'card', amount: 2500000, date: DateTime.utc(2026));
    expect(repo.outbox.length, 1);
    expect(repo.rows('transactions').length, 2);
    expect(repo.row('accounts', 'card')!['balance'], '500000.00');
    repo = FinanceRepository(ApiClient(), store, 'user');
    for (final amount in [200000, 400000]) {
      repo.mutate('transactions', 'CREATE', {'account_id': 'card', 'type': 'EXPENSE', 'amount': '$amount.00', 'category_id': 'food'}, balanceDelta: {'card': -amount});
    }
    expect(repo.row('accounts', 'card')!['balance'], '-100000.00');
    expect(repo.row('accounts', 'card')!['version'], '9007199254740993124');
    expect(repo.outbox.length, 3);
    expect(repo.rows('transactions').where((t) => t['type'] == 'EXPENSE').length, 2);
  });

  test('pending expense preserves authoritative fractional balance', () async {
    repo.mutate('transactions', 'CREATE', {
      'account_id': 'card', 'type': 'EXPENSE', 'amount': '1.00',
    }, balanceDelta: {'card': -1});
    repo = FinanceRepository(_AccountSnapshotClient(), store, 'user');
    await repo.refreshList('accounts', '/accounts');
    expect(repo.row('accounts', 'card')!['balance'], '-2000001.25');
    expect(repo.outbox, hasLength(1));
  });

  test('large local balances stay exact and fractional edits roll back', () {
    repo.atomic(() {
      repo.entities['accounts']['card']['balance'] = '-999999999999999999.00';
    });
    final id = repo.mutate('transactions', 'CREATE', {
      'account_id': 'card', 'type': 'EXPENSE', 'amount': '2.00',
    }, balanceDelta: {'card': -2});
    expect(repo.row('accounts', 'card')!['balance'], '-1000000000000000001.00');
    repo.mutate('transactions', 'DELETE', null, id: id, balanceDelta: {'card': 2});
    expect(repo.row('accounts', 'card')!['balance'], '-999999999999999999.00');
    repo.atomic(() => repo.entities['accounts']['card']['balance'] = '-0.25');
    expect(() => repo.mutate('transactions', 'CREATE', {
      'account_id': 'card', 'type': 'EXPENSE', 'amount': '1.00',
    }, balanceDelta: {'card': -1}), throwsA(isA<ApiFailure>()));
    expect(repo.row('accounts', 'card')!['balance'], '-0.25');
    expect(repo.outbox, isEmpty);
  });

  test('limit edits preserve balance and version; null means untracked', () {
    repo.mutate('accounts', 'UPDATE', {'credit_limit': '1.00'}, id: 'card');
    expect(repo.row('accounts', 'card')!['balance'], '-2000000.00');
    expect(repo.outbox.single['client_version'], '9007199254740993124');
  });

  test('card excluded from cash, pocket and trade funding; no outgoing transfer or income', () {
    expect(GoalsRepository(repo).cashAccounts.map((a) => a['id']), isNot(contains('card')));
    expect(pocketCandidates('user', repo.rows('accounts'), repo.rows('account_types')).map((a) => a.id), isNot(contains('card')));
    expect(repo.canTradeAccount('card', 'CASH'), isFalse);
    expect(() => repo.createTransfer(fromAccountId: 'card', toAccountId: 'bank', amount: 1, date: DateTime.utc(2026)), throwsA(isA<ApiFailure>()));
    expect(() => repo.mutate('transactions', 'CREATE', {'account_id': 'card', 'type': 'INCOME'}), throwsA(isA<ApiFailure>()));
    expect(repo.outbox, isEmpty);
  });

  test('creation zero-only, metadata durable, identity conversion refused', () {
    final id = repo.mutate('accounts', 'CREATE', {'name': 'New', 'account_type_id': 'bank', 'currency': 'IDR', 'is_credit_card': true, 'credit_limit': null}, local: {'balance': '0.00'});
    repo = FinanceRepository(ApiClient(), store, 'user');
    expect(repo.row('accounts', id)!['is_credit_card'], isTrue);
    expect(repo.row('accounts', id)!['credit_limit'], isNull);
    expect(() => repo.mutate('accounts', 'UPDATE', {'is_credit_card': true}, id: 'bank'), throwsA(isA<ApiFailure>()));
    expect(() => repo.mutate('accounts', 'CREATE', {'account_type_id': 'bank', 'is_credit_card': true}, local: {'balance': '-1.00'}), throwsA(isA<ApiFailure>()));
  });
}
