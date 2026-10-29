/// Calendar-day helpers. Day arithmetic goes through the DateTime
/// constructor rather than `subtract(Duration(days: n))`, which drifts by an
/// hour across daylight-saving changes and can land on the wrong date.
abstract final class Dates {
  static String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  static String todayKey([DateTime? now]) => key(now ?? DateTime.now());

  static String yesterdayKey([DateTime? now]) =>
      key(addDays(now ?? DateTime.now(), -1));

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];

  /// "Friday, 17 October"
  static String longDate(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

  /// "9:00 PM"
  static String time(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:${minute.toString().padLeft(2, '0')} $period';
  }
}
