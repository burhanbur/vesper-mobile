import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';
import 'package:vesper_mobile/core/utils/currency_formatter.dart';
import 'package:vesper_mobile/core/utils/app_time_zone.dart';
import 'package:vesper_mobile/features/bills/data/bills_repository.dart';
import 'package:vesper_mobile/features/dashboard/data/dashboard_insights_repository.dart';

import '../fixtures/dashboard_insights.dart';

class _MidSyncBillClient extends ApiClient {
  late FinanceRepository source;
  final cursors = <String>[];
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    if (path == '/devices') return {};
    if (path == '/sync/pull') {
      cursors.add(query!['since_version'] as String);
      if (cursors.length == 1) BillsRepository(source);
      return {
        'changes': [],
        'has_more': false,
        'next_version': query['since_version'] == '0' ? '1' : '2',
      };
    }
    throw StateError('Unexpected request: $path');
  }
}

void main() {
  test('bill activation during sync still requires a full replay before coverage is complete', () async {
    final client = _MidSyncBillClient();
    final source = FinanceRepository(
      client,
      LocalStore(sqlite3.openInMemory()),
      'user',
    );
    client.source = source;
    addTearDown(source.store.close);
    await source.sync();
    expect(source.state['bill_history_coverage']['complete'], isFalse);
    await source.sync();
    expect(client.cursors, ['0', '0']);
    expect(source.state['bill_history_coverage']['complete'], isTrue);
    await source.sync();
    expect(client.cursors, ['0', '0', '1']);
  });
  for (final indexed in [false, true]) {
    group(indexed ? 'Indexed insights' : 'Snapshot insights', () {
      test('same-date comparison pages all rows, excludes transfers and other currencies/owners', () {
        final source = insightRepository(indexed: indexed);
        addTearDown(source.store.close);
        source.atomic(() {
          source.entities['transactions'] = <String, dynamic>{
            for (var i = 0; i < 125; i++)
              'tx-$i': insightExpense('tx-$i', '2026-10-05T00:00:00Z', '1.01'),
            'previous': insightExpense(
              'previous',
              '2026-09-05T00:00:00Z',
              '100.00',
            ),
            'late': insightExpense('late', '2026-09-24T00:00:00Z', '999.00'),
            'transfer': insightExpense(
              'transfer',
              '2026-10-05T00:00:00Z',
              '999.00',
              type: 'TRANSFER',
            ),
            'buy': insightExpense(
              'buy',
              '2026-10-05T00:00:00Z',
              '999.00',
              type: 'INVESTMENT_BUY',
            ),
            'legacy-buy': insightExpense(
              'legacy-buy',
              '2026-10-05T00:00:00Z',
              '999.00',
            ),
            'foreign': insightExpense(
              'foreign',
              '2026-10-05T00:00:00Z',
              '999.00',
              account: 'foreign',
            ),
            'usd': insightExpense(
              'usd',
              '2026-10-05T00:00:00Z',
              '999.00',
              account: 'usd',
            ),
            'deleted': {
              ...insightExpense('deleted', '2026-10-05T00:00:00Z', '999.00'),
              'deleted_at': '2026-10-06',
            },
            'future': insightExpense(
              'future',
              '2026-10-24T00:00:00Z',
              '999.00',
            ),
          };
          source.entities['investment_transactions'] = <String, dynamic>{
            'legacy-trade': {
              'id': 'legacy-trade',
              'linked_transaction_id': 'legacy-buy',
              'type': 'BUY',
            },
          };
        });
        final before = jsonEncode(source.state);
        final result = DashboardInsightsRepository(source)
            .read(now: DateTime.utc(2026, 10, 23, 12));
        expect(result.spending!.current, BigInt.from(12625));
        expect(result.spending!.previous, BigInt.from(10000));
        expect(result.spending!.changePercent, BigInt.from(2625));
        expect(
          jsonEncode(source.state),
          before,
          reason: 'Insights never mutate local financial state.',
        );
      });

      test(
        '31st compares equal completed days against shorter previous month',
        () {
          final source = insightRepository(indexed: indexed);
          addTearDown(source.store.close);
          source.atomic(() {
            source.entities['transactions'] = <String, dynamic>{
              'current': insightExpense(
                'current',
                '2026-03-28T12:00:00Z',
                '280.00',
              ),
              'excluded': insightExpense(
                'excluded',
                '2026-03-29T00:00:00Z',
                '999.00',
              ),
              'previous': insightExpense(
                'previous',
                '2026-02-28T12:00:00Z',
                '280.00',
              ),
            };
          });
          final result = DashboardInsightsRepository(
            source,
          ).read(now: DateTime.utc(2026, 3, 31, 12), timeZone: AppTimeZone.wib);
          expect(result.spending!.comparedDays, 28);
          expect(result.spending!.current, BigInt.from(28000));
          expect(result.spending!.changePercent, BigInt.zero);
        },
      );

      test(
        'missing/zero baseline is unavailable, not an invented percentage',
        () {
          final source = insightRepository(indexed: indexed);
          addTearDown(source.store.close);
          final repository = DashboardInsightsRepository(source);
          expect(
            repository
                .read(now: DateTime.utc(2026, 1, 2))
                .spending!
                .changePercent,
            isNull,
          );
          source.atomic(() {
            source.state['transaction_snapshot_coverage']['complete'] = false;
          });
          final result = repository.read();
          expect(result.spending, isNull);
          expect(result.budgets, isNull);
          expect(result.bills, isNull);
        },
      );

      test('active anchored budgets use exact 80% threshold and live offline spending', () {
        final source = insightRepository(indexed: indexed);
        addTearDown(source.store.close);
        source.atomic(() {
          source.entities['budgets']!['budget']['anchor_date'] = '2026-01-15';
          source.entities['budgets']!['budget']['current_amount'] = '100.01';
          source.entities['transactions'] = <String, dynamic>{
            'start': insightExpense('start', '2026-09-15T00:00:00Z', '79.99'),
            'outside': insightExpense(
              'outside',
              '2026-09-14T23:59:59Z',
              '999.00',
            ),
          };
          source.state['progress:budget:2026-09'] = {
            'allowance': '100.01',
            'total_amount': '0.00',
          };
        });
        final repository = DashboardInsightsRepository(source);
        expect(
          repository.read(now: DateTime.utc(2026, 10, 10)).budgets,
          isEmpty,
        );
        source.atomic(() {
          source.entities['transactions']!['extra'] = insightExpense(
            'extra',
            '2026-10-09T00:00:00Z',
            '0.02',
          );
          source.outbox.add({'id': 'offline-edit', 'status': 'pending'});
        });
        final result = repository.read(now: DateTime.utc(2026, 10, 10));
        expect(result.budgets!.single.spent, BigInt.from(8001));
        expect(result.budgets!.single.remaining, BigInt.from(2000));
        expect(result.provisional, isTrue);
      });

      test('bills include today through day six in bill timezone, excluding paid/skipped/income', () {
        final source = insightRepository(indexed: indexed);
        addTearDown(source.store.close);
        const estimatedId = '22222222-2222-4222-8222-222222222222';
        const outsideId = '33333333-3333-4333-8333-333333333333';
        source.atomic(() {
          source.entities['bill_schedules'] = <String, dynamic>{
            insightBillId: insightBill('2026-10-24'),
            estimatedId: {
              ...insightBill('2026-10-30', id: estimatedId),
              'amount_type': 'ESTIMATED',
            },
            outsideId: insightBill('2026-10-31', id: outsideId),
          };
        });
        final repository = DashboardInsightsRepository(source);
        final now = DateTime.utc(2026, 10, 23, 18); // Oct 24 in WIB.
        final bills = repository.read(now: now).bills!;
        expect(bills.count, 2);
        expect(bills.estimatedCount, 1);
        expect(bills.total, BigInt.from(70000100));
        source.atomic(() {
          final id = billOccurrenceId(insightBillId, '2026-10-24');
          source.entities['bill_occurrences'] = <String, dynamic>{
            id: {'id': id, 'status': 'SKIPPED'},
          };
          source.entities['bill_schedules']![estimatedId]['transaction_type'] =
              'INCOME';
        });
        expect(repository.read(now: now).bills!.count, 0);
        source.atomic(() {
          source.state['bill_history_coverage']['user_id'] = 'other';
        });
        expect(repository.read(now: now).bills, isNull);
      });

      test('broken paid evidence withholds total and duplicate debt schedules are not summed', () {
        final source = insightRepository(indexed: indexed);
        addTearDown(source.store.close);
        const duplicateId = '22222222-2222-4222-8222-222222222222';
        source.atomic(() {
          source.entities['obligations'] = <String, dynamic>{
            'debt': {'id': 'debt', 'user_id': 'user', 'kind': 'PAYABLE'},
          };
          source.entities['bill_schedules'] = <String, dynamic>{
            for (final id in [insightBillId, duplicateId])
              id: {
                ...insightBill('2026-10-24', id: id),
                'obligation_id': 'debt',
              },
          };
        });
        final repository = DashboardInsightsRepository(source);
        final now = DateTime.utc(2026, 10, 23);
        expect(repository.read(now: now).bills!.count, 1);
        source.atomic(() {
          final id = billOccurrenceId(insightBillId, '2026-10-24');
          source.entities['bill_occurrences'] = <String, dynamic>{
            id: {'id': id, 'status': 'PAID', 'transaction_id': 'missing'},
          };
        });
        expect(repository.read(now: now).bills!.needsReview, isTrue);
      });
    });
  }

  test('minor-unit currency formatting preserves cents and large integer precision', () {
    expect(
      CurrencyFormatter.formatMinorRupiah(BigInt.parse('900719925474099301')),
      'Rp 9.007.199.254.740.993,01',
    );
    expect(CurrencyFormatter.formatMinorRupiah(BigInt.from(-1)), '-Rp 0,01');
  });
}
