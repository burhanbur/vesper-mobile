/// Calendar conversion only; persisted transaction timestamps remain UTC.
/// Device mode uses the OS rules (including DST). Indonesian zones are fixed.
enum AppTimeZone {
  device('Ikuti perangkat', null),
  wib('WIB · Jakarta', 7),
  wita('WITA · Makassar', 8),
  wit('WIT · Jayapura', 9);

  final String label;
  final int? offsetHours;
  const AppTimeZone(this.label, this.offsetHours);

  /// Wall-clock components. Fixed-zone results are calendar values, not instants.
  DateTime at(DateTime instant) => this == device
      ? instant.toLocal()
      : instant.toUtc().add(Duration(hours: offsetHours!));

  /// Date-only calendar value; never persist this as an event timestamp.
  DateTime calendarDate(DateTime instant) {
    final value = at(instant);
    return DateTime.utc(value.year, value.month, value.day);
  }

  int offsetMinutesAt(DateTime instant) => this == device
      ? instant.toLocal().timeZoneOffset.inMinutes
      : offsetHours! * 60;

  /// Interpret calendar components in this zone and return the UTC instant.
  DateTime fromCalendar(DateTime calendar) => this == device
      ? DateTime(
          calendar.year,
          calendar.month,
          calendar.day,
          calendar.hour,
          calendar.minute,
          calendar.second,
          calendar.millisecond,
          calendar.microsecond,
        ).toUtc()
      : DateTime.utc(
          calendar.year,
          calendar.month,
          calendar.day,
          calendar.hour,
          calendar.minute,
          calendar.second,
          calendar.millisecond,
          calendar.microsecond,
        ).subtract(Duration(hours: offsetHours!));

  String abbreviation(DateTime instant) {
    if (this != device) return name.toUpperCase();
    final minutes = instant.toLocal().timeZoneOffset.inMinutes;
    if (minutes == 420) return 'WIB';
    if (minutes == 480) return 'WITA';
    if (minutes == 540) return 'WIT';
    final absolute = minutes.abs();
    return 'GMT${minutes < 0 ? '-' : '+'}${(absolute ~/ 60).toString().padLeft(2, '0')}:${(absolute % 60).toString().padLeft(2, '0')}';
  }
}
