import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/utils/date_formatter.dart';
import 'package:vesper_mobile/core/utils/app_time_zone.dart';

void main() {
  test('Full UTC timestamp converts to WIB across date and year rollover', () {
    expect(
      DateFormatter.formatFull(
        DateTime.utc(2026, 12, 31, 18, 5),
        timeZone: AppTimeZone.wib,
      ),
      '1 Jan 2027, 01:05 WIB',
    );
  });
  test('Explicit timezone offsets identify the same WIB instant', () {
    expect(
      DateFormatter.formatFull(
        DateTime.parse('2026-10-14T12:30:00+09:00'),
        timeZone: AppTimeZone.wib,
      ),
      '14 Okt 2026, 10:30 WIB',
    );
    expect(
      DateFormatter.formatFull(
        DateTime.parse('2026-10-14T03:30:00Z'),
        timeZone: AppTimeZone.wib,
      ),
      '14 Okt 2026, 10:30 WIB',
    );
  });
  test('Device-local timestamp converts through UTC', () {
    final instant = DateTime.utc(2026, 10, 14, 23, 15);
    expect(
      DateFormatter.formatFull(instant.toLocal(), timeZone: AppTimeZone.wib),
      '15 Okt 2026, 06:15 WIB',
    );
  });
  test('Date-only formatting preserves the provided calendar date', () {
    expect(
      DateFormatter.formatShort(DateTime.utc(2026, 12, 31, 18)),
      '31 Des 2026',
    );
  });

  group('formatTransactionDateTime', () {
    final fixedNow = DateTime.parse('2026-10-15T05:00:00Z'); // 12:00 WIB

    test('formats today with time', () {
      final txDate = DateTime.parse('2026-10-15T03:30:00Z'); // 10:30 WIB
      expect(
        DateFormatter.formatTransactionDateTime(
          txDate,
          showDate: true,
          timeZone: AppTimeZone.wib,
          now: fixedNow,
        ),
        'Hari ini, 10:30',
      );
    });

    test(
      'formats today without time when hour and minute are zero in zone',
      () {
        final txDate = DateTime.parse(
          '2026-10-14T17:00:00Z',
        ); // 00:00 WIB on Oct 15
        expect(
          DateFormatter.formatTransactionDateTime(
            txDate,
            showDate: true,
            timeZone: AppTimeZone.wib,
            now: fixedNow,
          ),
          'Hari ini',
        );
      },
    );

    test('formats yesterday with time', () {
      final txDate = DateTime.parse('2026-10-14T14:01:00Z'); // 21:01 WIB
      expect(
        DateFormatter.formatTransactionDateTime(
          txDate,
          showDate: true,
          timeZone: AppTimeZone.wib,
          now: fixedNow,
        ),
        'Kemarin, 21:01',
      );
    });

    test('formats same year date compactly without year', () {
      final txDate = DateTime.parse('2026-10-02T13:36:00Z'); // 20:36 WIB
      expect(
        DateFormatter.formatTransactionDateTime(
          txDate,
          showDate: true,
          timeZone: AppTimeZone.wib,
          now: fixedNow,
        ),
        '2 Okt, 20:36',
      );
    });

    test('formats different year date with full short date and time', () {
      final txDate = DateTime.parse('2025-12-31T16:45:00Z'); // 23:45 WIB
      expect(
        DateFormatter.formatTransactionDateTime(
          txDate,
          showDate: true,
          timeZone: AppTimeZone.wib,
          now: fixedNow,
        ),
        '31 Des 2025, 23:45',
      );
    });

    test('returns only time when showDate is false', () {
      final txDate = DateTime.parse('2026-10-14T14:01:00Z'); // 21:01 WIB
      expect(
        DateFormatter.formatTransactionDateTime(
          txDate,
          showDate: false,
          timeZone: AppTimeZone.wib,
          now: fixedNow,
        ),
        '21:01',
      );
    });
  });
}
