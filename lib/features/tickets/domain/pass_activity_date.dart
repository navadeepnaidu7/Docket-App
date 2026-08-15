import 'pass_catalog.dart';

/// Resolves the real-world activity date of a pass (journey / show time).
///
/// Passes carry two date representations: optional machine-readable ISO fields
/// ([TrainPass.departAt], [MoviePass.showAt]) and the human display strings the
/// wallet actually renders. Backend payloads may omit the ISO fields entirely,
/// so archive sorting and month grouping have to fall back to parsing the
/// display form.
///
/// Pure Dart on purpose — `intl` is not a dependency, so month names and
/// formatting are hand-rolled and the whole class stays unit-testable.
abstract final class PassActivityDate {
  PassActivityDate._();

  static const List<String> _monthPrefixes = <String>[
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];

  static const List<String> _weekdayPrefixes = <String>[
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun',
  ];

  static const List<String> _monthsLong = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _monthsShort = <String>[
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

  static final RegExp _digits = RegExp(r'^\d+$');
  static final RegExp _separators = RegExp(r'[\s,]+');
  static final RegExp _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');

  /// Best-effort activity instant for a pass, or null when nothing parses.
  ///
  /// Prefers the ISO field but falls through on a malformed one, so a bad
  /// `departAt` never hides a perfectly good display date.
  static DateTime? of(WalletPassItem item) => switch (item) {
        TrainPassItem(:final ticket) =>
          parse(ticket.departAt) ?? parse(ticket.date),
        MoviePassItem(:final pass) => parse(pass.showAt) ?? parse(pass.showDate),
        BusPassItem(:final pass) => parse(pass.departAt) ?? parse(pass.date),
      };

  /// Parses an ISO 8601 instant or a display date, or returns null.
  ///
  /// Accepted display forms: `10 Jan 2024`, `03 Sep 2023`, `10 January 2024`,
  /// `Mon, 10 Feb 2025`, `Feb 10, 2025`.
  static DateTime? parse(String? raw) {
    if (raw == null) return null;
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // ISO fields win. Convert to local: a `...T20:00:00Z` show time bucketed as
    // UTC would land in the wrong month for a user near a month boundary.
    final DateTime? iso = DateTime.tryParse(trimmed);
    if (iso != null) {
      // DateTime.parse rolls overflow dates over silently, so '2024-02-31'
      // comes back as 2 Mar 2024 and files the pass under the wrong month.
      // Round-trip the literal calendar fields rather than the parsed value:
      // a UTC offset can legitimately move `...T01:00:00+05:30` onto the
      // previous day, and that is not the failure being caught here.
      final Match? ymd = _isoDate.firstMatch(trimmed);
      if (ymd != null && !_isRealDate(ymd)) return null;
      return iso.toLocal();
    }

    final List<String> tokens = trimmed
        .split(_separators)
        .where((String t) => t.isNotEmpty)
        .toList();
    if (tokens.isNotEmpty && _isWeekday(tokens.first)) {
      tokens.removeAt(0);
    }
    if (tokens.length != 3) return null;

    return _assemble(day: tokens[0], month: tokens[1], year: tokens[2]) ??
        _assemble(day: tokens[1], month: tokens[0], year: tokens[2]);
  }

  /// Month section header, e.g. "February 2025".
  ///
  /// Always carries the year — an archive spans years by definition.
  static String monthLabel(DateTime date) =>
      '${_monthsLong[date.month - 1]} ${date.year}';

  /// Year section header, e.g. "2025".
  static String yearLabel(DateTime date) => '${date.year}';

  /// Compact card date, e.g. "10 Feb". The section header carries the year.
  static String shortDayLabel(DateTime date) =>
      '${date.day} ${_monthsShort[date.month - 1]}';

  /// Full day label, e.g. "10 Jan 2024".
  static String dayLabel(DateTime date) =>
      '${date.day} ${_monthsShort[date.month - 1]} ${date.year}';

  /// True when the `YYYY-MM-DD` fields in [ymd] name a day that exists.
  static bool _isRealDate(Match ymd) {
    final int y = int.parse(ymd.group(1)!);
    final int m = int.parse(ymd.group(2)!);
    final int d = int.parse(ymd.group(3)!);
    final DateTime probe = DateTime.utc(y, m, d);
    return probe.year == y && probe.month == m && probe.day == d;
  }

  static bool _isWeekday(String token) {
    if (token.length < 3) return false;
    return _weekdayPrefixes.contains(token.substring(0, 3).toLowerCase());
  }

  static DateTime? _assemble({
    required String day,
    required String month,
    required String year,
  }) {
    final int? d = _intToken(day);
    if (d == null || d < 1 || d > 31) return null;
    final int? m = _monthFromToken(month);
    if (m == null) return null;
    final int? y = _yearFromToken(year);
    if (y == null) return null;

    // DateTime rolls invalid days over silently: DateTime(2024, 1, 32) is
    // 1 Feb 2024. Round-trip the components to reject that.
    final DateTime resolved = DateTime(y, m, d);
    if (resolved.year != y || resolved.month != m || resolved.day != d) {
      return null;
    }
    return resolved;
  }

  /// Month index (1-12) from a name or prefix: `Jan` and `January` both work.
  static int? _monthFromToken(String token) {
    if (token.length < 3) return null;
    final int index = _monthPrefixes.indexOf(token.substring(0, 3).toLowerCase());
    return index == -1 ? null : index + 1;
  }

  static int? _yearFromToken(String token) {
    final int? value = _intToken(token);
    if (value == null) return null;
    if (token.length == 4) return value;
    if (token.length == 2) return 2000 + value;
    return null;
  }

  /// Digits only, so `+5` and `1a` are rejected rather than coerced.
  static int? _intToken(String token) =>
      _digits.hasMatch(token) ? int.tryParse(token) : null;
}
