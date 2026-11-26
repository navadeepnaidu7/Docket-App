import 'package:docket/core/wallet/wallet_card_metrics.dart';
import 'package:docket/features/tickets/application/pass_list_provider.dart';
import 'package:docket/features/tickets/application/ticket_code_scanner.dart';
import 'package:docket/features/tickets/data/mock_flight_fixtures.dart';
import 'package:docket/features/tickets/domain/flight_pass_models.dart';
import 'package:docket/features/tickets/domain/flight_trip.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_code.dart';
import 'package:docket/features/tickets/presentation/flight/flight_pass_detail_screen.dart';
import 'package:docket/features/tickets/presentation/flight/flight_ticket_face.dart';
import 'package:docket/features/tickets/presentation/flight/flight_updates_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Map<String, dynamic> _leg(
  String id,
  String from,
  String to,
  String depart,
  String arrive, {
  String number = '6E 1',
}) => <String, dynamic>{
  'id': id,
  'flightNumber': number,
  'from': from,
  'to': to,
  'departAt': depart,
  'arriveAt': arrive,
};

FlightTrip _trip(int index, List<Map<String, dynamic>> legs) =>
    FlightTrip.tryFromJson(<String, dynamic>{
      'id': 't',
      'index': index,
      'legs': legs,
    })!;

final List<Map<String, dynamic>> _connection = <Map<String, dynamic>>[
  _leg(
    'a',
    'BLR',
    'DEL',
    '2026-12-03T06:10:00+05:30',
    '2026-12-03T09:00:00+05:30',
    number: '6E 2134',
  ),
  _leg(
    'b',
    'DEL',
    'LHR',
    '2026-12-03T10:35:00+05:30',
    '2026-12-03T15:05:00+00:00',
    number: 'AI 111',
  ),
];

/// The wallet, without the mock repository's simulated network delay.
class _FixturePasses extends PassListNotifier {
  @override
  Future<List<WalletPassItem>> build() async => <WalletPassItem>[
    for (final FlightPass f in mockFlightPasses) FlightPassItem(f),
  ];
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('reading a trip', () {
    test('a same-day change of plane is one journey with a layover', () {
      final FlightTrip trip = _trip(0, _connection);
      final List<FlightTripJourney> journeys = flightTripJourneys(trip);
      expect(journeys, hasLength(1));
      expect(journeys.single.part, FlightTripPart.single);
      final FlightTripPlace place = placeInTrip(trip)!;
      expect(place.tag, 'Leg 1 of 2');
      expect(place.onwardLine, 'Then AI 111 to LHR · 1h 35m in DEL');
      expect(placeInTrip(_trip(1, _connection))!.onwardLine, isEmpty);
    });

    test('flying home days later is a return, with its own connection', () {
      final List<Map<String, dynamic>> legs = <Map<String, dynamic>>[
        ..._connection,
        _leg(
          'c',
          'LHR',
          'DEL',
          '2026-12-10T21:00:00+00:00',
          '2026-12-11T10:30:00+05:30',
        ),
        _leg(
          'd',
          'DEL',
          'BLR',
          '2026-12-11T13:00:00+05:30',
          '2026-12-11T15:45:00+05:30',
        ),
      ];
      final FlightTrip trip = _trip(2, legs);
      expect(
        flightTripJourneys(trip).map((FlightTripJourney j) => j.part),
        <FlightTripPart>[FlightTripPart.outbound, FlightTripPart.inbound],
      );
      expect(placeInTrip(trip)!.tag, 'Return · 1 of 2');
      expect(placeInTrip(_trip(1, legs))!.tag, 'Outbound · 2 of 2');
    });

    test('a stay of more than a day splits the journey', () {
      final FlightTrip trip = _trip(1, <Map<String, dynamic>>[
        _leg(
          'a',
          'BLR',
          'DEL',
          '2026-12-03T06:10:00+05:30',
          '2026-12-03T09:00:00+05:30',
        ),
        _leg(
          'b',
          'DEL',
          'GOI',
          '2026-12-05T08:00:00+05:30',
          '2026-12-05T10:30:00+05:30',
        ),
      ]);
      expect(flightTripJourneys(trip), hasLength(2));
      // Ends in Goa, not Bengaluru: onward, not a return.
      expect(placeInTrip(trip)!.tag, 'Onward');
    });

    test('a leg that does not leave from where the last landed is no '
        'connection', () {
      final FlightTrip trip = _trip(0, <Map<String, dynamic>>[
        _connection.first,
        _leg(
          'b',
          'BOM',
          'LHR',
          '2026-12-03T12:00:00+05:30',
          '2026-12-03T17:00:00+00:00',
        ),
      ]);
      expect(flightTripJourneys(trip), hasLength(2));
      expect(placeInTrip(trip)!.onwardLine, isEmpty);
    });

    test('a malformed trip is no trip', () {
      expect(FlightTrip.tryFromJson(null), isNull);
      expect(
        FlightTrip.tryFromJson(<String, dynamic>{
          'index': 0,
          'legs': <dynamic>[_connection.first],
        }),
        isNull,
        reason: 'one leg',
      );
      expect(
        FlightTrip.tryFromJson(<String, dynamic>{
          'index': 5,
          'legs': _connection,
        }),
        isNull,
        reason: 'index out of range',
      );
    });

    test('the trip survives a JSON round trip on the pass', () {
      final FlightPass f = mockFlightPasses.firstWhere(
        (FlightPass p) => p.id == 'mock_f1',
      );
      final FlightPass again = FlightPass.fromJson(f.toJson());
      expect(again.trip!.legs.map((FlightTripLeg l) => l.id), <String>[
        'mock_f1',
        'mock_f7',
      ]);
      expect(again.trip!.index, 0);
    });
  });

  group('fixtures', () {
    String? tagOf(String id) {
      final FlightPass p = mockFlightPasses.firstWhere(
        (FlightPass f) => f.id == id,
      );
      return p.trip == null ? null : placeInTrip(p.trip!)!.tag;
    }

    test('show a connection and a return', () {
      expect(tagOf('mock_f1'), 'Leg 1 of 2');
      expect(tagOf('mock_f7'), 'Leg 2 of 2');
      expect(tagOf('mock_f8'), 'Outbound');
      expect(tagOf('mock_f4'), 'Return');
      expect(tagOf('mock_f2'), isNull);
    });
  });

  group('on screen', () {
    Widget host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: WalletCardMetrics.trainCanvasWidth,
            height: WalletCardMetrics.trainCanvasHeight,
            child: child,
          ),
        ),
      ),
    );

    testWidgets('the face tags the leg', (WidgetTester t) async {
      final FlightPass f = mockFlightPasses.firstWhere(
        (FlightPass p) => p.id == 'mock_f4',
      );
      await t.pumpWidget(host(FlightTicketFace(pass: f)));
      expect(t.takeException(), isNull);
      expect(
        t.widget<Text>(find.byKey(FlightTicketFace.tripKey)).data,
        'Return',
      );
    });

    testWidgets('the face names the onward flight while it is still to come', (
      WidgetTester t,
    ) async {
      String ist(Duration from) {
        final DateTime l = DateTime.now().toUtc().add(
          from + const Duration(hours: 5, minutes: 30),
        );
        String two(int v) => v.toString().padLeft(2, '0');
        return '${l.year}-${two(l.month)}-${two(l.day)}'
            'T${two(l.hour)}:${two(l.minute)}:00+05:30';
      }

      // No gate yet, so the detail line is free for the connection.
      final List<Map<String, dynamic>> legs = <Map<String, dynamic>>[
        _leg(
          'x',
          'DEL',
          'BOM',
          ist(const Duration(days: 3)),
          ist(const Duration(days: 3, hours: 2)),
          number: 'AI 803',
        ),
        _leg(
          'y',
          'BOM',
          'GOX',
          ist(const Duration(days: 3, hours: 3, minutes: 20)),
          ist(const Duration(days: 3, hours: 4, minutes: 30)),
          number: 'AI 2877',
        ),
      ];
      FlightPass leg(int index) => FlightPass.fromJson(<String, dynamic>{
        'id': legs[index]['id'],
        'airline': 'Air India',
        'flightNumber': legs[index]['flightNumber'],
        'origin': legs[index]['from'],
        'destination': legs[index]['to'],
        'departAt': legs[index]['departAt'],
        'arriveAt': legs[index]['arriveAt'],
        'status': 'active',
        'trip': <String, dynamic>{'id': 't', 'index': index, 'legs': legs},
      });

      await t.pumpWidget(host(FlightTicketFace(pass: leg(0))));
      expect(find.text('Then AI 2877 to GOX · 1h 20m in BOM'), findsOneWidget);
      await t.pumpWidget(host(FlightTicketFace(pass: leg(1))));
      expect(find.textContaining('Then '), findsNothing);
    });

    testWidgets('the detail screen lists the trip', (WidgetTester t) async {
      FlightAircraftCard.debugPhotoBuilder = (_) => const SizedBox.expand();
      addTearDown(() => FlightAircraftCard.debugPhotoBuilder = null);
      t.view.physicalSize = const Size(393, 2600);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      final FlightPass f = mockFlightPasses.firstWhere(
        (FlightPass p) => p.id == 'mock_f1',
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: [passListProvider.overrideWith(_FixturePasses.new)],
          child: MaterialApp(home: FlightPassDetailScreen(pass: f)),
        ),
      );
      await t.pump();
      expect(find.text('Your trip'), findsOneWidget);
      expect(find.text('BLR → DEL'), findsOneWidget);
      expect(find.text('DEL → SXR'), findsOneWidget);
      expect(find.text('1h 45m connection in DEL'), findsOneWidget);
      expect(find.text('This pass'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('boardingPassCodes', () {
    TicketCodeCandidate c(String text, double area) => TicketCodeCandidate(
      format: PassCodeFormat.pdf417,
      area: area,
      text: text,
    );
    const String out =
        'M1NAIDU/NAVADEEP      EX7KQ2M BLRDEL6E 2134 325Y014C0042 100';
    const String back =
        'M1NAIDU/NAVADEEP      EX7KQ2M DELBLR6E 2135 330Y021A0007 100';

    test('keeps every boarding pass across pages, once each, in order', () {
      final List<ScannedTicketCode> got = boardingPassCodes(
        <List<TicketCodeCandidate>>[
          <TicketCodeCandidate>[
            c('https://play.google.com/x', 9000),
            c(out, 4000),
          ],
          <TicketCodeCandidate>[c(back, 4000), c(out, 100)],
        ],
      );
      expect(got.map((ScannedTicketCode s) => s.payload), <String>[out, back]);
    });

    test('ignores codes that are not boarding passes', () {
      expect(
        boardingPassCodes(<List<TicketCodeCandidate>>[
          <TicketCodeCandidate>[c('ABC123', 5000)],
        ]),
        isEmpty,
      );
    });
  });
}
