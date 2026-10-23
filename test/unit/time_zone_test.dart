import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/utils/app_time_zone.dart';
import 'package:vesper_mobile/core/utils/date_formatter.dart';
import 'package:vesper_mobile/core/utils/transaction_period.dart';
import 'package:vesper_mobile/features/dashboard/data/dashboard_insights_repository.dart';
import 'package:vesper_mobile/features/settings/data/time_zone_preferences_repository.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import '../fixtures/dashboard_insights.dart';

void main() {
  test('calendar conversion crosses year/month boundaries without changing instant', () {
    final instant = DateTime.utc(2026, 12, 31, 16, 30);
    expect(AppTimeZone.wib.at(instant).day, 31);
    expect(AppTimeZone.wit.at(instant).year, 2027);
    for (final zone in AppTimeZone.values) {
      expect(zone.fromCalendar(zone.at(instant)), instant);
    }
    expect(AppTimeZone.device.at(instant), instant.toLocal());
    expect(
      DateFormatter.formatFull(instant, timeZone: AppTimeZone.wit),
      '1 Jan 2027, 01:30 WIT',
    );
  });

  test('month filters have exclusive UTC boundaries and retain calendar month when shifted', () {
    final period = TransactionPeriod(
      DateTime.utc(2026, 10),
      timeZone: AppTimeZone.wib,
    );
    expect(period.start, DateTime.utc(2026, 9, 30, 17));
    expect(period.end, DateTime.utc(2026, 10, 31, 17));
    expect(period.contains(period.start), isTrue);
    expect(
      period.contains(period.start.subtract(const Duration(microseconds: 1))),
      isFalse,
    );
    expect(period.contains(period.end), isFalse);
    expect(period.shift(-1).month, DateTime.utc(2026, 9));
    expect(
      period.withTimeZone(AppTimeZone.wit).start,
      DateTime.utc(2026, 9, 30, 15),
    );
    expect(period.shift(-1).shift(1).start, period.start);
  });

  test('relative dates compare calendar days in selected zone', () {
    final now = DateTime.utc(2026, 10, 1, 16, 30);
    final transaction = DateTime.utc(2026, 10, 1, 14);
    expect(
      DateFormatter.formatRelativeOrDate(
        transaction,
        now: now,
        timeZone: AppTimeZone.wib,
      ),
      'Hari ini',
    );
    expect(
      DateFormatter.formatRelativeOrDate(
        transaction,
        now: now,
        timeZone: AppTimeZone.wit,
      ),
      'Kemarin',
    );
  });

  for (final indexed in [false, true]) {
    test(
      'preference persists per owner without financial mutations ($indexed)',
      () {
        final source = insightRepository(indexed: indexed);
        addTearDown(source.store.close);
        final before = jsonEncode(source.entities),
            outbox = jsonEncode(source.outbox);
        final preference = TimeZonePreferencesRepository(source);
        expect(preference.selected, AppTimeZone.device);
        preference.save(AppTimeZone.wita);
        final reopened = FinanceRepository(source.client, source.store, 'user');
        expect(
          TimeZonePreferencesRepository(reopened).selected,
          AppTimeZone.wita,
        );
        expect(
          TimeZonePreferencesRepository(
            FinanceRepository(source.client, source.store, 'other'),
          ).selected,
          AppTimeZone.device,
        );
        expect(jsonEncode(source.entities), before);
        expect(jsonEncode(source.outbox), outbox);
        source.atomic(
          () => source.state['display_time_zone']['selection'] = 'unknown',
        );
        expect(preference.selected, AppTimeZone.device);
      },
    );

    test(
      'dashboard comparison follows zone; budget and bill periods stay unchanged ($indexed)',
      () {
        final source = insightRepository(indexed: indexed);
        addTearDown(source.store.close);
        source.atomic(() {
          source.entities['transactions'] = <String, dynamic>{
            'boundary': insightExpense(
              'boundary',
              '2026-09-30T15:30:00Z',
              '850000.00',
            ),
          };
          source.entities['bill_schedules'] = <String, dynamic>{
            insightBillId: insightBill('2026-10-01'),
          };
        });
        final repository = DashboardInsightsRepository(source);
        final now = DateTime.utc(2026, 9, 30, 16, 30);
        final wib = repository.read(now: now, timeZone: AppTimeZone.wib);
        final wit = repository.read(now: now, timeZone: AppTimeZone.wit);
        expect(wib.spending!.currentStart.month, 9);
        expect(wit.spending!.currentStart.month, 10);
        expect(wit.spending!.current, BigInt.from(85000000));
        expect(wib.budgets!.single.spent, wit.budgets!.single.spent);
        expect(wib.bills!.total, wit.bills!.total);
        expect(wib.bills!.count, wit.bills!.count);
      },
    );

    test('monthly totals match selected-zone query boundaries ($indexed)', () {
      final source = insightRepository(indexed: indexed);
      addTearDown(source.store.close);
      final state = AppState(repository: source)..currentUserId = 'user';
      addTearDown(state.dispose);
      final now = DateTime.now();
      final month = AppTimeZone.wib.at(now);
      final date = AppTimeZone.wib
          .fromCalendar(DateTime.utc(month.year, month.month))
          .subtract(const Duration(hours: 1));
      source.atomic(() {
        source.entities['transactions'] = <String, dynamic>{
          'boundary': insightExpense(
            'boundary',
            date.toIso8601String(),
            '100.00',
          ),
        };
      });
      for (final zone in [AppTimeZone.wib, AppTimeZone.wit]) {
        state.setTimeZone(zone);
        final period = TransactionPeriod(zone.at(now), timeZone: zone);
        expect(state.monthExpense, period.contains(date) ? 100 : 0);
      }
    });
  }
}
