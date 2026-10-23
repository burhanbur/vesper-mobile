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
}
