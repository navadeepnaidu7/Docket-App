import 'package:docket/features/tickets/data/mock_flight_fixtures.dart';
import 'package:docket/features/tickets/domain/airline_brands.dart';
import 'package:docket/features/tickets/domain/bcbp.dart';
import 'package:docket/features/tickets/domain/flight_format.dart';
import 'package:docket/features/tickets/domain/flight_geo.dart';
import 'package:docket/features/tickets/domain/flight_pass_models.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_status.dart';
import 'package:docket/features/tickets/presentation/flight/airline_logo.dart';
import 'package:docket/features/tickets/presentation/flight/flight_brand_style.dart';
import 'package:docket/features/tickets/presentation/flight/flight_journey_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a one-leg BCBP mandatory block with exact padding, so tests never
/// depend on hand-counted spaces.
String bcbp({
  String name = 'NAGELLA/NAVADEEP MR',
  String pnr = 'X7KQ2M',
  String from = 'BLR',
  String to = 'DEL',
  String carrier = '6E',
  String flight = '2134',
  String doy = '325',
  String compartment = 'Y',
  String seat = '012A',
  String seq = '0042',
  String conditional = '',
}) {
  final String size = conditional.length
      .toRadixString(16)
      .toUpperCase()
      .padLeft(2, '0');
  return 'M1${name.padRight(20)}E${pnr.padRight(7)}$from$to'
      '${carrier.padRight(3)}${flight.padLeft(4, '0').padRight(5)}'
      '$doy$compartment$seat${seq.padRight(5)}1$size$conditional';
}

FlightPass flight({
  String departAt = '2026-11-21T06:10:00+05:30',
  String arriveAt = '2026-11-21T09:00:00+05:30',
  String? boardingAt = '2026-11-21T05:30:00+05:30',
  String gate = '',
  FlightLive? live,
  List<FlightUpdate> updates = const <FlightUpdate>[],
  TicketStatus status = TicketStatus.active,
}) {
  return FlightPass(
    id: 'f1',
    airline: 'IndiGo',
    flightNumber: '6E 2134',
    origin: const FlightAirport(code: 'BLR', city: 'Bengaluru', terminal: '1'),
    destination: const FlightAirport(
      code: 'DEL',
      city: 'New Delhi',
      terminal: '1D',
    ),
    status: status,
    departAt: AirportTime.tryParse(departAt),
    arriveAt: AirportTime.tryParse(arriveAt),
    boardingAt: AirportTime.tryParse(boardingAt),
    gate: gate,
    live: live,
    updates: updates,
  );
}

DateTime ist(int day, int hour, int minute) => DateTime.utc(
  2026,
  11,
  day,
  hour,
  minute,
).subtract(const Duration(hours: 5, minutes: 30));

void main() {
  group('BCBP', () {
    test('parses the IATA implementation guide example', () {
      const String sample =
          'M1DESMARAIS/LUC       EABC123 YULFRAAC 0834 326J001A0025 100';
      expect(sample.length, 60);
      final BcbpPass? p = parseBcbp(sample);
      expect(p, isNotNull);
      expect(p!.passengerName, 'DESMARAIS/LUC');
      expect(p.displayName, 'Luc Desmarais');
      expect(p.electronicTicket, isTrue);
      final BcbpLeg leg = p.legs.single;
      expect(leg.pnr, 'ABC123');
      expect(leg.from, 'YUL');
      expect(leg.to, 'FRA');
      expect(leg.carrier, 'AC');
      expect(leg.flightNumber, '834');
      expect(leg.displayFlightNumber, 'AC 834');
      expect(leg.dayOfYear, 326);
      expect(leg.compartment, 'J');
      expect(leg.cabin, 'Business');
      expect(leg.seat, '1A');
      expect(leg.sequence, '25');
    });

    test('drops the title and title-cases the name', () {
      final BcbpPass p = parseBcbp(bcbp())!;
      expect(p.displayName, 'Navadeep Nagella');
      expect(p.legs.single.displayFlightNumber, '6E 2134');
      expect(p.legs.single.seat, '12A');
      expect(p.legs.single.cabin, 'Economy');
    });

    test(
      'skips a conditional section and keeps a trailing newline harmless',
      () {
        final String withCond = '${bcbp(conditional: '>5180  B1A')}\n';
        expect(parseBcbp(withCond)!.legs.single.to, 'DEL');
      },
    );

    test('reads a second leg after the first leg conditional block', () {
      const String cond = '>5180';
      final String first = bcbp(conditional: cond).replaceRange(1, 2, '2');
      final String second =
          '${'X7KQ2M'.padRight(7)}DELBOM6E 0512 326Y014C0007 100';
      final BcbpPass p = parseBcbp(first + second)!;
      expect(p.legs, hasLength(2));
      expect(p.legs[1].from, 'DEL');
      expect(p.legs[1].to, 'BOM');
      expect(p.legs[1].flightNumber, '512');
    });

    test('rejects strings that only look like a boarding pass', () {
      expect(parseBcbp(''), isNull);
      expect(parseBcbp('M1SHORT'), isNull);
      expect(parseBcbp(bcbp(from: 'B1R')), isNull);
      expect(parseBcbp(bcbp(doy: '400')), isNull);
      expect(
        parseBcbp(bcbp().replaceRange(1, 2, '2')),
        isNull,
        reason: 'claims two legs but carries one',
      );
      expect(parseBcbp('https://example.com/${'x' * 60}'), isNull);
    });

    test('picks the year nearest the scan for a day-of-year date', () {
      final BcbpLeg leg = parseBcbp(bcbp(doy: '002'))!.legs.single;
      expect(leg.dateNear(DateTime(2026, 12, 30)), DateTime(2027, 1, 2));
      expect(leg.dateNear(DateTime(2027, 1, 1)), DateTime(2027, 1, 2));
      final BcbpLeg late = parseBcbp(bcbp(doy: '364'))!.legs.single;
      expect(late.dateNear(DateTime(2027, 1, 3)), DateTime(2026, 12, 30));
    });

    test('blank date and seat are absent, not zero', () {
      final BcbpLeg leg = parseBcbp(
        bcbp(doy: '   ', seat: '    '),
      )!.legs.single;
      expect(leg.dayOfYear, isNull);
      expect(leg.seat, isEmpty);
    });
  });

  group('AirportTime', () {
    test('keeps the airport wall clock whatever the phone zone', () {
      final AirportTime t = AirportTime.tryParse('2026-11-21T06:10:00+05:30')!;
      expect(t.instant, DateTime.utc(2026, 11, 21, 0, 40));
      expect(FlightFormat.time(t), '06:10');
      expect(FlightFormat.day(t), 'Sat, 21 Nov');
    });

    test('block time across zones uses instants, day offset uses walls', () {
      final AirportTime dep = AirportTime.tryParse(
        '2026-11-21T23:30:00+05:30',
      )!;
      final AirportTime arr = AirportTime.tryParse(
        '2026-11-22T04:10:00+04:00',
      )!;
      expect(FlightFormat.duration(dep, arr), '6h 10m');
      expect(FlightFormat.arrivalDayOffset(dep, arr), 1);
    });

    test('round-trips through JSON with its offset', () {
      final FlightPass p = flight();
      final FlightPass back = FlightPass.fromJson(p.toJson());
      expect(back.departAt!.offset, const Duration(hours: 5, minutes: 30));
      expect(back.departAt!.instant, p.departAt!.instant);
      final WalletPassItem item = walletPassItemFromJson(
        FlightPassItem(p).toJson(),
      );
      expect(item, isA<FlightPassItem>());
    });
  });

  group('resolveFlightJourneyStatus', () {
    test('no feed: counts down and never claims on time', () {
      final FlightJourneyStatus s = resolveFlightJourneyStatus(
        flight(gate: 'B12'),
        ist(21, 5, 30),
      );
      expect(s.lead, 'Departs in');
      expect(s.emphasis, '40 min');
      expect(s.detail, 'Gate B12, boarding 05:30');
      expect(s.detail, isNot(contains('On time')));
    });

    test('no feed: printed boarding time does not become "Boarding now"', () {
      final FlightJourneyStatus s = resolveFlightJourneyStatus(
        flight(),
        ist(21, 5, 45),
      );
      expect(s.emphasis, isNot('Boarding now'));
    });

    test('feed on schedule says on time', () {
      final FlightJourneyStatus s = resolveFlightJourneyStatus(
        flight(
          live: FlightLive(
            departEstimatedAt: AirportTime.tryParse(
              '2026-11-21T06:12:00+05:30',
            ),
          ),
        ),
        ist(21, 4, 0),
      );
      expect(s.detail, startsWith('On time'));
      expect(s.tone, FlightStatusTone.positive);
    });

    test('feed with a late estimate says delayed and the new time', () {
      final FlightJourneyStatus s = resolveFlightJourneyStatus(
        flight(
          live: FlightLive(
            departEstimatedAt: AirportTime.tryParse(
              '2026-11-21T06:35:00+05:30',
            ),
            departGate: 'B17',
          ),
          gate: 'B12',
        ),
        ist(21, 5, 0),
      );
      expect(s.lead, 'Delayed');
      expect(s.emphasis, '25 min');
      expect(s.detail, 'Now departs 06:35, gate B17');
      expect(s.tone, FlightStatusTone.warning);
    });

    test('feed boarding', () {
      final FlightJourneyStatus s = resolveFlightJourneyStatus(
        flight(
          gate: 'B12',
          live: const FlightLive(state: FlightLiveState.boarding),
        ),
        ist(21, 5, 40),
      );
      expect(s.emphasis, 'Boarding now');
      expect(s.detail, 'Gate B12');
    });

    test('in the air counts down to the revised arrival', () {
      final FlightJourneyStatus s = resolveFlightJourneyStatus(
        flight(
          live: FlightLive(
            state: FlightLiveState.enRoute,
            departActualAt: AirportTime.tryParse('2026-11-21T06:40:00+05:30'),
            arriveEstimatedAt: AirportTime.tryParse(
              '2026-11-21T09:20:00+05:30',
            ),
          ),
        ),
        ist(21, 8, 8),
      );
      expect(s.lead, 'Lands in');
      expect(s.emphasis, '1h 12m');
      expect(s.detail, '20 min late');
      expect(s.progress, greaterThan(0.5));
    });

    test('landed shows the belt when known', () {
      final FlightJourneyStatus s = resolveFlightJourneyStatus(
        flight(
          live: FlightLive(
            state: FlightLiveState.landed,
            arriveActualAt: AirportTime.tryParse('2026-11-21T09:12:00+05:30'),
            baggageBelt: '4',
          ),
        ),
        ist(21, 9, 20),
      );
      expect(s.lead, 'Landed');
      expect(s.emphasis, '09:12');
      expect(s.detail, 'Bags on belt 4');
    });

    test('no feed past arrival says arrived, not landed', () {
      final FlightJourneyStatus s = resolveFlightJourneyStatus(
        flight(),
        ist(21, 10, 0),
      );
      expect(s.lead, 'Arrived');
      expect(s.emphasis, '09:00');
    });

    test('cancelled wins over everything', () {
      final FlightJourneyStatus s = resolveFlightJourneyStatus(
        flight(live: const FlightLive(state: FlightLiveState.cancelled)),
        ist(21, 9, 30),
      );
      expect(s.emphasis, 'Cancelled');
    });

    test('tomorrow is the airport day, not the phone day', () {
      // 22:00 IST on the 20th; the flight is 06:10 IST on the 22nd.
      final FlightJourneyStatus s = resolveFlightJourneyStatus(
        flight(
          departAt: '2026-11-22T06:10:00+05:30',
          arriveAt: '2026-11-22T09:00:00+05:30',
        ),
        ist(20, 22, 0),
      );
      expect(s.emphasis, '2 days');
    });
  });

  group('Updates feed', () {
    test('newest first, sentences from facts, unknown types dropped', () {
      final FlightPass p = flight(
        updates: <FlightUpdate>[
          FlightUpdate(
            at: ist(21, 3, 0),
            type: FlightUpdateType.gateAssigned,
            to: 'B12',
          ),
          FlightUpdate(
            at: ist(21, 4, 50),
            type: FlightUpdateType.gateChange,
            from: 'B12',
            to: 'B17',
          ),
          FlightUpdate(at: ist(21, 5, 0), type: FlightUpdateType.unknown),
          FlightUpdate(
            at: ist(21, 9, 14),
            type: FlightUpdateType.beltAssigned,
            to: '4',
          ),
        ],
      );
      final List<FlightUpdateLine> feed = flightUpdateFeed(p);
      expect(feed.map((FlightUpdateLine l) => l.title), <String>[
        'Bags on belt 4',
        'Gate changed to B17',
        'Gate B12 assigned',
      ]);
      expect(feed.first.time, '09:14');
      expect(feed[1].tone, FlightStatusTone.warning);
    });

    test('a delay update with no minutes renders nothing', () {
      final FlightPass p = flight(
        updates: <FlightUpdate>[
          FlightUpdate(at: ist(21, 4, 0), type: FlightUpdateType.delay),
        ],
      );
      expect(flightUpdateFeed(p), isEmpty);
    });
  });

  group('Geo', () {
    test('Bengaluru to Delhi is about 1,700 km', () {
      final double km = greatCircleKm(
        FlightAirportCoordinates.of('BLR')!,
        FlightAirportCoordinates.of('DEL')!,
      );
      expect(km, closeTo(1708, 15));
    });

    test('the sun is up at Delhi noon and down at Delhi midnight', () {
      const GeoPoint del = GeoPoint(28.5562, 77.1);
      expect(solarElevation(del, ist(21, 12, 15)), closeTo(40, 3));
      expect(solarElevation(del, ist(21, 0, 15)), lessThan(-30));
    });

    test('dawn at Bengaluru: below the horizon at 06:00, above by 06:40', () {
      const GeoPoint blr = GeoPoint(13.1986, 77.7066);
      expect(solarElevation(blr, ist(21, 6, 0)), lessThan(0));
      expect(solarElevation(blr, ist(21, 6, 40)), greaterThan(0));
    });
  });

  group('ADS-B updates and the situation line', () {
    test('found, cruising and descending read as sentences', () {
      final FlightPass p = flight(
        live: const FlightLive(
          state: FlightLiveState.enRoute,
          aircraft: 'Airbus A320neo',
          registration: 'VT-IPZ',
        ),
        updates: <FlightUpdate>[
          FlightUpdate(
            at: ist(21, 5, 40),
            type: FlightUpdateType.aircraftFound,
            to: 'VT-IPZ',
          ),
          FlightUpdate(
            at: ist(21, 6, 53),
            type: FlightUpdateType.cruising,
            to: '36000',
          ),
          FlightUpdate(at: ist(21, 8, 22), type: FlightUpdateType.descending),
        ],
      );
      final List<FlightUpdateLine> feed = flightUpdateFeed(p);
      expect(feed.map((FlightUpdateLine l) => l.title), <String>[
        'Started descent',
        'Reached 36,000 ft',
        'Aircraft found',
      ]);
      expect(feed.last.detail, 'VT-IPZ, an Airbus A320neo');
      expect(feed.first.detail, 'Into New Delhi');
      expect(
        flightSituationLine(p, ist(21, 8, 30)),
        'Descending into New Delhi.',
      );
    });

    test('no feed before departure promises nothing live', () {
      expect(
        flightSituationLine(flight(), ist(21, 4, 0)),
        startsWith('Times are from your pass.'),
      );
    });

    test('position, altitude and photo survive JSON', () {
      final FlightLive live = FlightLive.fromJson(<String, dynamic>{
        'state': 'enRoute',
        'lat': 16.65,
        'lon': 73.25,
        'altitudeFt': 21400,
        'groundSpeedKt': 386,
        'aircraftPhotoUrl': 'https://example.org/a.jpg',
        'aircraftPhotoCredit': 'Photo by someone',
      });
      final FlightLive back = FlightLive.fromJson(live.toJson());
      expect(back.position!.lat, 16.65);
      expect(back.position!.lon, 73.25);
      expect(back.altitudeFt, 21400);
      expect(back.groundSpeedKt, 386);
      expect(back.aircraftPhotoUrl, 'https://example.org/a.jpg');
      expect(back.aircraftPhotoCredit, 'Photo by someone');
    });

    test('a nonsense position is dropped, not drawn', () {
      expect(
        FlightLive.fromJson(<String, dynamic>{'lat': 123, 'lon': 77}).position,
        isNull,
      );
    });
  });

  group('Airline brands', () {
    test('every code is unique, upper case, and two characters', () {
      final Set<String> seen = <String>{};
      for (final AirlineBrand b in airlineBrands) {
        expect(b.code, matches(RegExp(r'^[A-Z0-9]{2}$')), reason: b.name);
        expect(seen.add(b.code), isTrue, reason: 'duplicate ${b.code}');
      }
      expect(airlineBrands.length, greaterThanOrEqualTo(80));
    });

    test('a pass resolves its airline from the flight number', () {
      final FlightPass p = FlightPass.fromJson(<String, dynamic>{
        ...mockFlightPasses[1].toJson(),
        'airlineCode': '',
        'flightNumber': 'lh 761',
      });
      expect(p.brand?.name, 'Lufthansa');
      expect(AirlineBrand.of('zz'), isNull);
    });

    test('light liveries print in dark ink, unknown airlines in neutral', () {
      final FlightBrandStyle vueling = FlightBrandStyle.of(
        AirlineBrand.of('VY'),
        active: true,
      );
      expect(vueling.ink.computeLuminance(), lessThan(0.1));
      expect(
        FlightBrandStyle.of(null, active: true).surface,
        FlightBrandStyle.universal.surface,
      );
      expect(
        FlightBrandStyle.of(AirlineBrand.of('EK'), active: false).surface,
        FlightBrandStyle.spent.surface,
      );
    });

    test('white ink reads on every dark livery', () {
      for (final AirlineBrand b in airlineBrands.where((b) => !b.darkInk)) {
        final double l = Color(b.surface).computeLuminance();
        // WCAG contrast of white on the surface, at least 3:1 for the
        // large type the face is set in.
        expect((1.05) / (l + 0.05), greaterThanOrEqualTo(3), reason: b.name);
      }
    });

    test('logos of any shape cover about the same area', () {
      final Size wordmark = AirlineLogo.fit(6);
      final Size emblem = AirlineLogo.fit(1.4);
      expect(wordmark.height, lessThan(emblem.height));
      expect(wordmark.width, greaterThan(emblem.width));
      expect(emblem.height, lessThanOrEqualTo(30));
      expect(AirlineLogo.fit(20).width, lessThanOrEqualTo(168));
    });
  });
}
