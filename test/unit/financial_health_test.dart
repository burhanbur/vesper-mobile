import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/financial_health/data/financial_health_repository.dart';
import 'package:vesper_mobile/features/goals/data/goals_repository.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import 'emergency_fund_test.dart' show seedEmergency, emergencyConfig;

void seedHealth(FinanceRepository source) {
  seedEmergency(source);
  source.atomic(() {
    for (final name in [
      'goal_history_coverage',
      'obligation_history_coverage',
      'investment_history_coverage',
      'emergency_plan_coverage',
    ]) {
      source.state[name] = {
        'schema': 1,
        'user_id': 'owner',
        'complete': true,
        'cursor': source.state['cursor'],
      };
    }
  });
}

void healthTransaction(
  FinanceRepository source,
  String id,
  String kind,
  String amount, {
  String date = '2026-08-15T00:00:00Z',
  String account = 'cash',
  bool deleted = false,
}) {
  source.atomic(() {
    source.entities.putIfAbsent('transactions', () => <String, dynamic>{});
    source.entities['transactions'][id] = <String, dynamic>{
      'id': id,
      'account_id': account,
      'type': kind,
      'category_id': 'food',
      'amount': amount,
      'transacted_at': date,
      'version': '1',
      'deleted_at': deleted ? date : null,
    };
  });
}

void healthRepayment(
  FinanceRepository source, {
  String kind = 'PAYABLE',
  bool reversed = false,
}) {
  source.atomic(() {
    source.entities['obligations'] = <String, dynamic>{
      'debt': <String, dynamic>{'id': 'debt', 'user_id': 'owner', 'kind': kind},
    };
    source.entities['obligation_events'] = <String, dynamic>{
      'repay': <String, dynamic>{
        'id': 'repay',
        'user_id': 'owner',
        'obligation_id': 'debt',
        'operation': 'REPAY',
        'cash_account_id': 'cash',
        'principal': '100.00',
        'interest': '10.00',
        'fee': '5.00',
        'cash_principal_id': 'principal',
        'interest_id': 'interest',
        'fee_id': 'fee',
        'transacted_at': '2026-08-15T00:00:00Z',
        'reversed_at': reversed ? '2026-09-01T00:00:00Z' : null,
      },
    };
  });
  healthTransaction(
    source,
    'principal',
    'TRANSFER',
    kind == 'PAYABLE' ? '-100.00' : '100.00',
    deleted: reversed,
  );
  healthTransaction(
    source,
    'interest',
    kind == 'PAYABLE' ? 'EXPENSE' : 'INCOME',
    '10.00',
    deleted: reversed,
  );
  healthTransaction(source, 'fee', 'EXPENSE', '5.00', deleted: reversed);
}

void main() {
  for (final indexed in [false, true]) {
    group(indexed ? 'indexed health' : 'snapshot health', () {
      late LocalStore store;
      late FinanceRepository source;
      late FinancialHealthRepository repo;
      Directory? temporary;
      setUp(() {
        if (indexed) {
          temporary = Directory.systemTemp.createTempSync(
            'vesper-health-test-',
          );
        }
        store = indexed
            ? LocalStore.indexed(
                sqlite3.open('${temporary!.path}/finance.sqlite'),
                key: List.generate(32, (i) => i),
                userId: 'owner',
              )
            : LocalStore(sqlite3.openInMemory());
        source = FinanceRepository(ApiClient(), store, 'owner')..offline = true;
        seedHealth(source);
        repo = FinancialHealthRepository(source);
      });
      tearDown(() {
        store.close();
        final directory = temporary?.absolute;
        if (directory != null) {
          if (directory.parent.path != Directory.systemTemp.absolute.path ||
              !directory.path.contains('vesper-health-test-')) {
            throw StateError('Unsafe test directory');
          }
          directory.deleteSync(recursive: true);
          temporary = null;
        }
      });
      HealthAssessment assess() => repo.assess(now: DateTime.utc(2026, 10, 21));

      test('actual debt costs count once, principal is not spending and reads do not mutate money', () {
        healthTransaction(source, 'salary', 'INCOME', '1000.00');
        healthTransaction(source, 'food', 'EXPENSE', '200.00');
        healthRepayment(source);
        final before = jsonEncode(source.state);
        final r = assess();
        expect(r.income, goalMinor('1000'));
        expect(r.expenses, goalMinor('215'));
        expect(r.debtService, goalMinor('115'));
        expect(r.savingPercent, BigInt.from(7850));
        expect(r.debtPercent, BigInt.from(1150));
        expect(r.liquidityMonths, BigInt.from(952));
        expect(jsonEncode(source.state), before);
        expect(source.outbox, isEmpty);
      });

      test('completed UTC months are half-open and all transaction pages are included', () {
        for (var i = 0; i < 205; i++) {
          healthTransaction(
            source,
            'salary$i',
            'INCOME',
            '1.01',
            date: '2026-07-01T07:00:00+07:00',
          );
        }
        healthTransaction(
          source,
          'before',
          'INCOME',
          '9999',
          date: '2026-07-01T00:00:00+07:00',
        );
        healthTransaction(
          source,
          'end',
          'EXPENSE',
          '9999',
          date: '2026-10-01T00:00:00Z',
        );
        healthTransaction(
          source,
          'last',
          'EXPENSE',
          '1',
          date: '2026-10-01T06:59:59+07:00',
        );
        final r = assess();
        expect(r.start, DateTime.utc(2026, 7));
        expect(r.end, DateTime.utc(2026, 10));
        expect(r.income, goalMinor('207.05'));
        expect(r.expenses, goalMinor('1'));
        expect(r.transactionCount, 206);
        expect(r.incomeMonths, 1);
      });

      test('transfers, investment cash and deleted rows are excluded; net dividends are configurable', () {
        healthTransaction(source, 'salary', 'INCOME', '100');
        healthTransaction(source, 'transfer', 'TRANSFER', '999');
        healthTransaction(source, 'deleted', 'INCOME', '999', deleted: true);
        healthTransaction(source, 'buy', 'EXPENSE', '500');
        healthTransaction(source, 'sell', 'INCOME', '600');
        healthTransaction(source, 'dividend', 'INCOME', '10.25');
        source.atomic(() {
          source.entities['investment_transactions'] = <String, dynamic>{
            for (final type in ['BUY', 'SELL', 'DIVIDEND'])
              type: <String, dynamic>{
                'id': type,
                'type': type,
                'linked_transaction_id': type == 'DIVIDEND'
                    ? 'dividend'
                    : type.toLowerCase(),
              },
          };
          // Scheduled bills are not actual ledger movements.
          source.entities['bill_schedules'] = <String, dynamic>{
            'unpaid': <String, dynamic>{'amount': '999999'},
          };
        });
        expect(assess().income, goalMinor('100'));
        expect(assess().expenses, BigInt.zero);
        repo.saveAssumptions(
          months: 3,
          includeDividends: true,
          accountIds: ['cash'],
        );
        expect(assess().income, goalMinor('110.25'));
        expect(source.outbox, isEmpty);
      });

      test('zero income, zero expenses and incomplete snapshots never give infinite or false-zero ratios', () {
        final empty = assess();
        expect(empty.savingPercent, isNull);
        expect(empty.debtPercent, isNull);
        expect(empty.liquidityMonths, isNull);
        healthTransaction(source, 'salary', 'INCOME', '100');
        source.atomic(() {
          source.state.remove('investment_history_coverage');
        });
        final incomplete = assess();
        expect(incomplete.income, isNull);
        expect(incomplete.debtService, isNull);
        expect(incomplete.savingPercent, isNull);
        expect(incomplete.warnings.join(' '), contains('snapshot'));
      });

      test('negative saving and high debt ratios retain exact signed values beyond floating-point precision', () {
        healthTransaction(source, 'salary', 'INCOME', '50');
        healthTransaction(source, 'expense', 'EXPENSE', '200');
        healthRepayment(source);
        final r = assess();
        expect(r.savingPercent, BigInt.from(-33000));
        expect(r.debtPercent, BigInt.from(23000));
        expect(healthDecimal(BigInt.from(-1)), '-0.01');
        expect(
          healthRatio(
            goalMinor('9007199254740993.01'),
            goalMinor('9007199254740993.00'),
          ),
          BigInt.from(10000),
        );
        expect(
          healthRatio(BigInt.from(-1), BigInt.from(3)),
          BigInt.from(-3333),
        );
      });

      test(
        'reversed and receivable repayments never inflate payable debt burden',
        () {
          healthTransaction(source, 'salary', 'INCOME', '1000');
          healthRepayment(source, reversed: true);
          expect(assess().debtService, BigInt.zero);
          expect(assess().expenses, BigInt.zero);
          healthRepayment(source, kind: 'RECEIVABLE');
          expect(assess().debtService, BigInt.zero);
          expect(assess().income, goalMinor('1010'));
          expect(assess().expenses, goalMinor('5'));
        },
      );

      test('missing repayment evidence and unknown settlement classification withhold affected flows', () {
        healthTransaction(source, 'salary', 'INCOME', '1000');
        healthRepayment(source);
        source.atomic(() {
          (source.entities['transactions'] as Map).remove('interest');
        });
        expect(assess().debtPercent, isNull);
        expect(assess().liquidityMonths, isNull);
        expect(assess().warnings.join(' '), contains('bukti pelunasan'));
        source.atomic(() {
          source.entities['obligation_events'] = <String, dynamic>{};
          source.entities['transactions']['principal'] = <String, dynamic>{
            ...source.row('transactions', 'principal')!,
            'is_obligation_settlement': true,
          };
        });
        expect(assess().debtPercent, isNull);
      });

      test('goal reserves reduce free cash once and emergency coverage reuses its own selected backing', () {
        healthTransaction(source, 'salary', 'INCOME', '1000');
        healthTransaction(source, 'food', 'EXPENSE', '300');
        source.atomic(() {
          source.entities['goals'] = <String, dynamic>{
            'emergency': <String, dynamic>{
              'id': 'emergency',
              'user_id': 'owner',
              'currency': 'IDR',
              'target_date': '2027-01-01',
            },
          };
          source.entities['goal_allocations'] = <String, dynamic>{
            'reserve': <String, dynamic>{
              'id': 'reserve',
              'user_id': 'owner',
              'goal_id': 'emergency',
              'account_id': 'cash',
              'amount': '400.00',
              'created_at': '2026-07-01T00:00:00Z',
            },
          };
          source.entities['emergency_plans'] = <String, dynamic>{
            'plan': <String, dynamic>{
              'id': 'plan',
              'user_id': 'owner',
              ...emergencyConfig(goal: 'emergency', baseline: '200.00'),
            },
          };
        });
        final r = assess();
        expect(r.freeCash, goalMinor('600'));
        expect(r.liquidityMonths, BigInt.from(600));
        expect(r.emergency?.liquid, goalMinor('1000'));
        expect(r.emergencyMonths, BigInt.from(500));
        expect(r.emergency?.baseline, goalMinor('200'));
      });

      test('foreign, parent, investment and non-IDR accounts cannot enter persisted assumptions', () {
        source.atomic(() {
          for (final id in ['foreign', 'parent', 'usd', 'mapped']) {
            source.entities['accounts'][id] = <String, dynamic>{
              ...source.row('accounts', 'cash')!,
              'id': id,
              'user_id': id == 'foreign' ? 'other' : 'owner',
              'currency': id == 'usd' ? 'USD' : 'IDR',
            };
          }
          source.entities['accounts']['cash'] = <String, dynamic>{
            ...source.row('accounts', 'cash')!,
            'parent_account_id': 'parent',
          };
          source.entities['obligations'] = <String, dynamic>{
            'mapped': <String, dynamic>{
              'id': 'mapped',
              'user_id': 'owner',
              'linked_account_id': 'mapped',
            },
          };
        });
        for (final id in ['foreign', 'parent', 'usd', 'mapped']) {
          expect(
            () => repo.saveAssumptions(
              months: 3,
              includeDividends: false,
              accountIds: [id],
            ),
            throwsA(isA<ApiFailure>()),
          );
        }
        repo.saveAssumptions(
          months: 6,
          includeDividends: true,
          accountIds: ['cash'],
        );
        final reloaded = FinanceRepository(ApiClient(), store, 'owner');
        expect(FinancialHealthRepository(reloaded).assumptions['months'], 6);
        expect(assess().months, 6);
        expect(source.outbox, isEmpty);
        source.atomic(() {
          source.entities['accounts']['cash']['deleted_at'] = '2026-10-21';
        });
        expect(assess().savingPercent, isNull);
      });

      test('failed assumption persistence rolls back and another owner never inherits settings', () {
        final before = jsonEncode(source.state);
        store.database.execute('PRAGMA query_only = ON');
        expect(
          () => repo.saveAssumptions(
            months: 12,
            includeDividends: true,
            accountIds: ['cash'],
          ),
          throwsA(anything),
        );
        store.database.execute('PRAGMA query_only = OFF');
        expect(jsonEncode(source.state), before);
        source.atomic(() {
          source.state['financial_health_assumptions'] = {
            'schema': 1,
            'user_id': 'other',
            'months': 12,
          };
        });
        expect(repo.assumptions['months'], 3);
      });
    });
  }
}
