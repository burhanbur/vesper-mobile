import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/utils/budget_period.dart';

void main() {
  group('Budget period utilities (WM-03)', () {
    test(
      'monthly period calculates exact half-open UTC range with anchor day',
      () {
        final anchor = DateTime.parse('2026-01-15T00:00:00.000Z');
        final range = budgetPeriodRange(anchor, 'MONTHLY', '2026-03');

        expect(range.start, DateTime.parse('2026-03-15T00:00:00.000Z'));
        expect(range.end, DateTime.parse('2026-04-15T00:00:00.000Z'));
        expect(range.days, 31);
        expect(range.formatDisplay(), '15 Mar - 14 Apr 2026');
      },
    );

    test('monthly period clamps anchor day 31 in February 28/29', () {
      final anchor = DateTime.parse('2026-01-31T00:00:00.000Z');

      // Non-leap year 2026
      final range2026 = budgetPeriodRange(anchor, 'MONTHLY', '2026-02');
      expect(range2026.start, DateTime.parse('2026-02-28T00:00:00.000Z'));
      expect(range2026.end, DateTime.parse('2026-03-31T00:00:00.000Z'));
      expect(range2026.days, 31);

      // Leap year 2024
      final range2024 = budgetPeriodRange(anchor, 'MONTHLY', '2024-02');
      expect(range2024.start, DateTime.parse('2024-02-29T00:00:00.000Z'));
      expect(range2024.end, DateTime.parse('2024-03-31T00:00:00.000Z'));
      expect(range2024.days, 31);
    });

    test('annual period covers full year aligned to anchor month and day', () {
      final anchor = DateTime.parse('2026-01-01T00:00:00.000Z');
      final range = budgetPeriodRange(anchor, 'ANNUAL', '2026');

      expect(range.start, DateTime.parse('2026-01-01T00:00:00.000Z'));
      expect(range.end, DateTime.parse('2027-01-01T00:00:00.000Z'));
      expect(range.days, 365);
      expect(range.formatDisplay(), '1 Jan - 31 Des 2026');
    });

    test('weekly period aligns start to anchor weekday and spans 7 days', () {
      // 2026-01-01 is Thursday
      final anchor = DateTime.parse('2026-01-01T00:00:00.000Z');
      // 2026-03-10 is Tuesday
      final range = budgetPeriodRange(anchor, 'WEEKLY', '2026-03-10');

      // Should shift back to prior Thursday (2026-03-05)
      expect(range.start, DateTime.parse('2026-03-05T00:00:00.000Z'));
      expect(range.end, DateTime.parse('2026-03-12T00:00:00.000Z'));
      expect(range.days, 7);
    });

    test('daily period spans exactly 1 UTC day', () {
      final anchor = DateTime.parse('2026-01-01T00:00:00.000Z');
      final range = budgetPeriodRange(anchor, 'DAILY', '2026-03-15');

      expect(range.start, DateTime.parse('2026-03-15T00:00:00.000Z'));
      expect(range.end, DateTime.parse('2026-03-16T00:00:00.000Z'));
      expect(range.days, 1);
    });

    test('contains enforces half-open boundary [start, end)', () {
      final anchor = DateTime.parse('2026-01-01T00:00:00.000Z');
      final range = budgetPeriodRange(anchor, 'MONTHLY', '2026-03');

      final start = DateTime.parse('2026-03-01T00:00:00.000Z');
      final end = DateTime.parse('2026-04-01T00:00:00.000Z');

      expect(range.contains(start), isTrue);
      expect(
        range.contains(DateTime.parse('2026-03-15T12:00:00.000Z')),
        isTrue,
      );
      expect(
        range.contains(end.subtract(const Duration(milliseconds: 1))),
        isTrue,
      );
      expect(range.contains(end), isFalse);
      expect(
        range.contains(start.subtract(const Duration(milliseconds: 1))),
        isFalse,
      );
    });

    test('rejects invalid period formats', () {
      final anchor = DateTime.parse('2026-01-01T00:00:00.000Z');

      expect(
        () => budgetPeriodRange(anchor, 'MONTHLY', '2026-13'),
        throwsFormatException,
      );
      expect(
        () => budgetPeriodRange(anchor, 'MONTHLY', 'invalid'),
        throwsFormatException,
      );
      expect(
        () => budgetPeriodRange(anchor, 'ANNUAL', '26'),
        throwsFormatException,
      );
      expect(
        () => budgetPeriodRange(anchor, 'WEEKLY', '2026-02-30'),
        throwsFormatException,
      );
    });

    test('formatPeriodKey generates appropriate keys for each period type', () {
      final date = DateTime.parse('2026-03-15T10:30:00.000Z');

      expect(formatPeriodKey(date, 'MONTHLY'), '2026-03');
      expect(formatPeriodKey(date, 'ANNUAL'), '2026');
      expect(formatPeriodKey(date, 'WEEKLY'), '2026-03-15');
      expect(formatPeriodKey(date, 'DAILY'), '2026-03-15');
    });
  });
}
