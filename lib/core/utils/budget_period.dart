import 'dart:math' as math;

import 'date_formatter.dart';

/// Half-open UTC time range [start, end) for budget evaluation.
class BudgetPeriodRange {
  final DateTime start;
  final DateTime end;

  const BudgetPeriodRange({required this.start, required this.end});

  /// Total days in the period.
  int get days => end.difference(start).inDays;

  /// Alias for compatibility with period progress calculations.
  int get daysInPeriod => days;

  /// Inclusive start to inclusive end presentation string.
  /// Because [end] is exclusive, the last active day is end - 1 day.
  String formatDisplay() {
    final lastDay = end.toUtc().subtract(const Duration(days: 1));
    final startUtc = start.toUtc();
    if (startUtc.year == lastDay.year) {
      if (startUtc.month == lastDay.month) {
        return '${startUtc.day} - ${DateFormatter.formatShort(lastDay)}';
      }
      return '${startUtc.day} ${DateFormatter.formatMonthShort(startUtc.month)} - ${DateFormatter.formatShort(lastDay)}';
    }
    return '${DateFormatter.formatShort(startUtc)} - ${DateFormatter.formatShort(lastDay)}';
  }

  /// Whether a given transaction timestamp falls within this period.
  bool contains(DateTime date) {
    final utc = date.toUtc();
    return !utc.isBefore(start) && utc.isBefore(end);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetPeriodRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;

  @override
  String toString() =>
      'BudgetPeriodRange(${start.toIso8601String()} -> ${end.toIso8601String()})';
}

DateTime _clampedUtcDate(int year, int month, int targetDay) {
  final lastDayOfMonth = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(year, month, math.min(targetDay, lastDayOfMonth));
}

bool _isCalendarDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return false;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) return false;
  final parsed = DateTime.utc(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day;
}

/// Computes the exact half-open UTC [start, end) range for a budget's anchor date and period.
/// Matches backend rules in `src/common/utils/budget-period.ts`.
BudgetPeriodRange budgetPeriodRange(
  DateTime anchor,
  String periodType,
  String period,
) {
  final anchorUtc = anchor.isUtc
      ? anchor
      : DateTime.utc(anchor.year, anchor.month, anchor.day);
  final type = periodType.toUpperCase();

  if (type == 'MONTHLY') {
    final match = RegExp(r'^(\d{4})-(0[1-9]|1[0-2])$').firstMatch(period);
    if (match == null || period.startsWith('0000')) {
      throw FormatException('Invalid monthly period: $period');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final start = _clampedUtcDate(year, month, anchorUtc.day);
    final end = _clampedUtcDate(year, month + 1, anchorUtc.day);
    return BudgetPeriodRange(start: start, end: end);
  }

  if (type == 'ANNUAL') {
    final match = RegExp(r'^\d{4}$').firstMatch(period);
    if (match == null || period == '0000') {
      throw FormatException('Invalid annual period: $period');
    }
    final year = int.parse(period);
    final start = _clampedUtcDate(year, anchorUtc.month, anchorUtc.day);
    final end = _clampedUtcDate(year + 1, anchorUtc.month, anchorUtc.day);
    return BudgetPeriodRange(start: start, end: end);
  }

  if (!_isCalendarDate(period)) {
    throw FormatException('Invalid daily or weekly period: $period');
  }

  final parsedDate = DateTime.parse('${period}T00:00:00.000Z');
  if (type == 'WEEKLY') {
    // Convert DateTime.weekday (1=Mon..7=Sun) to JS getUTCDay() (0=Sun, 1=Mon..6=Sat)
    final parsedJsDay = parsedDate.weekday % 7;
    final anchorJsDay = anchorUtc.weekday % 7;
    final diffDays = (parsedJsDay - anchorJsDay + 7) % 7;
    final start = parsedDate.subtract(Duration(days: diffDays));
    final end = start.add(const Duration(days: 7));
    return BudgetPeriodRange(start: start, end: end);
  }

  // DAILY
  return BudgetPeriodRange(
    start: parsedDate,
    end: parsedDate.add(const Duration(days: 1)),
  );
}

/// Helper to generate the canonical period string for a date and period type.
String formatPeriodKey(DateTime date, String periodType) {
  final utc = date.toUtc();
  return switch (periodType.toUpperCase()) {
    'ANNUAL' => '${utc.year}',
    'DAILY' || 'WEEKLY' =>
      '${utc.year}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}',
    _ => '${utc.year}-${utc.month.toString().padLeft(2, '0')}',
  };
}
