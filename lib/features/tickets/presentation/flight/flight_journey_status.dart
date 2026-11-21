import 'package:flutter/foundation.dart';

import '../../domain/flight_format.dart';
import '../../domain/flight_pass_models.dart';
import '../../domain/pass_status.dart';
import '../train/train_journey_status.dart';

/// How a status line or feed row should be coloured.
enum FlightStatusTone { neutral, positive, warning, live }

/// Everything the flight face says about where the flight stands right now.
///
/// The train and bus faces' two-weight sentence — [lead] muted, then
/// [emphasis] in ink — with a quieter [detail] under it.
///
/// The honesty rule from the train band holds: nothing here claims "On time",
/// "Boarding", "Delayed" or "Landed" unless [FlightPass.live] said so. With no
/// live feed every word comes from the timetable.
@immutable
class FlightJourneyStatus {
  const FlightJourneyStatus({
    required this.lead,
    required this.emphasis,
    this.detail = '',
    this.progress = 0,
    this.tone = FlightStatusTone.neutral,
  });

  final String lead;
  final String emphasis;
  final String detail;

  /// How much of the route line is filled, 0..1.
  final double progress;
  final FlightStatusTone tone;
}

/// Minutes either side of schedule that still count as "to schedule". Airline
/// on-time performance uses 15; a traveller notices 5.
const int kFlightDelayThresholdMinutes = 5;

/// Without a live feed, how long after scheduled departure the face keeps
/// counting down before assuming the aircraft is airborne. Pushback plus taxi.
const Duration _airborneGrace = Duration(minutes: 20);

/// Where [pass] stands at [now]. Spec in `docs/features/flight-pass.md`.
FlightJourneyStatus resolveFlightJourneyStatus(FlightPass pass, DateTime now) {
  final FlightLive? live = pass.live;
  final FlightLiveState? state = live?.state;
  final AirportTime? departure = live?.departRevised ?? pass.departAt;
  final AirportTime? arrival = live?.arriveRevised ?? pass.arriveAt;

  if (state == FlightLiveState.cancelled) {
    return const FlightJourneyStatus(
      lead: '',
      emphasis: 'Cancelled',
      detail: 'Check with the airline to rebook',
      tone: FlightStatusTone.warning,
    );
  }
  if (state == FlightLiveState.diverted) {
    return const FlightJourneyStatus(
      lead: '',
      emphasis: 'Diverted',
      detail: 'Check with the airline',
      tone: FlightStatusTone.warning,
    );
  }

  // ── Landed ──
  if (state != null && state.hasLanded) {
    final AirportTime? touchdown = live!.arriveActualAt ?? arrival;
    final int? late = flightArrivalDelayMinutes(pass);
    final String belt = live.baggageBelt.trim();
    return FlightJourneyStatus(
      lead: touchdown == null ? '' : 'Landed',
      emphasis: touchdown == null ? 'Landed' : FlightFormat.time(touchdown),
      detail: belt.isNotEmpty
          ? 'Bags on belt $belt'
          : (late != null && late >= kFlightDelayThresholdMinutes
                ? '$late min late'
                : ''),
      progress: 1,
      tone: FlightStatusTone.positive,
    );
  }
  final bool pastArrival = arrival != null && !now.isBefore(arrival.instant);
  if (pass.status == TicketStatus.expired || (live == null && pastArrival)) {
    // No feed said it landed, so this is the timetable speaking: "Arrived",
    // the word the bus and train faces use, not "Landed".
    return FlightJourneyStatus(
      lead: pass.arriveAt == null ? '' : 'Arrived',
      emphasis: pass.arriveAt == null
          ? 'Arrived'
          : FlightFormat.time(pass.arriveAt),
      detail: 'Journey complete',
      progress: 1,
    );
  }

  // ── In the air ──
  final bool airborne = state != null
      ? state.hasDeparted
      : departure != null &&
            !now.isBefore(departure.instant.add(_airborneGrace));
  if (airborne) {
    if (arrival == null) {
      return const FlightJourneyStatus(lead: '', emphasis: 'In the air');
    }
    final Duration left = arrival.instant.difference(now);
    final int? late = live == null ? null : flightArrivalDelayMinutes(pass);
    return FlightJourneyStatus(
      lead: left.inMinutes < 1 ? 'Landing' : 'Lands in',
      emphasis: left.inMinutes < 1 ? 'now' : formatTrainMinutes(left.inMinutes),
      detail: late != null && late >= kFlightDelayThresholdMinutes
          ? '$late min late'
          : '',
      progress: _progress(departure, arrival, now),
      tone: live == null ? FlightStatusTone.neutral : FlightStatusTone.live,
    );
  }

  final String gateLine = _gateLine(pass);

  // ── Boarding, only on the feed's word ──
  if (state == FlightLiveState.boarding) {
    final String gate = pass.resolvedGate;
    return FlightJourneyStatus(
      lead: '',
      emphasis: 'Boarding now',
      detail: gate.isEmpty ? '' : 'Gate $gate',
      tone: FlightStatusTone.live,
    );
  }

  if (departure == null) {
    return const FlightJourneyStatus(lead: '', emphasis: 'Scheduled');
  }

  // ── Delayed ──
  final int? delay = flightDepartureDelayMinutes(pass);
  if (delay != null && delay >= kFlightDelayThresholdMinutes) {
    return FlightJourneyStatus(
      lead: 'Delayed',
      emphasis: _minutes(delay),
      detail: _sentence(<String>[
        'Now departs ${FlightFormat.time(departure)}',
        if (pass.resolvedGate.isNotEmpty) 'Gate ${pass.resolvedGate}',
      ]),
      tone: FlightStatusTone.warning,
    );
  }

  // ── Countdown ──
  final Duration left = departure.instant.difference(now);
  final ({String lead, String emphasis}) line;
  if (left.inMinutes < 1) {
    line = (lead: 'Departs', emphasis: 'now');
  } else {
    // Both days in the airport's calendar, so "tomorrow" means tomorrow where
    // the flight leaves from.
    final DateTime here = now.toUtc().add(departure.offset);
    final DateTime there = departure.local;
    final int days = DateTime.utc(
      there.year,
      there.month,
      there.day,
    ).difference(DateTime.utc(here.year, here.month, here.day)).inDays;
    if (days == 0 || left.inHours < 12) {
      line = (lead: 'Departs in', emphasis: formatTrainMinutes(left.inMinutes));
    } else if (days == 1) {
      line = (lead: 'Departs', emphasis: 'tomorrow');
    } else {
      line = (lead: 'Departs in', emphasis: '$days days');
    }
  }

  final bool onTime =
      live != null &&
      delay != null &&
      delay.abs() < kFlightDelayThresholdMinutes;
  return FlightJourneyStatus(
    lead: line.lead,
    emphasis: line.emphasis,
    detail: _sentence(<String>[if (onTime) 'On time', gateLine]),
    tone: onTime ? FlightStatusTone.positive : FlightStatusTone.neutral,
  );
}

/// Minutes the departure is behind schedule, negative when early. Null when
/// there is no live revision to compare against, which is not the same as 0.
int? flightDepartureDelayMinutes(FlightPass pass) {
  final AirportTime? revised = pass.live?.departRevised;
  final AirportTime? scheduled = pass.departAt;
  if (revised == null || scheduled == null) return null;
  return revised.instant.difference(scheduled.instant).inMinutes;
}

/// Minutes the arrival is behind schedule, negative when early. Null when
/// unknown.
int? flightArrivalDelayMinutes(FlightPass pass) {
  final AirportTime? revised = pass.live?.arriveRevised;
  final AirportTime? scheduled = pass.arriveAt;
  if (revised == null || scheduled == null) return null;
  return revised.instant.difference(scheduled.instant).inMinutes;
}

/// "Gate B12, boarding 05:30", each half only when known.
String _gateLine(FlightPass pass) => _sentence(<String>[
  if (pass.resolvedGate.isNotEmpty) 'Gate ${pass.resolvedGate}',
  if (pass.boardingAt != null) 'Boarding ${FlightFormat.time(pass.boardingAt)}',
]);

String _minutes(int m) =>
    m < 60 ? '$m min' : FlightFormat.compact(Duration(minutes: m));

/// Joins clauses into one sentence: "On time, gate 12, boarding 05:30".
/// Later clauses lose their capital so the line reads as prose, not a list.
String _sentence(List<String> parts) {
  final List<String> kept = parts
      .map((String p) => p.trim())
      .where((String p) => p.isNotEmpty)
      .toList();
  return <String>[
    for (int i = 0; i < kept.length; i++)
      i == 0 ? kept[i] : kept[i][0].toLowerCase() + kept[i].substring(1),
  ].join(', ');
}

double _progress(AirportTime? departure, AirportTime arrival, DateTime now) {
  if (departure == null) return 0;
  final DateTime start = departure.instant;
  if (!arrival.instant.isAfter(start)) return 0;
  final double total = arrival.instant.difference(start).inSeconds.toDouble();
  final double done = now.difference(start).inSeconds.toDouble();
  return (done / total).clamp(0.0, 1.0).toDouble();
}

// ── Updates feed ────────────────────────────────────────────────────────────

/// What a feed row's icon shows.
enum FlightUpdateKind {
  found,
  takeoff,
  cruise,
  descent,
  landing,
  gate,
  delay,
  boarding,
  bags,
  alert,
}

/// One rendered row of the Updates feed.
@immutable
class FlightUpdateLine {
  const FlightUpdateLine({
    required this.title,
    required this.time,
    this.detail = '',
    this.kind = FlightUpdateKind.alert,
    this.tone = FlightStatusTone.neutral,
  });

  final String title;

  /// One quieter line under the title, or empty.
  final String detail;

  /// Clock time the change happened, in the zone of the airport it concerns.
  final String time;
  final FlightUpdateKind kind;
  final FlightStatusTone tone;
}

/// The sentence for [update]. Null for a type this build does not know, so a
/// newer server never puts a blank row in an older app's feed.
FlightUpdateLine? describeFlightUpdate(FlightPass pass, FlightUpdate update) {
  // Arrival-side events read in the destination's zone, everything else in
  // the origin's: "Landed 09:12" is the clock the traveller sees on landing.
  final bool arrivalSide = switch (update.type) {
    FlightUpdateType.landed ||
    FlightUpdateType.arrived ||
    FlightUpdateType.beltAssigned ||
    FlightUpdateType.descending => true,
    _ => false,
  };
  final Duration offset =
      (arrivalSide ? pass.arriveAt?.offset : pass.departAt?.offset) ??
      Duration.zero;
  final String time = FlightFormat.time(AirportTime(update.at, offset));

  final String from = update.from.trim();
  final String to = update.to.trim();
  final int? minutes = update.minutes;
  final FlightLive? live = pass.live;
  final String origin = pass.origin.displayCity;
  final String destination = pass.destination.displayCity;

  final (String, String, FlightUpdateKind, FlightStatusTone)?
  line = switch (update.type) {
    FlightUpdateType.aircraftFound when to.isNotEmpty => (
      'Aircraft found',
      (live?.aircraft ?? '').trim().isEmpty
          ? to
          : '$to, ${_article(live!.aircraft.trim())} ${live.aircraft.trim()}',
      FlightUpdateKind.found,
      FlightStatusTone.live,
    ),
    FlightUpdateType.gateAssigned when to.isNotEmpty => (
      'Gate $to assigned',
      '',
      FlightUpdateKind.gate,
      FlightStatusTone.neutral,
    ),
    FlightUpdateType.gateChange when to.isNotEmpty => (
      'Gate changed to $to',
      from.isEmpty ? '' : 'Was gate $from',
      FlightUpdateKind.gate,
      FlightStatusTone.warning,
    ),
    FlightUpdateType.terminalChange when to.isNotEmpty => (
      'Now departs from Terminal $to',
      from.isEmpty ? '' : 'Was Terminal $from',
      FlightUpdateKind.gate,
      FlightStatusTone.warning,
    ),
    FlightUpdateType.delay when minutes != null && minutes > 0 => (
      'Delayed ${_minutes(minutes)}',
      '',
      FlightUpdateKind.delay,
      FlightStatusTone.warning,
    ),
    FlightUpdateType.earlier when minutes != null && minutes > 0 => (
      'Departs ${_minutes(minutes)} earlier',
      '',
      FlightUpdateKind.delay,
      FlightStatusTone.neutral,
    ),
    FlightUpdateType.boarding => (
      'Boarding started',
      pass.resolvedGate.isEmpty ? '' : 'At gate ${pass.resolvedGate}',
      FlightUpdateKind.boarding,
      FlightStatusTone.live,
    ),
    // The live source is ADS-B, which sees wheels-up, not pushback.
    FlightUpdateType.departed => (
      'Took off from $origin',
      _takeoffDetail(pass),
      FlightUpdateKind.takeoff,
      (flightDepartureDelayMinutes(pass) ?? 0) >= kFlightDelayThresholdMinutes
          ? FlightStatusTone.warning
          : FlightStatusTone.live,
    ),
    FlightUpdateType.cruising => (
      int.tryParse(to) == null
          ? 'Reached cruise'
          : 'Reached ${_feet(int.parse(to))}',
      '',
      FlightUpdateKind.cruise,
      FlightStatusTone.neutral,
    ),
    FlightUpdateType.descending => (
      'Started descent',
      'Into $destination',
      FlightUpdateKind.descent,
      FlightStatusTone.neutral,
    ),
    FlightUpdateType.landed => (
      'Landed in $destination',
      _airborneDetail(pass),
      FlightUpdateKind.landing,
      FlightStatusTone.positive,
    ),
    FlightUpdateType.arrived => (
      'Arrived at the gate',
      '',
      FlightUpdateKind.landing,
      FlightStatusTone.positive,
    ),
    FlightUpdateType.beltAssigned when to.isNotEmpty => (
      'Bags on belt $to',
      '',
      FlightUpdateKind.bags,
      FlightStatusTone.neutral,
    ),
    FlightUpdateType.cancelled => (
      'Flight cancelled',
      'Check with the airline to rebook',
      FlightUpdateKind.alert,
      FlightStatusTone.warning,
    ),
    FlightUpdateType.diverted => (
      to.isEmpty ? 'Flight diverted' : 'Diverted to $to',
      '',
      FlightUpdateKind.alert,
      FlightStatusTone.warning,
    ),
    _ => null,
  };
  if (line == null) return null;
  return FlightUpdateLine(
    title: line.$1,
    detail: line.$2,
    time: time,
    kind: line.$3,
    tone: line.$4,
  );
}

/// "21 min after the scheduled 06:10", or empty when on time or unknown.
String _takeoffDetail(FlightPass pass) {
  final int? late = flightDepartureDelayMinutes(pass);
  if (late == null || late.abs() < kFlightDelayThresholdMinutes) return '';
  final String scheduled = FlightFormat.time(pass.departAt);
  return late > 0
      ? '${_minutes(late)} after the scheduled $scheduled'
      : '${_minutes(-late)} before the scheduled $scheduled';
}

/// "After 2h 21m in the air", when both actual times are known.
String _airborneDetail(FlightPass pass) {
  final AirportTime? off = pass.live?.departActualAt;
  final AirportTime? on = pass.live?.arriveActualAt;
  if (off == null || on == null) return '';
  return 'After ${FlightFormat.compact(on.instant.difference(off.instant))} in the air';
}

/// "36,000 ft".
String _feet(int ft) {
  final String digits = ft.toString();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return '$out ft';
}

String _article(String noun) =>
    RegExp(r'^[AEIOU]', caseSensitive: false).hasMatch(noun) ? 'an' : 'a';

/// The feed, newest first, with unrenderable rows dropped.
List<FlightUpdateLine> flightUpdateFeed(FlightPass pass) {
  final List<FlightUpdate> sorted = <FlightUpdate>[...pass.updates]
    ..sort((FlightUpdate a, FlightUpdate b) => b.at.compareTo(a.at));
  return <FlightUpdateLine>[
    for (final FlightUpdate u in sorted) ?describeFlightUpdate(pass, u),
  ];
}

// ── Situation line ──────────────────────────────────────────────────────────

/// The one plain sentence under the Updates headline: what is happening and
/// what to expect, from facts only. "Took off 21 min late. Cruising at
/// 36,000 ft, 740 km to go."
String flightSituationLine(FlightPass pass, DateTime now) {
  final FlightLive? live = pass.live;
  final FlightLiveState? state = live?.state;
  if (state == FlightLiveState.cancelled || state == FlightLiveState.diverted) {
    return resolveFlightJourneyStatus(pass, now).detail;
  }

  if (state != null && state.hasLanded) {
    final AirportTime? off = live!.departActualAt;
    final AirportTime? on = live.arriveActualAt;
    if (off != null && on != null) {
      return 'Landed in ${pass.destination.displayCity} after '
          '${FlightFormat.compact(on.instant.difference(off.instant))} '
          'in the air.';
    }
    return 'Landed in ${pass.destination.displayCity}.';
  }

  if (state != null && state.hasDeparted) {
    // The phase from the newest cruise or descent report; the numbers
    // (altitude, distance, lateness) already sit in the chips and rows.
    final FlightUpdate? phase =
        (pass.updates
                .where(
                  (FlightUpdate u) =>
                      u.type == FlightUpdateType.cruising ||
                      u.type == FlightUpdateType.descending,
                )
                .toList()
              ..sort((FlightUpdate a, FlightUpdate b) => b.at.compareTo(a.at)))
            .firstOrNull;
    if (phase?.type == FlightUpdateType.descending) {
      return 'Descending into ${pass.destination.displayCity}.';
    }
    final int? ft = int.tryParse(phase?.to ?? '') ?? live!.altitudeFt;
    if (phase != null && ft != null && ft > 0) {
      return 'Cruising at ${_feet(ft)}.';
    }
    return 'In the air from ${pass.origin.displayCity}.';
  }

  final bool before =
      pass.departAt != null && now.isBefore(pass.departAt!.instant);
  if (live == null) {
    return before
        ? 'Times are from your pass. Live tracking starts 30 minutes '
              'before departure.'
        : 'This flight is not being tracked, so these are the times on '
              'your pass.';
  }
  final String reg = live.registration.trim();
  final String type = live.aircraft.trim();
  final String plane = reg.isEmpty
      ? ''
      : type.isEmpty
      ? 'Flying on $reg.'
      : 'Flying on $reg, ${_article(type)} $type.';
  final String boarding = pass.boardingAt == null
      ? ''
      : pass.resolvedGate.isEmpty
      ? 'Boarding ${FlightFormat.time(pass.boardingAt)}.'
      : 'Boarding ${FlightFormat.time(pass.boardingAt)} at gate '
            '${pass.resolvedGate}.';
  final String out = <String>[
    plane,
    boarding,
  ].where((String s) => s.isNotEmpty).join(' ');
  return out.isEmpty ? 'Tracking this flight.' : out;
}
