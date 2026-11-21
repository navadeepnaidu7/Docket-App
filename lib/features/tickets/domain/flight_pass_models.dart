import 'airline_brands.dart';
import 'flight_geo.dart';
import 'pass_code.dart';
import 'pass_status.dart';

/// An instant plus the UTC offset of the airport it was printed at.
///
/// Flight times are read in the airport's zone, never the phone's: a 06:10
/// departure from DEL is 06:10 on the pass even when the phone is in London.
/// `DateTime.parse` keeps the instant but throws the offset away, so this keeps
/// both. [local] is a UTC-flagged [DateTime] whose fields read as the airport's
/// wall clock; it is for display only, never for comparing against `now`.
class AirportTime {
  const AirportTime(this.instant, this.offset);

  /// The moment, in UTC.
  final DateTime instant;

  /// The airport's offset from UTC when the string was written.
  final Duration offset;

  /// Wall-clock fields at the airport. Display only.
  DateTime get local => instant.add(offset);

  static final RegExp _offset = RegExp(r'([+-])(\d{2}):?(\d{2})$');

  /// Parses RFC3339. A trailing `Z` is offset zero; a string with no zone at
  /// all is read as airport-local wall clock, since that is how extracted
  /// tickets print it.
  static AirportTime? tryParse(String? raw) {
    final String s = raw?.trim() ?? '';
    if (s.isEmpty) return null;
    final DateTime? parsed = DateTime.tryParse(s);
    if (parsed == null) return null;
    if (s.endsWith('Z') || s.endsWith('z')) {
      return AirportTime(parsed.toUtc(), Duration.zero);
    }
    final RegExpMatch? m = _offset.firstMatch(s);
    if (m == null) {
      // No zone: the fields are the airport's wall clock, and the phone's zone
      // is the best guess at the instant. That guess only skews countdowns for
      // someone abroad; the printed time stays the airport's either way.
      return AirportTime(parsed.toUtc(), parsed.timeZoneOffset);
    }
    final int sign = m.group(1) == '-' ? -1 : 1;
    final Duration offset =
        Duration(
          hours: int.parse(m.group(2)!),
          minutes: int.parse(m.group(3)!),
        ) *
        sign;
    return AirportTime(parsed.toUtc(), offset);
  }
}

/// One end of the flight.
class FlightAirport {
  const FlightAirport({
    required this.code,
    this.city = '',
    this.airport = '',
    this.terminal = '',
    this.location,
  });

  /// IATA airport code, upper case. The only required part.
  final String code;
  final String city;
  final String airport;
  final String terminal;

  /// Coordinates the server sent, when it sent them.
  final GeoPoint? location;

  /// City when known, else the code, so a header line never renders blank.
  String get displayCity => city.trim().isNotEmpty ? city.trim() : code;

  /// The server's coordinates, else the bundled table's. Null means no map.
  GeoPoint? get resolvedLocation =>
      location ?? FlightAirportCoordinates.of(code);

  factory FlightAirport.fromJson(Object? raw) {
    if (raw is String) return FlightAirport(code: raw.trim().toUpperCase());
    if (raw is! Map) return const FlightAirport(code: '');
    final Map<String, dynamic> json = Map<String, dynamic>.from(raw);
    return FlightAirport(
      code: (json['code']?.toString() ?? '').trim().toUpperCase(),
      city: json['city']?.toString() ?? '',
      airport: json['airport']?.toString() ?? '',
      terminal: json['terminal']?.toString() ?? '',
      location: _geo(json['lat'], json['lon']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    if (city.isNotEmpty) 'city': city,
    if (airport.isNotEmpty) 'airport': airport,
    if (terminal.isNotEmpty) 'terminal': terminal,
    if (location != null) 'lat': location!.lat,
    if (location != null) 'lon': location!.lon,
  };
}

class FlightPassenger {
  const FlightPassenger({required this.name, this.seat = ''});

  final String name;
  final String seat;

  factory FlightPassenger.fromJson(Map<String, dynamic> json) =>
      FlightPassenger(
        name: json['name']?.toString() ?? '',
        seat: json['seat']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    if (seat.isNotEmpty) 'seat': seat,
  };
}

/// Where the flight is, as the status provider last reported it.
enum FlightLiveState {
  scheduled,
  boarding,
  departed,
  enRoute,
  landed,
  arrived,
  cancelled,
  diverted;

  static FlightLiveState fromJson(Object? raw) {
    final String s = raw?.toString() ?? '';
    for (final FlightLiveState v in values) {
      if (v.name.toLowerCase() == s.toLowerCase()) return v;
    }
    return FlightLiveState.scheduled;
  }

  /// Off the ground or past it.
  bool get hasDeparted =>
      this == departed || this == enRoute || this == landed || this == arrived;

  bool get hasLanded => this == landed || this == arrived;
}

/// Live status for a flight. Absent entirely when the server has no feed,
/// which is a different answer from "on time": the face then prints the
/// timetable and claims nothing. Every field here is optional for the same
/// reason; null means "not reported", never "unchanged".
class FlightLive {
  const FlightLive({
    this.state = FlightLiveState.scheduled,
    this.departEstimatedAt,
    this.departActualAt,
    this.arriveEstimatedAt,
    this.arriveActualAt,
    this.departGate = '',
    this.departTerminal = '',
    this.arriveTerminal = '',
    this.baggageBelt = '',
    this.aircraft = '',
    this.registration = '',
    this.position,
    this.altitudeFt,
    this.groundSpeedKt,
    this.aircraftPhotoUrl = '',
    this.aircraftPhotoCredit = '',
    this.updatedAt,
  });

  final FlightLiveState state;
  final AirportTime? departEstimatedAt;
  final AirportTime? departActualAt;
  final AirportTime? arriveEstimatedAt;
  final AirportTime? arriveActualAt;
  final String departGate;
  final String departTerminal;
  final String arriveTerminal;
  final String baggageBelt;
  final String aircraft;
  final String registration;

  /// Where the aircraft last reported itself (ADS-B). Null before it is found
  /// and after tracking ends; the map draws no plane without it.
  final GeoPoint? position;
  final int? altitudeFt;
  final int? groundSpeedKt;

  /// A photo of this airline's aircraft of this type, and who took it. Often a
  /// sister aircraft rather than this registration; the credit says which.
  final String aircraftPhotoUrl;
  final String aircraftPhotoCredit;

  final DateTime? updatedAt;

  /// Best known departure: actual, then estimated. Null when neither came.
  AirportTime? get departRevised => departActualAt ?? departEstimatedAt;

  /// Best known arrival: actual, then estimated.
  AirportTime? get arriveRevised => arriveActualAt ?? arriveEstimatedAt;

  factory FlightLive.fromJson(Map<String, dynamic> json) => FlightLive(
    state: FlightLiveState.fromJson(json['state']),
    departEstimatedAt: AirportTime.tryParse(
      json['departEstimatedAt']?.toString(),
    ),
    departActualAt: AirportTime.tryParse(json['departActualAt']?.toString()),
    arriveEstimatedAt: AirportTime.tryParse(
      json['arriveEstimatedAt']?.toString(),
    ),
    arriveActualAt: AirportTime.tryParse(json['arriveActualAt']?.toString()),
    departGate: json['departGate']?.toString() ?? '',
    departTerminal: json['departTerminal']?.toString() ?? '',
    arriveTerminal: json['arriveTerminal']?.toString() ?? '',
    baggageBelt: json['baggageBelt']?.toString() ?? '',
    aircraft: json['aircraft']?.toString() ?? '',
    registration: json['registration']?.toString() ?? '',
    position: _geo(json['lat'], json['lon']),
    altitudeFt: _int(json['altitudeFt']),
    groundSpeedKt: _int(json['groundSpeedKt']),
    aircraftPhotoUrl: json['aircraftPhotoUrl']?.toString() ?? '',
    aircraftPhotoCredit: json['aircraftPhotoCredit']?.toString() ?? '',
    updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'state': state.name,
    if (departEstimatedAt != null)
      'departEstimatedAt': _rfc3339(departEstimatedAt!),
    if (departActualAt != null) 'departActualAt': _rfc3339(departActualAt!),
    if (arriveEstimatedAt != null)
      'arriveEstimatedAt': _rfc3339(arriveEstimatedAt!),
    if (arriveActualAt != null) 'arriveActualAt': _rfc3339(arriveActualAt!),
    if (departGate.isNotEmpty) 'departGate': departGate,
    if (departTerminal.isNotEmpty) 'departTerminal': departTerminal,
    if (arriveTerminal.isNotEmpty) 'arriveTerminal': arriveTerminal,
    if (baggageBelt.isNotEmpty) 'baggageBelt': baggageBelt,
    if (aircraft.isNotEmpty) 'aircraft': aircraft,
    if (registration.isNotEmpty) 'registration': registration,
    if (position != null) 'lat': position!.lat,
    if (position != null) 'lon': position!.lon,
    if (altitudeFt != null) 'altitudeFt': altitudeFt,
    if (groundSpeedKt != null) 'groundSpeedKt': groundSpeedKt,
    if (aircraftPhotoUrl.isNotEmpty) 'aircraftPhotoUrl': aircraftPhotoUrl,
    if (aircraftPhotoCredit.isNotEmpty)
      'aircraftPhotoCredit': aircraftPhotoCredit,
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
  };
}

/// Kind of change in the Updates feed. The server sends facts; the client
/// writes the sentence.
enum FlightUpdateType {
  gateAssigned,
  gateChange,
  terminalChange,
  delay,
  earlier,
  boarding,
  departed,
  landed,
  arrived,
  beltAssigned,
  cancelled,
  diverted,

  /// The tracker matched an aircraft to the flight; `to` is its registration.
  aircraftFound,

  /// Reached cruise; `to` is the altitude in feet.
  cruising,
  descending,
  unknown;

  static FlightUpdateType fromJson(Object? raw) {
    final String s = raw?.toString() ?? '';
    for (final FlightUpdateType v in values) {
      if (v.name.toLowerCase() == s.toLowerCase()) return v;
    }
    return FlightUpdateType.unknown;
  }
}

/// One entry in the Updates feed: something that changed, and when.
class FlightUpdate {
  const FlightUpdate({
    required this.at,
    required this.type,
    this.from = '',
    this.to = '',
    this.minutes,
  });

  final DateTime at;
  final FlightUpdateType type;

  /// Previous and new values for a change (gate, terminal, belt).
  final String from;
  final String to;

  /// Size of a delay or an earlier departure, in minutes.
  final int? minutes;

  static FlightUpdate? tryFromJson(Map<String, dynamic> json) {
    final DateTime? at = DateTime.tryParse(json['at']?.toString() ?? '');
    if (at == null) return null;
    final Object? rawMinutes = json['minutes'];
    return FlightUpdate(
      at: at.toUtc(),
      type: FlightUpdateType.fromJson(json['type']),
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      minutes: rawMinutes is num
          ? rawMinutes.round()
          : int.tryParse(rawMinutes?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'at': at.toUtc().toIso8601String(),
    'type': type.name,
    if (from.isNotEmpty) 'from': from,
    if (to.isNotEmpty) 'to': to,
    if (minutes != null) 'minutes': minutes,
  };
}

/// Flight boarding pass. Spec in `docs/features/flight-pass.md`.
class FlightPass {
  const FlightPass({
    required this.id,
    required this.airline,
    required this.flightNumber,
    required this.origin,
    required this.destination,
    required this.status,
    this.airlineCode = '',
    this.bookingRef = '',
    this.departAt,
    this.arriveAt,
    this.boardingAt,
    this.gate = '',
    this.seat = '',
    this.cabin = '',
    this.boardingGroup = '',
    this.sequence = '',
    this.passengers = const <FlightPassenger>[],
    this.live,
    this.updates = const <FlightUpdate>[],
    this.codePayload,
    this.codePayloadBase64,
    this.codeFormat,
  });

  final String id;
  final String airline;

  /// IATA designator, "6E". Empty falls back to the flight number's prefix.
  final String airlineCode;

  /// Display flight number with its carrier code, "6E 2134".
  final String flightNumber;

  /// The airline's booking reference (PNR).
  final String bookingRef;

  final FlightAirport origin;
  final FlightAirport destination;
  final TicketStatus status;

  /// Scheduled times. Revisions live on [live], never here.
  final AirportTime? departAt;
  final AirportTime? arriveAt;
  final AirportTime? boardingAt;

  /// Gate as printed on the pass. [resolvedGate] prefers the live one.
  final String gate;
  final String seat;
  final String cabin;
  final String boardingGroup;
  final String sequence;
  final List<FlightPassenger> passengers;

  /// Null when the server has no live feed for this flight.
  final FlightLive? live;

  /// Oldest first, as the server sends them. The feed reverses for display.
  final List<FlightUpdate> updates;

  final String? codePayload;
  final String? codePayloadBase64;
  final String? codeFormat;

  PassCode? get passCode => PassCode.parse(
    payload: codePayload,
    payloadBase64: codePayloadBase64,
    format: codeFormat,
  );

  /// Designator from [airlineCode], else the flight number's leading two
  /// characters, which is where every IATA flight number carries it.
  String get resolvedAirlineCode {
    if (airlineCode.trim().isNotEmpty) return airlineCode.trim().toUpperCase();
    final String n = flightNumber.replaceAll(' ', '').toUpperCase();
    return n.length >= 2 ? n.substring(0, 2) : '';
  }

  /// The airline's colours, or null for a carrier the table does not know.
  AirlineBrand? get brand => AirlineBrand.of(resolvedAirlineCode);

  /// Live gate when reported, else the printed one. Empty means unknown, and
  /// surfaces render nothing rather than "TBA".
  String get resolvedGate {
    final String liveGate = live?.departGate.trim() ?? '';
    return liveGate.isNotEmpty ? liveGate : gate.trim();
  }

  String get resolvedDepartTerminal {
    final String t = live?.departTerminal.trim() ?? '';
    return t.isNotEmpty ? t : origin.terminal.trim();
  }

  String get resolvedArriveTerminal {
    final String t = live?.arriveTerminal.trim() ?? '';
    return t.isNotEmpty ? t : destination.terminal.trim();
  }

  String get routeLabel => '${origin.code} → ${destination.code}';

  factory FlightPass.fromJson(Map<String, dynamic> json) {
    final List<dynamic> paxRaw = json['passengers'] is List
        ? json['passengers'] as List
        : const [];
    final List<dynamic> updatesRaw = json['updates'] is List
        ? json['updates'] as List
        : const [];
    final Object? liveRaw = json['live'];
    return FlightPass(
      id: json['id']?.toString() ?? '',
      airline: json['airline']?.toString() ?? '',
      airlineCode: json['airlineCode']?.toString() ?? '',
      flightNumber: json['flightNumber']?.toString() ?? '',
      bookingRef: json['bookingRef']?.toString() ?? '',
      origin: FlightAirport.fromJson(json['origin']),
      destination: FlightAirport.fromJson(json['destination']),
      status: TicketStatus.fromJson(json['status']),
      departAt: AirportTime.tryParse(json['departAt']?.toString()),
      arriveAt: AirportTime.tryParse(json['arriveAt']?.toString()),
      boardingAt: AirportTime.tryParse(json['boardingAt']?.toString()),
      gate: json['gate']?.toString() ?? '',
      seat: json['seat']?.toString() ?? '',
      cabin: json['cabin']?.toString() ?? '',
      boardingGroup: json['boardingGroup']?.toString() ?? '',
      sequence: json['sequence']?.toString() ?? '',
      passengers: paxRaw
          .whereType<Map>()
          .map(
            (Map m) => FlightPassenger.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList(),
      live: liveRaw is Map
          ? FlightLive.fromJson(Map<String, dynamic>.from(liveRaw))
          : null,
      updates: updatesRaw
          .whereType<Map>()
          .map(
            (Map m) => FlightUpdate.tryFromJson(Map<String, dynamic>.from(m)),
          )
          .whereType<FlightUpdate>()
          .toList(),
      codePayload: json['codePayload']?.toString(),
      codePayloadBase64: json['codePayloadBase64']?.toString(),
      codeFormat: json['codeFormat']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'airline': airline,
    if (airlineCode.isNotEmpty) 'airlineCode': airlineCode,
    'flightNumber': flightNumber,
    if (bookingRef.isNotEmpty) 'bookingRef': bookingRef,
    'origin': origin.toJson(),
    'destination': destination.toJson(),
    'status': status.toJson(),
    if (departAt != null) 'departAt': _rfc3339(departAt!),
    if (arriveAt != null) 'arriveAt': _rfc3339(arriveAt!),
    if (boardingAt != null) 'boardingAt': _rfc3339(boardingAt!),
    if (gate.isNotEmpty) 'gate': gate,
    if (seat.isNotEmpty) 'seat': seat,
    if (cabin.isNotEmpty) 'cabin': cabin,
    if (boardingGroup.isNotEmpty) 'boardingGroup': boardingGroup,
    if (sequence.isNotEmpty) 'sequence': sequence,
    if (passengers.isNotEmpty)
      'passengers': passengers.map((FlightPassenger p) => p.toJson()).toList(),
    if (live != null) 'live': live!.toJson(),
    if (updates.isNotEmpty)
      'updates': updates.map((FlightUpdate u) => u.toJson()).toList(),
    if (codePayload != null) 'codePayload': codePayload,
    if (codePayloadBase64 != null) 'codePayloadBase64': codePayloadBase64,
    if (codeFormat != null) 'codeFormat': codeFormat,
  };
}

/// RFC3339 with the airport's offset, so a round trip keeps the zone.
String _rfc3339(AirportTime t) {
  final DateTime l = t.local;
  String two(int v) => v.toString().padLeft(2, '0');
  final int mins = t.offset.inMinutes;
  final String zone = mins == 0
      ? 'Z'
      : '${mins < 0 ? '-' : '+'}${two(mins.abs() ~/ 60)}:${two(mins.abs() % 60)}';
  return '${l.year.toString().padLeft(4, '0')}-${two(l.month)}-${two(l.day)}'
      'T${two(l.hour)}:${two(l.minute)}:${two(l.second)}$zone';
}

GeoPoint? _geo(Object? lat, Object? lon) {
  final double? a = lat is num
      ? lat.toDouble()
      : double.tryParse('${lat ?? ''}');
  final double? b = lon is num
      ? lon.toDouble()
      : double.tryParse('${lon ?? ''}');
  if (a == null || b == null || a.abs() > 90 || b.abs() > 180) return null;
  return GeoPoint(a, b);
}

int? _int(Object? raw) =>
    raw is num ? raw.round() : int.tryParse('${raw ?? ''}');
