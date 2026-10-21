import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/bills/data/bills_repository.dart';
import 'package:vesper_mobile/features/cash_flow/data/cash_flow_repository.dart';
import 'package:vesper_mobile/features/cash_flow/data/cash_flow_controller.dart';
import 'package:vesper_mobile/features/goals/data/goals_repository.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import 'bills_test.dart' show seedBills, billFixture, billId, cashId;

const forecastOtherCash = '44444444-4444-4444-8444-444444444444';
const forecastOtherBill = '55555555-5555-4555-8555-555555555555';
void forecastPut(
  FinanceRepository s,
  String entity,
  String id,
  Map<String, dynamic> row,
) => s.atomic(() {
  s.entities.putIfAbsent(entity, () => <String, dynamic>{});
  s.entities[entity][id] = <String, dynamic>{...row, 'id': id};
});
void seedForecast(FinanceRepository s) {
  seedBills(s);
  s.atomic(() {
    s.entities['bill_schedules'] = <String, dynamic>{};
    s.entities['transactions'] = <String, dynamic>{};
    s.state['goal_history_coverage'] = {
      'schema': 1,
      'user_id': 'owner',
      'complete': true,
      'cursor': s.state['cursor'],
    };
    s.state['transaction_snapshot_coverage'] = {
      'schema': 1,
      'user_id': 'owner',
      'complete': true,
    };
  });
}

void forecastBill(
  FinanceRepository s, {
  String id = billId,
  String date = '2026-10-21',
  String amount = '100.00',
  String account = cashId,
  String type = 'EXPENSE',
  String amountType = 'FIXED',
  int offset = 420,
}) {
  forecastPut(s, 'bill_schedules', id, {
    ...billFixture(),
    'id': id,
    'frequency': 'ONCE',
    'anchor_date': date,
    'amount': amount,
    'account_id': account,
    'transaction_type': type,
    'amount_type': amountType,
    'utc_offset_minutes': offset,
  });
}

void forecastLoan(
  FinanceRepository s, {
  String outstanding = '300.00',
  String kind = 'PAYABLE',
  bool linked = true,
}) {
  const installments = [
    {'due_date': '2026-10-21', 'principal': '100.00'},
    {'due_date': '2026-10-22', 'principal': '100.00'},
    {'due_date': '2026-10-23', 'principal': '100.00'},
  ];
  forecastPut(s, 'obligations', 'debt', {
    'user_id': 'owner',
    'kind': kind,
    'counterparty': 'Loan',
    'principal': '300.00',
    'outstanding': outstanding,
    'installments': installments,
  });
  if (linked) {
    forecastPut(s, 'bill_schedules', billId, {
      ...billFixture(),
      'frequency': 'INSTALLMENTS',
      'anchor_date': '2026-10-21',
      'category_id': null,
      'obligation_id': 'debt',
      'transaction_type': kind == 'PAYABLE' ? 'EXPENSE' : 'INCOME',
      'installments': installments,
    });
  }
}

void forecastRepayment(FinanceRepository s, {String amount = '100.00'}) =>
    forecastPut(s, 'obligation_events', 'repay', {
      'user_id': 'owner',
      'obligation_id': 'debt',
      'operation': 'REPAY',
      'principal': amount,
      'cash_account_id': cashId,
      'transacted_at': '2026-10-20T00:00:00.000Z',
    });

void main() {
  for (final indexed in [false, true]) {
    group(indexed ? 'indexed forecast' : 'snapshot forecast', () {
      late LocalStore store;
      late FinanceRepository s;
      late CashFlowRepository repo;
      Directory? temporary;
      setUp(() {
        if (indexed) {
          temporary = Directory.systemTemp.createTempSync(
            'vesper-cash-flow-test-',
          );
        }
        store = indexed
            ? LocalStore.indexed(
                sqlite3.open('${temporary!.path}/data.sqlite'),
                key: List.generate(32, (i) => i),
                userId: 'owner',
              )
            : LocalStore(sqlite3.openInMemory());
        s = FinanceRepository(ApiClient(), store, 'owner')..offline = true;
        seedForecast(s);
        repo = CashFlowRepository(s);
      });
      tearDown(() {
        store.close();
        final d = temporary?.absolute;
        if (d != null) {
          if (d.parent.path != Directory.systemTemp.absolute.path ||
              !d.path.contains('vesper-cash-flow-test-')) {
            throw StateError('Unsafe test cleanup');
          }
          d.deleteSync(recursive: true);
          temporary = null;
        }
      });
      CashFlowForecast forecast() =>
          repo.forecast(now: DateTime.utc(2026, 10, 21, 12));
      void config(Map<String, dynamic> values) =>
          repo.saveAssumptions({...repo.assumptions, ...values});

      test('90-day horizon is inclusive today/exclusive day 90 and never changes financial state', () {
        config({'days': 90});
        forecastBill(
          s,
          date: goalDay(
            DateTime.utc(2026, 10, 21).add(const Duration(days: 89)),
          ),
        );
        forecastBill(
          s,
          id: forecastOtherBill,
          date: goalDay(
            DateTime.utc(2026, 10, 21).add(const Duration(days: 90)),
          ),
        );
        final before = jsonEncode(s.state), r = forecast();
        expect(r.days, hasLength(90));
        expect(r.entries, hasLength(1));
        expect(r.actual, goalMinor('1000'));
        expect(r.closing, goalMinor('900'));
        expect(jsonEncode(s.state), before);
        expect(s.outbox, isEmpty);
      });
      test('paid and skipped occurrences are excluded instead of subtracting from cash again', () {
        forecastBill(s);
        forecastBill(s, id: forecastOtherBill);
        forecastPut(s, 'transactions', 'paid', {
          'account_id': cashId,
          'category_id': billFixture()['category_id'],
          'type': 'EXPENSE',
          'amount': '100.00',
        });
        forecastPut(
          s,
          'bill_occurrences',
          billOccurrenceId(billId, '2026-10-21'),
          {
            'user_id': 'owner',
            'bill_id': billId,
            'due_date': '2026-10-21',
            'status': 'PAID',
            'amount': '100.00',
            'transaction_id': 'paid',
          },
        );
        forecastPut(
          s,
          'bill_occurrences',
          billOccurrenceId(forecastOtherBill, '2026-10-21'),
          {
            'user_id': 'owner',
            'bill_id': forecastOtherBill,
            'due_date': '2026-10-21',
            'status': 'SKIPPED',
            'amount': '0.00',
          },
        );
        final r = forecast();
        expect(r.entries, isEmpty);
        expect(r.paidExcluded, 1);
        expect(r.skippedExcluded, 1);
        expect(r.closing, goalMinor('1000'));
      });
      test('overdue and estimated events are explicit assumptions and configurable', () {
        forecastBill(
          s,
          date: '2025-01-01',
          amount: '1200.01',
          amountType: 'ESTIMATED',
        );
        final r = forecast();
        expect(r.entries.single.overdue, isTrue);
        expect(r.entries.single.assumption, isTrue);
        expect(r.entries.single.date, '2026-10-21');
        expect(r.firstShortfall?.low, BigInt.from(-20001));
        config({'include_estimates': false});
        expect(forecast().entries, isEmpty);
        config({'include_estimates': true, 'include_overdue': false});
        expect(forecast().entries, isEmpty);
      });
      test('same-day inflows do not hide account shortfalls or imply automatic transfers', () {
        forecastPut(s, 'accounts', forecastOtherCash, {
          ...s.row('accounts', cashId)!,
          'name': 'Other',
          'balance': '10000.00',
        });
        forecastBill(s, amount: '1200.00');
        forecastBill(
          s,
          id: forecastOtherBill,
          type: 'INCOME',
          amount: '500.00',
        );
        final r = forecast();
        expect(r.firstShortfall, isNull);
        final account = r.accounts.firstWhere((a) => a.id == cashId);
        expect(account.firstShortfall?.low, BigInt.from(-20000));
        expect(account.days.first.closing, goalMinor('300'));
        expect(r.days.first.inflow, goalMinor('500'));
      });
      test('backed goal reserves are deducted once and negative balances are preserved', () {
        forecastPut(s, 'accounts', forecastOtherCash, {
          ...s.row('accounts', cashId)!,
          'name': 'Overdraft',
          'balance': '-50.25',
        });
        forecastPut(s, 'goal_allocations', 'reserve', {
          'user_id': 'owner',
          'account_id': cashId,
          'goal_id': 'goal',
          'amount': '2000.00',
          'created_at': '2026-10-01',
        });
        final r = forecast();
        expect(r.actual, BigInt.from(94975));
        expect(r.reserved, goalMinor('1000'));
        expect(r.available, BigInt.from(-5025));
        expect(r.firstShortfall, isNotNull);
        config({'reserve_goals': false});
        expect(forecast().available, BigInt.from(94975));
      });
      test('explicit later installment payments are allocated first, without FIFO/bill duplicate charges', () {
        forecastLoan(s, outstanding: '200.00');
        forecastRepayment(s);
        forecastPut(
          s,
          'bill_occurrences',
          billOccurrenceId(billId, '2026-10-23'),
          {
            'user_id': 'owner',
            'bill_id': billId,
            'due_date': '2026-10-23',
            'status': 'PAID',
            'amount': '100.00',
            'obligation_event_id': 'repay',
          },
        );
        forecastPut(s, 'bill_schedules', forecastOtherBill, {
          ...s.row('bill_schedules', billId)!,
          'title': 'Duplicate reminder',
        });
        final r = forecast();
        expect(r.entries, hasLength(2));
        expect(r.entries.map((e) => e.date), ['2026-10-21', '2026-10-22']);
        expect(r.closing, goalMinor('800'));
        expect(s.row('obligations', 'debt')!['outstanding'], '200.00');
      });
      test('unallocated partial repayments use oldest-first and missing fallback accounts are not guessed', () {
        forecastLoan(s, outstanding: '250.00', linked: false);
        forecastRepayment(s, amount: '50.00');
        expect(forecast, throwsA(isA<ApiFailure>()));
        config({
          'debt_accounts': {'debt': cashId},
        });
        final r = forecast();
        expect(r.entries.first.amount, goalMinor('50'));
        expect(r.entries.first.assumption, isTrue);
        expect(r.closing, goalMinor('750'));
      });
      test('review evidence and contradictory duplicate loan accounts stop ambiguous forecasts', () {
        forecastBill(s);
        forecastPut(
          s,
          'bill_occurrences',
          billOccurrenceId(billId, '2026-10-21'),
          {
            'user_id': 'owner',
            'bill_id': billId,
            'due_date': '2026-10-21',
            'status': 'PAID',
            'amount': '100.00',
            'transaction_id': 'missing',
          },
        );
        expect(forecast, throwsA(isA<ApiFailure>()));
        s.atomic(() {
          s.entities['bill_occurrences'] = <String, dynamic>{};
        });
        forecastLoan(s);
        forecastPut(s, 'accounts', forecastOtherCash, {
          ...s.row('accounts', cashId)!,
          'name': 'Other',
        });
        forecastPut(s, 'bill_schedules', forecastOtherBill, {
          ...s.row('bill_schedules', billId)!,
          'account_id': forecastOtherCash,
        });
        expect(forecast, throwsA(isA<ApiFailure>()));
      });
      test(
        'skipped loan reminders do not forgive debt; receivables are opt-in',
        () {
          forecastLoan(s);
          forecastPut(
            s,
            'bill_occurrences',
            billOccurrenceId(billId, '2026-10-21'),
            {
              'user_id': 'owner',
              'bill_id': billId,
              'due_date': '2026-10-21',
              'status': 'SKIPPED',
              'amount': '0.00',
            },
          );
          final r = forecast();
          expect(r.closing, goalMinor('800'));
          expect(r.warnings.join(' '), contains('pokok utang tetap ada'));
          forecastLoan(s, kind: 'RECEIVABLE');
          expect(forecast().entries, isEmpty);
          config({'include_receivables': true});
          expect(forecast().closing, goalMinor('1200'));
        },
      );
      test(
        'fixed-zone day mapping and month-end anchors remain deterministic',
        () {
          forecastBill(s, date: '2026-10-22', offset: 540);
          expect(forecast().entries.single.date, '2026-10-21');
          forecastPut(s, 'bill_schedules', billId, {
            ...s.row('bill_schedules', billId)!,
            'frequency': 'MONTHLY',
            'anchor_date': '2026-01-31',
            'utc_offset_minutes': 420,
          });
          final r = repo.forecast(now: DateTime.utc(2026, 1, 31, 12));
          expect(r.entries.map((e) => e.dueDate), ['2026-01-31', '2026-02-28']);
          expect(
            () => repo.bills.occurrences(horizonDays: 367),
            throwsA(isA<ApiFailure>()),
          );
        },
      );
      test('incomplete owner snapshots withhold results; durable assumptions do not sync or leak owners', () {
        config({'days': 7});
        final loaded = CashFlowRepository(
          FinanceRepository(ApiClient(), store, 'owner')..offline = true,
        );
        expect(loaded.assumptions['days'], 7);
        expect(s.outbox, isEmpty);
        s.atomic(() {
          s.state['bill_history_coverage']['user_id'] = 'other';
        });
        expect(forecast, throwsA(isA<ApiFailure>()));
        final controller = CashFlowController(repo, () => false);
        expect(controller.save({...repo.assumptions, 'days': 90}), isFalse);
        expect(controller.error, contains('Sesi telah berubah'));
      });
      test('due-date balloons, undated debts and explicitly outside-scope payment accounts are distinct', () {
        forecastLoan(s, outstanding: '250.00', linked: false);
        forecastPut(s, 'obligations', 'debt', {
          ...s.row('obligations', 'debt')!,
          'installments': <Map<String, dynamic>>[],
          'due_date': '2026-10-25',
        });
        config({
          'debt_accounts': {'debt': cashId},
        });
        expect(forecast().entries.single.amount, goalMinor('250'));
        expect(forecast().entries.single.source, 'Pokok jatuh tempo');
        forecastPut(s, 'obligations', 'debt', {
          ...s.row('obligations', 'debt')!,
          'due_date': null,
        });
        expect(forecast().entries, isEmpty);
        expect(forecast().warnings.join(' '), contains('belum punya tanggal'));
        forecastPut(s, 'accounts', forecastOtherCash, {
          ...s.row('accounts', cashId)!,
          'name': 'Other',
        });
        forecastPut(s, 'obligations', 'debt', {
          ...s.row('obligations', 'debt')!,
          'due_date': '2026-10-25',
        });
        config({
          'account_ids': [cashId],
          'debt_accounts': {'debt': forecastOtherCash},
        });
        expect(forecast().entries, isEmpty);
      });

      test('failed persistence rolls back and invalid scopes/denominators never silently substitute accounts', () {
        final before = jsonEncode(s.state);
        store.database.execute('PRAGMA query_only = ON');
        expect(() => config({'days': 7}), throwsA(anything));
        store.database.execute('PRAGMA query_only = OFF');
        expect(jsonEncode(s.state), before);
        expect(
          () => config({'account_ids': <String>[]}),
          throwsA(isA<ApiFailure>()),
        );
        expect(
          () => config({
            'account_ids': ['foreign'],
          }),
          throwsA(isA<ApiFailure>()),
        );
        expect(() => config({'days': 365}), throwsA(isA<ApiFailure>()));
      });
    });
  }
}
