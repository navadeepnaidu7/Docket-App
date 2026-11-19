import 'package:flutter/foundation.dart';

import '../../domain/bus_pass_models.dart';
import '../../domain/pass_activity_date.dart';
import '../../domain/pass_status.dart';
import '../train/train_journey_status.dart';

/// Everything the bus face says about where a journey stands right now.
///
/// The same two-weight sentence as the train face — [lead] muted, then
/// [emphasis] in ink — with a quieter [detail] line under it. Bus tickets
/// carry no running feed, so every word comes from the timetable: nothing here
/// can print a delay or a cancellation.
@immutable
class BusJourneyStatus {
  const BusJourneyStatus({
    required this.lead,
    required this.emphasis,
    this.detail = '',
    this.progress = 0,
  });

  /// Muted opening words; empty when [emphasis] stands alone.
  final String lead;
  final String emphasis;
  final String detail;

  /// How much of the route line is filled, 0..1.
  final double progress;
}

/// Where [pass] stands at [now]. Spec in `docs/features/bus-pass-redesign.md`.
///
/// Pure on purpose: the face reads the clock through an injected callback, so
/// every branch here is unit-testable without pumping a widget.
BusJourneyStatus resolveBusJourneyStatus(BusPass pass, DateTime now) {
  final DateTime? departure = busDepartureAt(pass);
  final DateTime? arrival = busArrivalAt(pass);

  final bool arrived =
      pass.status == TicketStatus.expired ||
      (arrival != null && !now.isBefore(arrival));
  if (arrived) {
    final ({String time, String meridiem})? clock = busClock12(pass.arriveTime);
    return BusJourneyStatus(
      lead: clock == null ? '' : 'Arrived',
      emphasis: clock == null ? 'Arrived' : '${clock.time} ${clock.meridiem}',
      detail: 'Journey complete',
      progress: 1,
    );
  }

  final String overnight = _overnightLine(pass, arrival);

  if (departure == null) {
    final ({String time, String meridiem})? clock = busClock12(pass.departTime);
    return BusJourneyStatus(
      lead: clock == null ? '' : 'Departs at',
      emphasis: clock == null ? 'Scheduled' : '${clock.time} ${clock.meridiem}',
      detail: overnight,
    );
  }

  if (!now.isBefore(departure.add(_boardingGrace))) {
    if (arrival == null) {
      return const BusJourneyStatus(lead: '', emphasis: 'On the way');
    }
    final Duration left = arrival.difference(now);
    return BusJourneyStatus(
      lead: left.inMinutes < 1 ? 'Arriving' : 'Arrives in',
      emphasis: left.inMinutes < 1 ? 'now' : formatTrainMinutes(left.inMinutes),
      progress: _progress(departure, arrival, now),
    );
  }

  final Duration left = departure.difference(now);
  final ({String lead, String emphasis}) line;
  if (left.inSeconds <= 0) {
    line = (lead: '', emphasis: 'Boarding now');
  } else if (left.inMinutes < 1) {
    line = (lead: 'Departs', emphasis: 'now');
  } else {
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(
      departure.year,
      departure.month,
      departure.day,
    );
    final int days = day.difference(today).inDays;
    // Hours read better than "tomorrow" for a short overnight wait — a 06:00
    // coach seen at 22:00 is "8h" away, not a day.
    if (days == 0 || left.inHours < 12) {
      line = (lead: 'Departs in', emphasis: formatTrainMinutes(left.inMinutes));
    } else if (days == 1) {
      line = (lead: 'Departs', emphasis: 'tomorrow');
    } else {
      line = (lead: 'Departs in', emphasis: '$days days');
    }
  }

  return BusJourneyStatus(
    lead: line.lead,
    emphasis: line.emphasis,
    detail: overnight,
  );
}

/// Best-effort departure instant: the ISO field when present, otherwise the
/// display date with the display time folded in.
DateTime? busDepartureAt(BusPass pass) =>
    _instant(pass.departAt, pass.date, pass.departTime);

/// Best-effort arrival instant, built the same way as [busDepartureAt].
DateTime? busArrivalAt(BusPass pass) => _instant(
  pass.arriveAt,
  pass.arrivalDate.trim().isEmpty ? pass.date : pass.arrivalDate,
  pass.arriveTime,
);

DateTime? _instant(String? iso, String date, String time) {
  final DateTime? exact = PassActivityDate.parse(iso);
  if (exact != null) return exact;

  final DateTime? day = PassActivityDate.parse(date);
  if (day == null) return null;

  final ({int hour, int minute})? clock = parseTrainClock(time);
  if (clock == null) return null;
  return DateTime(day.year, day.month, day.day, clock.hour, clock.minute);
}

/// "08:30 AM" / "20:30" -> (time: "8:30", meridiem: "AM" / "PM").
///
/// Bus operators print 12-hour times, so the face does too, without the
/// leading zero a 44 dp "08" would make conspicuous. Null when unparseable.
({String time, String meridiem})? busClock12(String raw) {
  final ({int hour, int minute})? clock = parseTrainClock(raw);
  if (clock == null) return null;
  final int h12 = clock.hour % 12 == 0 ? 12 : clock.hour % 12;
  return (
    time: '$h12:${clock.minute.toString().padLeft(2, '0')}',
    meridiem: clock.hour < 12 ? 'AM' : 'PM',
  );
}

/// Calendar days the arrival lands past the departure, for callers that show
/// an overnight marker.
///
/// Prefers the ISO instants and falls back to the display dates. Returns 0
/// when neither parses — an unmarked arrival beats a wrong one.
int busArrivalDayOffset(BusPass pass) {
  final DateTime? depart =
      PassActivityDate.parse(pass.departAt) ??
      PassActivityDate.parse(pass.date);
  final DateTime? arrive =
      PassActivityDate.parse(pass.arriveAt) ??
      PassActivityDate.parse(pass.arrivalDate);
  if (depart == null || arrive == null) return 0;

  final int days = DateTime(
    arrive.year,
    arrive.month,
    arrive.day,
  ).difference(DateTime(depart.year, depart.month, depart.day)).inDays;
  return days > 0 ? days : 0;
}

/// Journey length, e.g. "8h 15m", or empty when it cannot be computed.
///
/// The display times carry no date, so an overnight run computed from them
/// alone would come out negative; only the ISO instants are trustworthy.
String busDurationLabel(BusPass pass) {
  final DateTime? depart = PassActivityDate.parse(pass.departAt);
  final DateTime? arrive = PassActivityDate.parse(pass.arriveAt);
  if (depart == null || arrive == null) return '';

  final Duration d = arrive.difference(depart);
  if (d.inMinutes <= 0) return '';

  final int hours = d.inHours;
  final int minutes = d.inMinutes % 60;
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

/// "Overnight, arrives Sat 5:30 AM", or empty for a same-day run.
String _overnightLine(BusPass pass, DateTime? arrival) {
  if (busArrivalDayOffset(pass) == 0) return '';
  final ({String time, String meridiem})? clock = busClock12(pass.arriveTime);
  if (clock == null) return 'Overnight';
  final String day = arrival == null
      ? ''
      : '${_weekdays[arrival.weekday - 1]} ';
  return 'Overnight, arrives $day${clock.time} ${clock.meridiem}';
}

const List<String> _weekdays = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// How long after the scheduled time the face still says "Boarding now"
/// before treating the coach as underway.
const Duration _boardingGrace = Duration(minutes: 10);

double _progress(DateTime departure, DateTime arrival, DateTime now) {
  if (!arrival.isAfter(departure)) return 0;
  final double total = arrival.difference(departure).inSeconds.toDouble();
  final double done = now.difference(departure).inSeconds.toDouble();
  return (done / total).clamp(0.0, 1.0).toDouble();
}
