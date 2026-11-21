import 'flight_pass_models.dart';

/// Display formatting for flight times, always in the airport's zone.
///
/// Airlines print 24-hour times with a leading zero ("06:10"), unlike bus
/// operators, so flights do not share the bus face's 12-hour formatter.
abstract final class FlightFormat {
  FlightFormat._();

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const List<String> _weekdays = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// "06:10", or empty when unknown.
  static String time(AirportTime? t) {
    if (t == null) return '';
    final DateTime l = t.local;
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  /// "Sat, 21 Nov", or empty when unknown.
  static String day(AirportTime? t) {
    if (t == null) return '';
    final DateTime l = t.local;
    return '${_weekdays[l.weekday - 1]}, ${l.day} ${_months[l.month - 1]}';
  }

  /// "21 Nov 2026", or empty when unknown.
  static String date(AirportTime? t) {
    if (t == null) return '';
    final DateTime l = t.local;
    return '${l.day} ${_months[l.month - 1]} ${l.year}';
  }

  /// "2h 50m" between scheduled departure and arrival, or empty.
  ///
  /// Computed on instants, so a flight across zones gets its real block time,
  /// not the difference between two wall clocks.
  static String duration(AirportTime? from, AirportTime? to) {
    if (from == null || to == null) return '';
    final Duration d = to.instant.difference(from.instant);
    if (d.isNegative || d.inMinutes == 0) return '';
    return compact(d);
  }

  /// "2h 50m", "45m", "3h".
  static String compact(Duration d) {
    final int h = d.inHours;
    final int m = d.inMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// Calendar days the arrival lands after the departure, each in its own
  /// airport's zone. A red-eye DEL 23:30 to BOM 01:40 is +1.
  static int arrivalDayOffset(AirportTime? from, AirportTime? to) {
    if (from == null || to == null) return 0;
    final DateTime a = from.local;
    final DateTime b = to.local;
    final int days = DateTime.utc(
      b.year,
      b.month,
      b.day,
    ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
    return days < 0 ? 0 : days;
  }
}
