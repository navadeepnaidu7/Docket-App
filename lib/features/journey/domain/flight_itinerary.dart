/// The shape a flight carries, independent of where it came from.
///
/// Flights are **not** a `PassKind` in this version. `PassKind` is
/// `{train, movie, bus}` and adding a fourth member touches roughly ten
/// exhaustive switches across the tickets feature — scope that belongs to a
/// flight *pass*, not to Journey.
///
/// So Journey defines only the itinerary, and mock fixtures build these
/// directly. When a real `FlightPassItem` lands it exposes one of these, the
/// sealed switch in `buildJourneyIndex` stops compiling, and the single new
/// case reuses the same conversion the mocks already go through. Nothing
/// downstream of [JourneyEvent] changes, because nothing downstream knows what
/// a flight is.
///
/// See `docs/features/journey.md`, "Flights are mocked in v1".
final class FlightItinerary {
  const FlightItinerary({
    required this.id,
    required this.airline,
    required this.flightNumber,
    required this.fromIata,
    required this.toIata,
    required this.fromCity,
    required this.toCity,
    this.departAt,
    this.arriveAt,
  });

  final String id;
  final String airline;
  final String flightNumber;

  /// IATA airport codes, e.g. `BLR`, `DXB`.
  final String fromIata;
  final String toIata;

  /// Display city names, used as the lookup fallback when a code is unknown.
  final String fromCity;
  final String toCity;

  final DateTime? departAt;
  final DateTime? arriveAt;

  String get routeLabel => '$fromCity to $toCity';

  String get flightLabel => '$airline $flightNumber';
}
