import 'pass_activity_date.dart';
import 'pass_catalog.dart';
import 'pass_status.dart';

String passTitle(WalletPassItem item) => switch (item) {
  TrainPassItem(:final ticket) => _nonempty(ticket.trainTitle, 'Train ticket'),
  MoviePassItem(:final pass) => _nonempty(pass.movieTitle, 'Movie ticket'),
  BusPassItem(:final pass) => _nonempty(pass.operator, 'Bus ticket'),
};

String passWhenLabel(WalletPassItem item) {
  final (String, String) display = switch (item) {
    TrainPassItem(:final ticket) => (ticket.date, ticket.departTime),
    MoviePassItem(:final pass) => (pass.showDate, pass.showTime),
    BusPassItem(:final pass) => (pass.date, pass.departTime),
  };
  final start = passStartTime(item);
  return _join([
    display.$1.trim().isEmpty && start != null
        ? PassActivityDate.dayLabel(start)
        : display.$1,
    display.$2.trim().isEmpty && start != null
        ? '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'
        : display.$2,
  ]);
}

String passPlaceLabel(WalletPassItem item) => switch (item) {
  TrainPassItem(:final ticket) => _join([
    ticket.fromName,
    ticket.toName,
  ], ' → '),
  MoviePassItem(:final pass) => pass.cinemaName,
  BusPassItem(:final pass) => _join([
    pass.resolvedFromCity,
    pass.resolvedToCity,
  ], ' → '),
};

String _nonempty(String value, String fallback) =>
    value.trim().isEmpty ? fallback : value.trim();
String _join(List<String> values, [String separator = ' · ']) => values
    .map((value) => value.trim())
    .where((value) => value.isNotEmpty)
    .join(separator);

/// Only claims an upcoming time when both a date and a time are available.
/// Date-only values must not silently become a midnight departure.
DateTime? passStartTime(WalletPassItem item) {
  final (String?, String) raw = switch (item) {
    TrainPassItem(:final ticket) => (ticket.departAt, ticket.departTime),
    MoviePassItem(:final pass) => (pass.showAt, pass.showTime),
    BusPassItem(:final pass) => (pass.departAt, pass.departTime),
  };
  if (raw.$1 != null && RegExp(r'[Tt ]\d{2}:\d{2}').hasMatch(raw.$1!)) {
    final parsed = PassActivityDate.parse(raw.$1);
    if (parsed != null) return parsed;
  }
  final date = PassActivityDate.of(item);
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$',
    caseSensitive: false,
  ).firstMatch(raw.$2.trim());
  if (date == null || match == null) return null;
  var hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  final meridiem = match[3]?.toUpperCase();
  if (minute > 59 || (meridiem == null ? hour > 23 : hour < 1 || hour > 12)) {
    return null;
  }
  if (meridiem != null) hour = hour % 12 + (meridiem == 'PM' ? 12 : 0);
  return DateTime(date.year, date.month, date.day, hour, minute);
}

WalletPassItem? nextUpcomingPass(List<WalletPassItem> items, DateTime now) {
  WalletPassItem? next;
  DateTime? soonest;
  for (final item in items) {
    if (item.status != TicketStatus.active) continue;
    if (item case TrainPassItem(:final ticket)) {
      if (ticket.runState == TrainRunState.cancelled ||
          ticket.runState == TrainRunState.arrived) {
        continue;
      }
    }
    final start = passStartTime(item);
    if (start == null || start.isBefore(now)) continue;
    if (soonest == null || start.isBefore(soonest)) {
      next = item;
      soonest = start;
    }
  }
  return next;
}
