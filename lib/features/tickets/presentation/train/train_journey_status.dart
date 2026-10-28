import 'package:flutter/foundation.dart';

import '../../domain/pass_activity_date.dart';
import '../../domain/ticket_models.dart';

/// How loud one piece of the status sentence is.
enum TrainStatusTone { neutral, warning, critical }

/// One comma-joined phrase in the detail line, e.g. "on time".
@immutable
class TrainStatusPart {
  const TrainStatusPart(this.text, [this.tone = TrainStatusTone.neutral]);

  final String text;
  final TrainStatusTone tone;

  @override
  bool operator ==(Object other) =>
      other is TrainStatusPart && other.text == text && other.tone == tone;

  @override
  int get hashCode => Object.hash(text, tone);

  @override
  String toString() => 'TrainStatusPart("$text", ${tone.name})';
}

/// Everything the face says about where a journey stands right now.
///
/// The lead line reads as one sentence in two weights — [lead] muted, then
/// [emphasis] in ink — the same voice as the account summary. [details] is the
/// quieter line under it.
@immutable
class TrainJourneyStatus {
  const TrainJourneyStatus({
    required this.lead,
    required this.emphasis,
    this.emphasisTone = TrainStatusTone.neutral,
    this.details = const <TrainStatusPart>[],
    this.progress = 0,
    this.departureShiftMinutes,
    this.arrivalShiftMinutes,
  });

  /// Muted opening words; empty when [emphasis] stands alone.
  final String lead;
  final String emphasis;
  final TrainStatusTone emphasisTone;
  final List<TrainStatusPart> details;

  /// How much of the route line is filled, 0..1.
  final double progress;

  /// Set when the departure the face shows should move by a known delay.
  final int? departureShiftMinutes;

  /// Set when the arrival the face shows should move by a known delay.
  final int? arrivalShiftMinutes;

  /// [details] as the sentence the face prints, first letter raised.
  String get detailText {
    if (details.isEmpty) return '';
    final String joined = details.map((TrainStatusPart p) => p.text).join(', ');
    return joined[0].toUpperCase() + joined.substring(1);
  }
}

/// Where [pass] stands at [now].
///
/// Pure on purpose: the face reads the clock through an injected callback, so
/// every branch here is unit-testable without pumping a widget.
TrainJourneyStatus resolveTrainJourneyStatus(TrainPass pass, DateTime now) {
  if (pass.isAwaitingJourney) {
    return const TrainJourneyStatus(lead: '', emphasis: 'Fetching journey');
  }

  // A cancelled train makes every other line misleading.
  if (pass.runState == TrainRunState.cancelled) {
    return const TrainJourneyStatus(
      lead: '',
      emphasis: 'Cancelled',
      emphasisTone: TrainStatusTone.critical,
    );
  }

  if (pass.runState == TrainRunState.arrived ||
      pass.status == TicketStatus.expired) {
    final String arrival = trainClock24(pass.arriveTime);
    return TrainJourneyStatus(
      lead: arrival.isEmpty ? '' : 'Arrived',
      emphasis: arrival.isEmpty ? 'Arrived' : arrival,
      details: const <TrainStatusPart>[TrainStatusPart('journey complete')],
      progress: 1,
    );
  }

  final DateTime? departure = trainDepartureAt(pass);
  final DateTime? arrival = trainArrivalAt(pass);
  final int delay = pass.isDelayed ? pass.delayMinutes! : 0;
  final DateTime? expectedDeparture = departure?.add(Duration(minutes: delay));

  final bool originLeft =
      pass.halts.isNotEmpty && pass.halts.first.state == HaltState.departed;
  // A halt flagged "departed" is only believed when the clock agrees: a stale
  // or mis-dated feed must not put "Arrives in 72h" on a train that has not
  // left yet.
  final bool underway =
      (originLeft &&
          (expectedDeparture == null ||
              !now.isBefore(expectedDeparture.subtract(_haltSlack)))) ||
      (expectedDeparture != null &&
          !now.isBefore(expectedDeparture.add(_boardingGrace)));

  if (underway) {
    final DateTime? expectedArrival = arrival?.add(Duration(minutes: delay));
    final TicketHalt? next = pass.nextHalt;
    final String nextTime = next == null
        ? ''
        : trainClock24((next.actual ?? '').trim().isEmpty
              ? next.time
              : next.actual!);
    final List<TrainStatusPart> details = <TrainStatusPart>[
      if (delay > 0)
        TrainStatusPart(
          'running ${formatTrainMinutes(delay)} late',
          TrainStatusTone.warning,
        ),
      if (next != null && next.station.trim().isNotEmpty)
        TrainStatusPart(
          nextTime.isEmpty
              ? 'next stop ${next.station.trim()}'
              : 'next stop ${next.station.trim()} at $nextTime',
        ),
    ];

    final ({String lead, String emphasis}) line;
    if (expectedArrival == null) {
      line = (lead: '', emphasis: 'On the way');
    } else {
      final Duration left = expectedArrival.difference(now);
      line = left.inMinutes < 1
          ? (lead: 'Arriving', emphasis: 'now')
          : (lead: 'Arrives in', emphasis: formatTrainMinutes(left.inMinutes));
    }

    return TrainJourneyStatus(
      lead: line.lead,
      emphasis: line.emphasis,
      details: details,
      progress: _progress(pass, expectedDeparture, expectedArrival, now),
      arrivalShiftMinutes: delay > 0 ? delay : null,
    );
  }

  final List<TrainStatusPart> details = <TrainStatusPart>[
    if (delay > 0)
      TrainStatusPart(
        'running ${formatTrainMinutes(delay)} late',
        TrainStatusTone.warning,
      )
    // Only claim "on time" when the backend actually said so. Inferring it
    // from the absence of a delay would print a confident status on every
    // pass the server has never reported on.
    else if (pass.runState == TrainRunState.onTime)
      const TrainStatusPart('on time'),
    if (_unconfirmed(pass.bookingStatus))
      TrainStatusPart(pass.bookingStatus.trim(), TrainStatusTone.warning),
    if (_chartPrepared(pass.chartStatus))
      const TrainStatusPart('chart prepared'),
  ];

  final ({String lead, String emphasis}) line = expectedDeparture == null
      ? (lead: 'Departs at', emphasis: _orDash(trainClock24(pass.departTime)))
      : _countdown(expectedDeparture, now);

  return TrainJourneyStatus(
    lead: line.lead,
    emphasis: line.emphasis,
    details: details,
    departureShiftMinutes: delay > 0 ? delay : null,
  );
}

/// Best-effort departure instant: the ISO field when present, otherwise the
/// display date with the display time folded in.
///
/// [PassActivityDate.parse] on `date` alone lands on midnight, which would make
/// every same-day countdown read hours early.
DateTime? trainDepartureAt(TrainPass pass) =>
    _instant(pass.departAt, pass.date, pass.departTime);

/// Best-effort arrival instant, built the same way as [trainDepartureAt].
DateTime? trainArrivalAt(TrainPass pass) => _instant(
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

/// Calendar days between departure and arrival, or 0 when unknown.
int trainArrivalDayOffset(TrainPass pass) {
  final DateTime? from = PassActivityDate.parse(pass.date);
  final DateTime? to = PassActivityDate.parse(pass.arrivalDate);
  if (from == null || to == null) return 0;
  final int days = DateTime(to.year, to.month, to.day)
      .difference(DateTime(from.year, from.month, from.day))
      .inDays;
  return days > 0 ? days : 0;
}

/// "07:10 AM" -> "07:10", "02:40 PM" -> "14:40", shifted by [shiftMinutes].
///
/// Railway timetables in India are 24-hour; a meridiem suffix on a 50 dp time
/// would also crowd the route line out. Unparseable input is returned trimmed.
String trainClock24(String raw, {int shiftMinutes = 0}) {
  final ({int hour, int minute})? clock = parseTrainClock(raw);
  if (clock == null) return raw.trim();
  final int total =
      ((clock.hour * 60 + clock.minute + shiftMinutes) % _minutesPerDay +
          _minutesPerDay) %
      _minutesPerDay;
  final String h = (total ~/ 60).toString().padLeft(2, '0');
  final String m = (total % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// "25 min", "2h 10m", "3h", "1d 15h".
String formatTrainMinutes(int minutes) {
  if (minutes < 60) return '$minutes min';
  if (minutes >= _minutesPerDay) {
    final int days = minutes ~/ _minutesPerDay;
    final int hours = (minutes % _minutesPerDay) ~/ 60;
    return hours == 0 ? '${days}d' : '${days}d ${hours}h';
  }
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
}

/// Minimal 12/24-hour parser for display times.
({int hour, int minute})? parseTrainClock(String raw) {
  final Match? m = _clockPattern.firstMatch(raw.trim());
  if (m == null) return null;

  int hour = int.parse(m.group(1)!);
  final int minute = int.parse(m.group(2)!);
  if (minute > 59) return null;

  final String? meridiem = m.group(3)?.toLowerCase();
  if (meridiem != null) {
    if (hour < 1 || hour > 12) return null;
    if (meridiem == 'am') {
      if (hour == 12) hour = 0;
    } else if (hour != 12) {
      hour += 12;
    }
  } else if (hour > 23) {
    return null;
  }
  return (hour: hour, minute: minute);
}

final RegExp _clockPattern = RegExp(r'^(\d{1,2})[:.](\d{2})\s*([AaPp][Mm])?');

const int _minutesPerDay = 24 * 60;

/// How long after the scheduled time the face still says "Boarding now"
/// before treating the train as underway.
const Duration _boardingGrace = Duration(minutes: 10);

/// How early a "departed" origin halt is trusted, for trains leaving ahead of
/// the timetable.
const Duration _haltSlack = Duration(hours: 1);

({String lead, String emphasis}) _countdown(DateTime departure, DateTime now) {
  final Duration left = departure.difference(now);
  if (left.inSeconds <= 0) return (lead: '', emphasis: 'Boarding now');
  if (left.inMinutes < 1) return (lead: 'Departs', emphasis: 'now');

  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime day = DateTime(departure.year, departure.month, departure.day);
  final int days = day.difference(today).inDays;

  // Hours read better than "tomorrow" for an overnight wait that is still
  // short — a 06:00 train seen at 22:00 is "8h" away, not a day.
  if (days == 0 || left.inHours < 12) {
    return (lead: 'Departs in', emphasis: formatTrainMinutes(left.inMinutes));
  }
  if (days == 1) return (lead: 'Departs', emphasis: 'tomorrow');
  return (lead: 'Departs in', emphasis: '$days days');
}

double _progress(
  TrainPass pass,
  DateTime? departure,
  DateTime? arrival,
  DateTime now,
) {
  if (pass.progressFraction > 0) {
    return pass.progressFraction.clamp(0.0, 1.0).toDouble();
  }
  if (departure == null || arrival == null || !arrival.isAfter(departure)) {
    return 0;
  }
  final double total = arrival.difference(departure).inSeconds.toDouble();
  final double done = now.difference(departure).inSeconds.toDouble();
  return (done / total).clamp(0.0, 1.0).toDouble();
}

bool _unconfirmed(String raw) {
  final String s = raw.trim().toUpperCase();
  if (s.isEmpty) return false;
  return !(s.startsWith('CNF') ||
      s.startsWith('CONFIRM') ||
      s.startsWith('COMPLETE'));
}

bool _chartPrepared(String raw) {
  final String s = raw.trim().toLowerCase();
  return s.contains('prepared') && !s.contains('not');
}

String _orDash(String v) => v.isEmpty ? '—' : v;
