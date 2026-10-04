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
    'Desember'
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
    'Des'
  ];

  static String formatShort(DateTime date) {
    final day = date.day;
    final month = _shortMonthsIndo[date.month - 1];
    final year = date.year;
    return '$day $month $year';
  }

  static String formatDate(DateTime date) {
    return formatShort(date);
  }

  static String formatFull(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${formatShort(date)}, $hour:$minute WIB';
  }

  static String formatMonthYear(DateTime date) {
    final month = _monthsIndo[date.month - 1];
    return '$month ${date.year}';
  }

  static String formatRelativeOrDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(targetDate).inDays;

    if (diff == 0) {
      return 'Hari ini';
    } else if (diff == 1) {
      return 'Kemarin';
    } else if (diff == -1) {
      return 'Besok';
    } else {
      return formatShort(date);
    }
  }
}
