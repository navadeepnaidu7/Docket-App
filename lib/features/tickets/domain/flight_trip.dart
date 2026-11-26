import 'package:flutter/foundation.dart';

import 'flight_format.dart';
import 'flight_pass_models.dart';

/// One flight of a trip, as the server lists it on every leg's `trip`.
@immutable
class FlightTripLeg {
  const FlightTripLeg({
    required this.id,
    required this.flightNumber,
    required this.from,
    required this.to,
    this.airlineCode = '',
    this.departAt,
    this.arriveAt,
  });

  /// The pass id, so a leg can open its own pass.
  final String id;
  final String flightNumber;
  final String airlineCode;
  final String from;
  final String to;
  final AirportTime? departAt;
  final AirportTime? arriveAt;

  static FlightTripLeg? tryFromJson(Map<String, dynamic> json) {
    final String id = json['id']?.toString() ?? '';
    final String from = (json['from']?.toString() ?? '').trim().toUpperCase();
    final String to = (json['to']?.toString() ?? '').trim().toUpperCase();
    if (id.isEmpty || from.isEmpty || to.isEmpty) return null;
    return FlightTripLeg(
      id: id,
      flightNumber: json['flightNumber']?.toString() ?? '',
      airlineCode: json['airlineCode']?.toString() ?? '',
      from: from,
      to: to,
      departAt: AirportTime.tryParse(json['departAt']?.toString()),
      arriveAt: AirportTime.tryParse(json['arriveAt']?.toString()),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'flightNumber': flightNumber,
    if (airlineCode.isNotEmpty) 'airlineCode': airlineCode,
    'from': from,
    'to': to,
    if (departAt != null) 'departAt': departAt!.toRfc3339(),
    if (arriveAt != null) 'arriveAt': arriveAt!.toRfc3339(),
  };
}

/// Every flight booked with a pass, in departure order, and which one the pass
/// is. The server sends it only when there are at least two; see
/// `docket_server/docs/flight_ingest.md`.
@immutable
class FlightTrip {
  const FlightTrip({required this.id, required this.index, required this.legs});

  final String id;
  final int index;
  final List<FlightTripLeg> legs;

  FlightTripLeg get current => legs[index];

  /// Null for anything that is not a usable trip: one leg, or an index that
  /// points nowhere.
  static FlightTrip? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final Map<String, dynamic> json = Map<String, dynamic>.from(raw);
    final Object? legsRaw = json['legs'];
    if (legsRaw is! List) return null;
    final List<FlightTripLeg> legs = legsRaw
        .whereType<Map>()
        .map((Map m) => FlightTripLeg.tryFromJson(Map<String, dynamic>.from(m)))
        .whereType<FlightTripLeg>()
        .toList(growable: false);
    final int? index = switch (json['index']) {
      final int i => i,
      final num n => n.toInt(),
      _ => null,
    };
    if (legs.length < 2 || index == null || index < 0 || index >= legs.length) {
      return null;
    }
    return FlightTrip(
      id: json['id']?.toString() ?? '',
      index: index,
      legs: List<FlightTripLeg>.unmodifiable(legs),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'index': index,
    'legs': legs.map((FlightTripLeg l) => l.toJson()).toList(),
  };
}

/// What part of the trip a run of connected flights is.
enum FlightTripPart {
  /// The first journey of a trip with more than one.
  outbound,

  /// The last journey, when it ends where the trip began.
  inbound,

  /// Any other journey: multi-city, or an open jaw.
  onward,

  /// The only journey: a connection and nothing else.
  single,
}

/// A run of flights flown one after another, connecting at each airport.
@immutable
class FlightTripJourney {
  const FlightTripJourney({required this.part, required this.legs});

  final FlightTripPart part;
  final List<FlightTripLeg> legs;

  String get from => legs.first.from;
  String get to => legs.last.to;

  /// "Outbound", "Return", "Onward", or "" for a lone connection.
  String get title => switch (part) {
    FlightTripPart.outbound => 'Outbound',
    FlightTripPart.inbound => 'Return',
    FlightTripPart.onward => 'Onward',
    FlightTripPart.single => '',
  };
}

/// The longest wait that is still a connection. Past it the traveller is
/// staying somewhere, and the next flight starts a new journey. The same
/// line IATA draws between a connection and a stopover on international
/// tickets.
const Duration maxConnection = Duration(hours: 24);

/// Splits a trip into journeys and names each. Pure; the face and the detail
/// screen both read the trip through this, so they cannot disagree.
List<FlightTripJourney> flightTripJourneys(FlightTrip trip) {
  final List<List<FlightTripLeg>> runs = <List<FlightTripLeg>>[];
  for (final FlightTripLeg leg in trip.legs) {
    if (runs.isNotEmpty && connects(runs.last.last, leg)) {
      runs.last.add(leg);
    } else {
      runs.add(<FlightTripLeg>[leg]);
    }
  }
  final String home = trip.legs.first.from;
  return <FlightTripJourney>[
    for (int i = 0; i < runs.length; i++)
      FlightTripJourney(
        part: runs.length == 1
            ? FlightTripPart.single
            : i == 0
            ? FlightTripPart.outbound
            : i == runs.length - 1 && runs[i].last.to == home
            ? FlightTripPart.inbound
            : FlightTripPart.onward,
        legs: List<FlightTripLeg>.unmodifiable(runs[i]),
      ),
  ];
}

/// Whether [next] is a connection out of the airport [prev] lands at.
bool connects(FlightTripLeg prev, FlightTripLeg next) {
  if (prev.to != next.from) return false;
  final Duration? wait = layover(prev, next);
  return wait != null && !wait.isNegative && wait <= maxConnection;
}

/// Time on the ground between [prev] landing and [next] leaving. Falls back to
/// departure-to-departure when the arrival is unknown, which overstates the
/// wait rather than inventing a landing time; returns null with neither.
Duration? layover(FlightTripLeg prev, FlightTripLeg next) {
  final AirportTime? left = next.departAt;
  final AirportTime? landed = prev.arriveAt ?? prev.departAt;
  if (left == null || landed == null) return null;
  return left.instant.difference(landed.instant);
}

/// Where one pass sits in its trip, in words the face can print.
@immutable
class FlightTripPlace {
  const FlightTripPlace({
    required this.journey,
    required this.leg,
    this.next,
    this.waitAfter,
  });

  final FlightTripJourney journey;

  /// 0-based within [journey].
  final int leg;

  /// The connecting flight after this one, if any.
  final FlightTripLeg? next;
  final Duration? waitAfter;

  bool get isConnection => journey.legs.length > 1;

  /// Short tag for the face: "Return", "Leg 1 of 2", "Outbound · 2 of 2".
  String get tag {
    final String legs = '${leg + 1} of ${journey.legs.length}';
    final String title = journey.title;
    if (!isConnection) return title;
    if (title.isEmpty) return 'Leg $legs';
    return '$title · $legs';
  }

  /// "Then 6E 512 to BOM · 1h 35m in DEL", or "" when nothing follows.
  String get onwardLine {
    final FlightTripLeg? n = next;
    if (n == null) return '';
    final Duration? w = waitAfter;
    final String wait = w == null || w.inMinutes <= 0
        ? ''
        : ' · ${FlightFormat.compact(w)} in ${n.from}';
    return 'Then ${n.flightNumber} to ${n.to}$wait';
  }
}

/// [trip]'s current pass, placed. Null only for a malformed trip, which
/// [FlightTrip.tryFromJson] already refuses.
FlightTripPlace? placeInTrip(FlightTrip trip) {
  final FlightTripLeg current = trip.current;
  for (final FlightTripJourney j in flightTripJourneys(trip)) {
    final int at = j.legs.indexWhere((FlightTripLeg l) => l.id == current.id);
    if (at < 0) continue;
    final FlightTripLeg? next = at + 1 < j.legs.length ? j.legs[at + 1] : null;
    return FlightTripPlace(
      journey: j,
      leg: at,
      next: next,
      waitAfter: next == null ? null : layover(j.legs[at], next),
    );
  }
  return null;
}
