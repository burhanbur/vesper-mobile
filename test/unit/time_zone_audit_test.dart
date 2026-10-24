import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/core/utils/app_time_zone.dart';
import 'package:vesper_mobile/core/utils/date_formatter.dart';
import 'package:vesper_mobile/features/cash_flow/data/cash_flow_repository.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/emergency_funds/data/emergency_fund_repository.dart';
import 'package:vesper_mobile/features/goals/data/goals_repository.dart';
import 'package:vesper_mobile/features/reports/data/financial_export_repository.dart';
import 'package:vesper_mobile/features/settings/data/time_zone_preferences_repository.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import 'emergency_fund_test.dart' show seedEmergency, emergencyConfig;
import 'financial_export_test.dart' show seedExport;

void main() {
  test(
    'API instants and calendar dates cannot be confused in presentation',
    () {
      expect(
        DateFormatter.timestamp(
          '2026-12-31T18:15:00Z',
          timeZone: AppTimeZone.wit,
        ),
        '1 Jan 2027, 03:15 WIT',
      );
      expect(
        DateFormatter.timestamp(
          '2027-01-01T03:15:00+09:00',
          timeZone: AppTimeZone.wib,
        ),
        '1 Jan 2027, 01:15 WIB',
      );
      for (final invalid in [
        null,
        '',
        '2026-12-31',
        '2026-12-31T18:15:00',
        'brokenZ',
      ]) {
        expect(DateFormatter.timestamp(invalid), 'Belum tersedia');
      }
      expect(DateFormatter.calendarDate('2026-12-31'), '31 Des 2026');
      expect(DateFormatter.calendarDate('2026-02-30'), 'Belum tersedia');
      expect(
        DateFormatter.calendarDate('2026-12-31T18:15:00Z'),
        'Belum tersedia',
      );
      expect(DateFormatter.fixedZone(420), 'WIB');
      expect(DateFormatter.fixedZone(-330), 'GMT-05:30');
    },
  );

  for (final indexed in [false, true]) {
    group(indexed ? 'indexed timezone audit' : 'snapshot timezone audit', () {
      late FinanceRepository source;
      Directory? temporary;
      setUp(() {
        temporary = indexed
            ? Directory.systemTemp.createTempSync('vesper-zone-audit-')
            : null;
        final store = indexed
            ? LocalStore.indexed(
                sqlite3.open('${temporary!.path}/finance.sqlite'),
                key: List.generate(32, (i) => i),
                userId: 'owner',
              )
            : LocalStore(sqlite3.openInMemory());
        source = FinanceRepository(ApiClient(), store, 'owner')..offline = true;
      });
      tearDown(() {
        source.store.close();
        final dir = temporary;
        if (dir != null) {
          if (dir.absolute.parent.path != Directory.systemTemp.absolute.path ||
              !dir.path.contains('vesper-zone-audit-')) {
            throw StateError('Unsafe cleanup');
          }
          dir.deleteSync(recursive: true);
        }
      });

      for (final zone in AppTimeZone.values) {
        test(
          'export includes both selected calendar days exactly in ${zone.name}',
          () {
            seedExport(source);
            final date = DateTime.utc(2027, 1, 1);
            final start = zone.fromCalendar(date);
            final end = zone.fromCalendar(DateTime.utc(2027, 1, 2));
            final instants = [
              start.subtract(const Duration(microseconds: 1)),
              start,
              end.subtract(const Duration(microseconds: 1)),
              end,
            ];
            source.atomic(() {
              source.entities['transactions'] = <String, dynamic>{
                for (var i = 0; i < instants.length; i++)
                  '$i': <String, dynamic>{
                    'id': '$i',
                    'account_id': 'account',
                    'type': 'EXPENSE',
                    'amount': '10.00',
                    'category_id': 'expense',
                    'transacted_at': instants[i].toIso8601String(),
                    'version': '1',
                  },
              };
            });
            final export = FinancialExportRepository(source).exportCalendar(
              startDate: date,
              endDate: date,
              timeZone: zone,
              currency: 'IDR',
            );
            expect(export.count, 2);
            expect(export.debits, BigInt.from(2000));
            expect(export.csv, contains(start.toIso8601String()));
            expect(source.outbox, isEmpty);
          },
        );

        test(
          'emergency full months and evidence use ${zone.name} boundaries',
          () {
            seedEmergency(source);
            final start = zone.fromCalendar(DateTime.utc(2026, 10, 1));
            final end = zone.fromCalendar(DateTime.utc(2027, 1, 1));
            final instants = [
              start.subtract(const Duration(microseconds: 1)),
              start,
              zone.fromCalendar(DateTime.utc(2026, 11, 30, 23, 59)),
              end.subtract(const Duration(microseconds: 1)),
              end,
            ];
            source.atomic(() {
              source.entities['transactions'] = <String, dynamic>{
                for (var i = 0; i < instants.length; i++)
                  '$i': <String, dynamic>{
                    'id': '$i',
                    'account_id': 'cash',
                    'type': 'EXPENSE',
                    'amount': '100.00',
                    'category_id': 'food',
                    'transacted_at': instants[i].toIso8601String(),
                    'version': '1',
                  },
              };
            });
            final result = EmergencyFundRepository(source).assess(
              emergencyConfig(mode: 'HISTORY'),
              now: zone.fromCalendar(DateTime.utc(2027, 1, 15)),
              timeZone: zone,
            );
            expect(result.historyStart, start);
            expect(result.historyEnd, end);
            expect(result.baseline, BigInt.from(10000));
            expect(result.monthsWithExpenses, 3);
            expect(source.outbox, isEmpty);
          },
        );
      }

      test(
        'goal today and overdue follow owner preference across year boundary',
        () {
          seedEmergency(source);
          final goal = <String, dynamic>{
            'id': 'g',
            'currency': 'IDR',
            'target_amount': '3100.00',
            'start_date': '2026-12-01',
            'target_date': '2026-12-31',
          };
          final now = DateTime.utc(2026, 12, 31, 16, 30);
          final goals = GoalsRepository(source);
          TimeZonePreferencesRepository(source).save(AppTimeZone.wib);
          expect(goals.progress(goal, now: now).overdue, isFalse);
          TimeZonePreferencesRepository(source).save(AppTimeZone.wit);
          expect(goals.progress(goal, now: now).overdue, isTrue);
          expect(source.outbox, isEmpty);
        },
      );

      test('new forecast follows preference but existing planning zone is preserved', () {
        seedEmergency(source);
        TimeZonePreferencesRepository(source).save(AppTimeZone.wit);
        final repo = CashFlowRepository(source);
        expect(repo.assumptions['utc_offset_minutes'], 540);
        final saved = {...repo.assumptions, 'utc_offset_minutes': 420};
        source.atomic(() => source.state['cash_flow_assumptions'] = saved);
        expect(repo.assumptions['utc_offset_minutes'], 420);
        expect(source.outbox, isEmpty);
      });
    });
  }
}
