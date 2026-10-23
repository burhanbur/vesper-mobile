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
