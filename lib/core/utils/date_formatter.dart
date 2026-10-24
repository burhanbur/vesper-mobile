import 'app_time_zone.dart';

class DateFormatter {
  DateFormatter._();

  static const List<String> _monthsIndo = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static const List<String> _shortMonthsIndo = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  /// API timestamps must carry an explicit offset. Calendar dates are separate.
  static String timestamp(
    Object? value, {
    AppTimeZone timeZone = AppTimeZone.device,
  }) {
    final text = value?.toString() ?? '';
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}T.+(Z|[+-]\d{2}:?\d{2})$').hasMatch(text)) {
      return 'Belum tersedia';
    }
    final parsed = DateTime.tryParse(text);
    return parsed == null
        ? 'Belum tersedia'
        : formatFull(parsed, timeZone: timeZone);
  }

  static String calendarDate(Object? value) {
    final text = value?.toString() ?? '';
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return 'Belum tersedia';
    final parsed = DateTime.tryParse('${text}T00:00:00Z');
    if (parsed == null || parsed.toIso8601String().substring(0, 10) != text) {
      return 'Belum tersedia';
    }
    return formatShort(parsed);
  }

  static String fixedZone(int offset) => switch (offset) {
    420 => 'WIB',
    480 => 'WITA',
    540 => 'WIT',
    _ =>
      'GMT${offset < 0 ? '-' : '+'}${(offset.abs() ~/ 60).toString().padLeft(2, '0')}:${(offset.abs() % 60).toString().padLeft(2, '0')}',
  };

  static String formatMonthShort(int month) {
    if (month < 1 || month > 12) return '';
    return _shortMonthsIndo[month - 1];
  }

  static String formatShort(DateTime date) {
    final day = date.day;
    final month = _shortMonthsIndo[date.month - 1];
    final year = date.year;
    return '$day $month $year';
  }

  static String formatDate(DateTime date) {
    return formatShort(date);
  }

  static String formatFull(
    DateTime date, {
    AppTimeZone timeZone = AppTimeZone.device,
  }) {
    final calendar = timeZone.at(date);
    return '${formatShort(calendar)}, ${formatTime(date, timeZone: timeZone)} ${timeZone.abbreviation(date)}';
  }

  static String formatMonthYear(DateTime date) {
    final month = _monthsIndo[date.month - 1];
    return '$month ${date.year}';
  }

  static String formatTime(
    DateTime date, {
    AppTimeZone timeZone = AppTimeZone.device,
  }) {
    final calendar = timeZone.at(date);
    final hour = calendar.hour.toString().padLeft(2, '0');
    final minute = calendar.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String formatRelativeOrDate(
    DateTime date, {
    AppTimeZone timeZone = AppTimeZone.device,
    DateTime? now,
  }) {
    final calendarNow = timeZone.at(now ?? DateTime.now());
    final calendarDate = timeZone.at(date);
    // Compare calendar dates, rather than 24h durations across DST boundaries.
    final today = DateTime.utc(
      calendarNow.year,
      calendarNow.month,
      calendarNow.day,
    );
    final targetDate = DateTime.utc(
      calendarDate.year,
      calendarDate.month,
      calendarDate.day,
    );
    final diff = today.difference(targetDate).inDays;

    if (diff == 0) {
      return 'Hari ini';
    } else if (diff == 1) {
      return 'Kemarin';
    } else if (diff == -1) {
      return 'Besok';
    } else {
      return formatShort(calendarDate);
    }
  }
}
