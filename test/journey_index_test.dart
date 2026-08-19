import 'package:docket/features/journey/domain/flight_itinerary.dart';
import 'package:docket/features/journey/domain/geo_point.dart';
import 'package:docket/features/journey/domain/journey_event.dart';
import 'package:docket/features/journey/domain/journey_index.dart';
import 'package:docket/features/journey/domain/place.dart';
import 'package:docket/features/journey/domain/place_resolver.dart';
import 'package:docket/features/tickets/domain/movie_pass_models.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/ticket_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Resolves only the places it is told about, so every degradation path in
/// [buildJourneyIndex] can be provoked deliberately rather than waited for.
final class _FakePlaceResolver implements PlaceResolver {
  _FakePlaceResolver(this.known);

  /// Keyed by code or by normalised name.
  final Map<String, Place> known;

  @override
  Place? lookup(PlaceQuery query) {
    final String? code = query.code;
    if (code != null && known.containsKey(code)) return known[code];
    for (final String candidate in query.textCandidates) {
      final Place? hit = known[candidate];
      if (hit != null) return hit;
    }
    return null;
  }

  @override
  Future<void> ensureReady() async {}
}

Place _place(String id, {String? cityId, double lat = 12.0, double lng = 77.0}) =>
    Place(
      id: id,
      name: id,
      kind: cityId == null ? PlaceKind.city : PlaceKind.station,
      point: GeoPoint(lat, lng),
      cityId: cityId,
      countryCode: 'IN',
    );

TrainPass _train({
  String id = 't1',
  String fromCode = 'AAA',
  String toCode = 'BBB',
  String date = '10 Jan 2024',
  List<TicketHalt> halts = const <TicketHalt>[],
}) {
  return TrainPass(
    id: id,
    operator: 'IRCTC',
    trainNumber: '12932',
    trainName: 'Test Express',
    fromCode: fromCode,
    fromName: fromCode,
    toCode: toCode,
    toName: toCode,
    departTime: '07:10 AM',
    arriveTime: '02:40 PM',
    date: date,
    arrivalDate: date,
    duration: '7h 30m',
    ticketClass: 'AC 2 Tier',
    passengers: const <TicketPassenger>[
      TicketPassenger(name: 'A', coach: 'B2', seat: '32', berth: 'Lower'),
    ],
    pnr: '1234567890',
    bookingId: 'B',
    status: TicketStatus.expired,
    halts: halts,
  );
}

TicketHalt _halt(String station) => TicketHalt(
      time: '11:40',
      station: station,
      dateLabel: 'Sun, 20 Jul',
      state: HaltState.departed,
    );

MoviePass _movie({
  String id = 'm1',
  String cinemaName = 'Test Cinema',
  String cinemaAddress = 'Somewhere, Nowhere',
  String showDate = '12 Apr 2025',
}) {
  return MoviePass(
    id: id,
    brand: MoviePassBrand.universal,
    movieTitle: 'A Film',
    movieSubtitle: '',
    cinemaName: cinemaName,
    cinemaAddress: cinemaAddress,
    screen: 'Screen 5',
    showDate: showDate,
    showTime: '7:15 PM',
    format: '2D',
    language: 'English',
    seats: const <MovieSeat>[MovieSeat(row: 'H', number: '12')],
    bookingId: 'B',
    orderId: 'O',
    status: TicketStatus.expired,
  );
}

void main() {
  group('route degradation', () {
    test('a route with both ends resolved draws as a route', () {
      final index = buildJourneyIndex(
        passes: <WalletPassItem>[TrainPassItem(_train())],
        resolver: _FakePlaceResolver(<String, Place>{
          'AAA': _place('stn:AAA', cityId: 'city:a'),
          'BBB': _place('stn:BBB', cityId: 'city:b', lng: 78.0),
        }),
      );

      expect(index.placed.single.isRoute, isTrue);
      expect(index.placed.single.placedStops.length, 2);
    });

    test('a route with one unresolved end degrades to a point', () {
      final index = buildJourneyIndex(
        passes: <WalletPassItem>[TrainPassItem(_train())],
        resolver: _FakePlaceResolver(<String, Place>{
          'AAA': _place('stn:AAA', cityId: 'city:a'),
        }),
      );

      final JourneyEvent event = index.placed.single;
      expect(event.isPlottable, isTrue);
      expect(event.isRoute, isFalse, reason: 'one end resolved, so it is a point');
      expect(event.anchorPlace!.id, 'stn:AAA');
    });

    test('a memory nothing resolves for is kept, not dropped', () {
      final index = buildJourneyIndex(
        passes: <WalletPassItem>[TrainPassItem(_train()), MoviePassItem(_movie())],
        resolver: _FakePlaceResolver(const <String, Place>{}),
      );

      expect(index.placed, isEmpty);
      expect(index.unplaced.length, 2);
      expect(index.events.length, 2, reason: 'still counted in totals');
    });

    test('an unresolved halt is skipped and the arc bridges past it', () {
      final index = buildJourneyIndex(
        passes: <WalletPassItem>[
          TrainPassItem(_train(halts: <TicketHalt>[
            _halt('Known Halt (KKK)'),
            _halt('Unknown Halt (ZZZ)'),
          ])),
        ],
        resolver: _FakePlaceResolver(<String, Place>{
          'AAA': _place('stn:AAA', cityId: 'city:a'),
          'BBB': _place('stn:BBB', cityId: 'city:b', lng: 78.0),
          'KKK': _place('stn:KKK', cityId: 'city:k', lng: 77.5),
        }),
      );

      final List<String> ids =
          index.placed.single.stops.map((JourneyStop s) => s.place!.id).toList();
      expect(ids, <String>['stn:AAA', 'stn:KKK', 'stn:BBB']);
    });

    test('a halt repeating an endpoint does not create a zero-length segment', () {
      // Fixtures routinely list the origin and destination among the halts.
      final index = buildJourneyIndex(
        passes: <WalletPassItem>[
          TrainPassItem(_train(halts: <TicketHalt>[
            _halt('Origin (AAA)'),
            _halt('Destination (BBB)'),
          ])),
        ],
        resolver: _FakePlaceResolver(<String, Place>{
          'AAA': _place('stn:AAA', cityId: 'city:a'),
          'BBB': _place('stn:BBB', cityId: 'city:b', lng: 78.0),
        }),
      );

      final List<String> ids =
          index.placed.single.stops.map((JourneyStop s) => s.place!.id).toList();
      expect(ids, <String>['stn:AAA', 'stn:BBB']);
    });

    test('interior halts are capped so a long route stays cheap', () {
      // Codes are letters only, like the real ones — a code with a digit in it
      // is rejected by the parser as a name that reached the wrong field.
      String code(int i) =>
          'Q${String.fromCharCode(65 + i ~/ 26)}${String.fromCharCode(65 + i % 26)}';

      final index = buildJourneyIndex(
        passes: <WalletPassItem>[
          TrainPassItem(_train(halts: <TicketHalt>[
            for (int i = 0; i < 40; i++) _halt('Halt $i (${code(i)})'),
          ])),
        ],
        resolver: _FakePlaceResolver(<String, Place>{
          'AAA': _place('stn:AAA', cityId: 'city:a'),
          'BBB': _place('stn:BBB', cityId: 'city:b', lng: 78.0),
          for (int i = 0; i < 40; i++)
            code(i): _place('stn:${code(i)}',
                cityId: 'city:${code(i)}', lng: 77.0 + i * 0.01),
        }),
      );

      // Two endpoints plus at most eight sampled vias.
      expect(index.placed.single.stops.length, lessThanOrEqualTo(10));
      expect(index.placed.single.stops.length, greaterThan(2));
    });
  });

  group('resolution report', () {
    test('counts what resolved and names what did not', () {
      final index = buildJourneyIndex(
        passes: <WalletPassItem>[TrainPassItem(_train())],
        resolver: _FakePlaceResolver(<String, Place>{
          'AAA': _place('stn:AAA', cityId: 'city:a'),
        }),
      );

      expect(index.report.attempted, 2);
      expect(index.report.resolved, 1);
      expect(index.report.missed, <String>['bbb']);
      expect(index.report.resolutionRate, 0.5);
    });

    test('a pass carrying no place at all is not counted as a table miss', () {
      // "The pass never said where" and "the table has no row" are different
      // problems, and conflating them hides real coverage gaps.
      final index = buildJourneyIndex(
        passes: <WalletPassItem>[
          MoviePassItem(_movie(cinemaName: '', cinemaAddress: '')),
        ],
        resolver: _FakePlaceResolver(const <String, Place>{}),
      );

      expect(index.report.attempted, 0);
      expect(index.report.missed, isEmpty);
      expect(index.unplaced.length, 1);
    });
  });

  group('ordering', () {
    test('most recent first, undated last, id as the tie-break', () {
      final index = buildJourneyIndex(
        passes: <WalletPassItem>[
          TrainPassItem(_train(id: 'older', date: '01 Jan 2020')),
          TrainPassItem(_train(id: 'undated', date: 'not a date')),
          TrainPassItem(_train(id: 'newer', date: '01 Jan 2024')),
        ],
        resolver: _FakePlaceResolver(const <String, Place>{}),
      );

      expect(
        index.events.map((JourneyEvent e) => e.id).toList(),
        <String>['train:newer', 'train:older', 'train:undated'],
      );
    });
  });

  group('flights', () {
    test('a mock itinerary becomes a route without being a pass kind', () {
      final index = buildJourneyIndex(
        passes: const <WalletPassItem>[],
        flights: <FlightItinerary>[
          FlightItinerary(
            id: 'f1',
            airline: 'Test Air',
            flightNumber: 'TA101',
            fromIata: 'BLR',
            toIata: 'DXB',
            fromCity: 'Bengaluru',
            toCity: 'Dubai',
            departAt: DateTime(2025, 6, 1, 9),
          ),
        ],
        resolver: _FakePlaceResolver(<String, Place>{
          'BLR': _place('city:bengaluru'),
          'DXB': _place('city:dubai', lat: 25.2, lng: 55.3),
        }),
      );

      final JourneyEvent flight = index.placed.single;
      expect(flight.kind, JourneyEventKind.flight);
      expect(flight.id, 'flight:f1');
      expect(flight.isRoute, isTrue);
      expect(flight.when, DateTime(2025, 6, 1, 9));
    });
  });

  group('spherical geometry', () {
    test('a centroid of points either side of the antimeridian stays there', () {
      // Averaging longitude as a scalar would land this in Africa.
      final Vec3? centroid = sphericalCentroid(<Vec3>[
        unitVectorFor(0.0, 179.0),
        unitVectorFor(0.0, -179.0),
      ]);

      final GeoPoint point = geoPointFor(centroid!);
      expect(point.lat, closeTo(0.0, 1e-9));
      expect(point.lng.abs(), closeTo(180.0, 1e-6));
    });

    test('a centroid stays on the unit sphere', () {
      final Vec3? centroid = sphericalCentroid(<Vec3>[
        unitVectorFor(12.97, 77.59),
        unitVectorFor(17.38, 78.48),
        unitVectorFor(28.61, 77.20),
      ]);
      expect(centroid!.length, closeTo(1.0, 1e-12));
    });

    test('antipodal points have no centroid rather than a wrong one', () {
      final Vec3? centroid = sphericalCentroid(<Vec3>[
        unitVectorFor(0.0, 0.0),
        unitVectorFor(0.0, 180.0),
      ]);
      expect(centroid, isNull);
    });

    test('angular distance never returns NaN for identical directions', () {
      // acos of a dot product that float error pushed past 1.0 is NaN, and it
      // would silently poison every distance-scaled camera duration.
      final Vec3 v = unitVectorFor(45.0, 45.0);
      expect(angularDistance(v, v), 0.0);
      expect(angularDistance(v, v * -1.0), closeTo(3.141592653589793, 1e-9));
    });

    test('a point round-trips through the vector form', () {
      const GeoPoint original = GeoPoint(17.3850, 78.4867);
      final GeoPoint back = geoPointFor(original.unitVector);
      expect(back.lat, closeTo(original.lat, 1e-9));
      expect(back.lng, closeTo(original.lng, 1e-9));
    });
  });
}
