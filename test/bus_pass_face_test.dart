import 'package:docket/core/wallet/wallet_card_metrics.dart';
import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/data/mock_pass_repository.dart';
import 'package:docket/features/tickets/domain/bus_pass_models.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_status.dart';
import 'package:docket/features/tickets/presentation/bus/bus_brand_style.dart';
import 'package:docket/features/tickets/presentation/bus/bus_pass_theme.dart';
import 'package:docket/features/tickets/presentation/bus/bus_ticket_face.dart';
import 'package:docket/features/tickets/presentation/pass_code_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

BusPass _pass({
  String operator = 'redBus',
  BusPassBrand? brand = BusPassBrand.redBus,
  String boarding = 'Bengaluru, Kempegowda Bus Station',
  String drop = 'Mysuru, Mysuru City Bus Stand',
  String fromCity = 'Bengaluru',
  String toCity = 'Mysuru',
  String boardingPoint = 'Kempegowda Bus Station',
  String platform = 'Platform 15',
  String fare = '₹650',
  String departTime = '08:30 AM',
  String arriveTime = '11:45 AM',
  String? departAt = '2026-08-20T08:30:00',
  String? arriveAt = '2026-08-20T11:45:00',
  String date = '20 Aug 2026',
  String arrivalDate = '20 Aug 2026',
  String seatDetails = '12A',
  List<BusPassenger> passengers = const <BusPassenger>[
    BusPassenger(name: 'Navadeep Naidu', seat: '12A'),
  ],
  String bookingId = 'RB8842119',
  String? codePayload = 'RBQR8842119',
  TicketStatus status = TicketStatus.active,
}) {
  return BusPass(
    id: 'b',
    operator: operator,
    brand: brand,
    fromCity: fromCity,
    toCity: toCity,
    boardingLocation: boarding,
    dropLocation: drop,
    boardingPoint: boardingPoint,
    platform: platform,
    departTime: departTime,
    arriveTime: arriveTime,
    date: date,
    arrivalDate: arrivalDate,
    departAt: departAt,
    arriveAt: arriveAt,
    seatDetails: seatDetails,
    fare: fare,
    passengers: passengers,
    bookingId: bookingId,
    codePayload: codePayload,
    status: status,
  );
}

/// Two days before the default pass departs.
final DateTime _now = DateTime(2026, 8, 18, 10);

Future<void> _pumpFace(WidgetTester tester, BusPass pass) async {
  tester.view.physicalSize = const Size(500, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: BusPassMetrics.width,
            height: BusPassMetrics.height,
            child: BusTicketFace(pass: pass, clock: () => _now),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Offset _faceOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(BusTicketFace));

void main() {
  group('layout', () {
    testWidgets('lays out inside its canvas without overflowing', (
      WidgetTester tester,
    ) async {
      await _pumpFace(tester, _pass());
      expect(tester.takeException(), isNull);

      final Size size = tester.getSize(find.byType(BusTicketFace));
      expect(size.width, BusPassMetrics.width);
      expect(size.height, BusPassMetrics.height);
    });

    testWidgets('survives long names, many seats, no fare and no booking id', (
      WidgetTester tester,
    ) async {
      await _pumpFace(
        tester,
        _pass(
          operator: 'Thiruvananthapuram Interstate Coach Services Limited',
          brand: null,
          fromCity: 'Thiruvananthapuram',
          toCity: 'Kanyakumari',
          boarding: 'Thiruvananthapuram, Central Bus Station East Wing Bay 22',
          drop: 'Kanyakumari, Vivekananda Kendra Junction Stand',
          boardingPoint: '',
          departTime: '12:45 PM',
          arriveTime: '10:20 AM',
          departAt: '2026-08-20T12:45:00',
          arriveAt: '2026-08-21T10:20:00',
          arrivalDate: '21 Aug 2026',
          seatDetails: 'L12 Lower sleeper',
          fare: '',
          bookingId: '',
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Booking'), findsNothing);
      expect(find.text('Fare'), findsNothing);
    });

    testWidgets('an unparseable time prints a dash, not free text', (
      WidgetTester tester,
    ) async {
      await _pumpFace(tester, _pass(departTime: 'To be announced'));
      expect(tester.takeException(), isNull);
      expect(find.text('To be announced'), findsNothing);
    });
  });

  group('alignment', () {
    testWidgets('city and stop share the left edge under the departure', (
      WidgetTester tester,
    ) async {
      await _pumpFace(tester, _pass());
      final double origin = _faceOrigin(tester).dx;

      expect(
        tester.getTopLeft(find.text('Bengaluru')).dx - origin,
        BusPassMetrics.inset,
      );
      expect(
        tester.getTopLeft(find.text('Kempegowda Bus Station')).dx - origin,
        BusPassMetrics.inset,
      );
    });

    testWidgets('city, arrival and stop share the right edge', (
      WidgetTester tester,
    ) async {
      await _pumpFace(tester, _pass());
      final double right = _faceOrigin(tester).dx + BusPassMetrics.contentRight;

      expect(
        tester.getTopRight(find.byKey(BusTicketFace.arrivalKey)).dx,
        right,
      );
      // Right-aligned text fills its column; the glyphs end on the edge.
      expect(tester.getTopRight(find.text('Mysuru')).dx, right);
      expect(tester.getTopRight(find.text('Mysuru City Bus Stand')).dx, right);
    });

    testWidgets('the meridiem sits on the time baseline', (
      WidgetTester tester,
    ) async {
      await _pumpFace(tester, _pass());
      final Finder dep = find.byKey(BusTicketFace.departureKey);
      final Finder time = find.descendant(of: dep, matching: find.text('8:30'));
      final Finder meridiem = find.descendant(
        of: dep,
        matching: find.text('AM'),
      );

      final RenderParagraph t = tester.renderObject(time);
      final RenderParagraph m = tester.renderObject(meridiem);
      final double tBase =
          tester.getTopLeft(time).dy +
          t.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final double mBase =
          tester.getTopLeft(meridiem).dy +
          m.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      expect(mBase, closeTo(tBase, 0.01));
    });
  });

  group('brand', () {
    test(
      'resolves redBus from an explicit brand and from the operator name',
      () {
        expect(_pass().resolvedBrand, BusPassBrand.redBus);
        expect(
          _pass(brand: null, operator: 'Red Bus').resolvedBrand,
          BusPassBrand.redBus,
        );
      },
    );

    test('an unknown operator gets its own surface, not redBus red', () {
      final BusPass p = _pass(brand: null, operator: 'KSRTC Airavat');
      expect(p.resolvedBrand, BusPassBrand.universal);
      expect(
        BusBrandStyle.forPass(p).surface,
        isNot(BusBrandStyle.redBus.surface),
      );
    });

    test('expired drains the colour and keeps the wordmark', () {
      final BusBrandStyle style = BusBrandStyle.forPass(
        _pass(status: TicketStatus.expired),
      );
      expect(style.surface, isNot(BusBrandStyle.redBus.surface));
      expect(style.wordmarkLead, BusBrandStyle.redBus.wordmarkLead);
      expect(style.wordmarkTail, BusBrandStyle.redBus.wordmarkTail);
    });

    test('useBrandColors overrides the expiry drain', () {
      final BusBrandStyle style = BusBrandStyle.forPass(
        _pass(status: TicketStatus.expired),
        useBrandColors: true,
      );
      expect(style.surface, BusBrandStyle.redBus.surface);
    });
  });

  group('content', () {
    testWidgets('prints the journey in 12-hour time with the stations', (
      WidgetTester tester,
    ) async {
      await _pumpFace(tester, _pass());

      expect(find.text('Thu, 20 Aug'), findsOneWidget);
      expect(find.text('Booking RB8842119'), findsOneWidget);
      // Scoped to the visible times: invisible copies size the route rule.
      final Finder dep = find.byKey(BusTicketFace.departureKey);
      final Finder arr = find.byKey(BusTicketFace.arrivalKey);
      expect(find.descendant(of: dep, matching: find.text('8:30')), findsOne);
      expect(find.descendant(of: dep, matching: find.text('AM')), findsOne);
      expect(find.descendant(of: arr, matching: find.text('11:45')), findsOne);
      expect(find.descendant(of: arr, matching: find.text('AM')), findsOne);
      expect(find.text('3h 15m'), findsOneWidget);
      expect(find.text('Kempegowda Bus Station'), findsOneWidget);
      expect(find.text('Mysuru City Bus Stand'), findsOneWidget);
      expect(find.text('12A'), findsOneWidget);
      expect(find.text('₹650'), findsOneWidget);
      expect(find.text('Navadeep Naidu'), findsOneWidget);
    });

    testWidgets('drops the platform: bus tickets rarely carry one', (
      WidgetTester tester,
    ) async {
      await _pumpFace(tester, _pass());
      expect(find.textContaining('Platform'), findsNothing);
    });

    testWidgets('never draws a code, even when the pass has one', (
      WidgetTester tester,
    ) async {
      await _pumpFace(tester, _pass());
      expect(find.byType(PassCodeView), findsNothing);
    });

    testWidgets('paints the coach watermark', (WidgetTester tester) async {
      await _pumpFace(tester, _pass());
      expect(find.byKey(BusTicketFace.coachKey), findsOneWidget);
    });

    testWidgets('an overnight run hangs +1 and says when it arrives', (
      WidgetTester tester,
    ) async {
      await _pumpFace(
        tester,
        _pass(
          departTime: '11:15 PM',
          arriveTime: '05:30 AM',
          departAt: '2026-08-20T23:15:00',
          arriveAt: '2026-08-21T05:30:00',
          arrivalDate: '21 Aug 2026',
        ),
      );
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('Overnight, arrives Fri 5:30 AM'), findsOneWidget);
    });

    // "Mangaluru" has no comma, so station and city resolve to the same
    // string. Printing it above and below the time looks like a bug.
    testWidgets('does not print the city twice when the stop has no comma', (
      WidgetTester tester,
    ) async {
      await _pumpFace(tester, _pass(drop: 'Mangaluru', toCity: 'Mangaluru'));
      expect(find.text('Mangaluru'), findsOneWidget);
    });

    testWidgets('a group reads as the lead first name and a count', (
      WidgetTester tester,
    ) async {
      await _pumpFace(
        tester,
        _pass(
          seatDetails: 'W4, W5',
          passengers: const <BusPassenger>[
            BusPassenger(name: 'Navadeep Naidu', seat: 'W4'),
            BusPassenger(name: 'Asha Rao', seat: 'W5'),
          ],
        ),
      );
      expect(find.text('Navadeep and 1 other'), findsOneWidget);
      expect(find.text('W4, W5'), findsOneWidget);
    });

    testWidgets('past three seats the list collapses to a count', (
      WidgetTester tester,
    ) async {
      await _pumpFace(tester, _pass(seatDetails: 'A1, A2, A3, A4'));
      expect(find.text('A1 and 3 more'), findsOneWidget);
    });

    testWidgets('seats come from the passengers when the ticket lists none', (
      WidgetTester tester,
    ) async {
      await _pumpFace(tester, _pass(seatDetails: ''));
      expect(find.text('12A'), findsOneWidget);
    });
  });

  group('json', () {
    test('the optional fields round-trip and stay optional', () {
      final BusPass back = BusPass.fromJson(_pass().toJson());
      expect(back.resolvedBrand, BusPassBrand.redBus);
      expect(back.fromCity, 'Bengaluru');
      expect(back.boardingPoint, 'Kempegowda Bus Station');
      expect(back.fare, '₹650');

      final BusPass legacy = BusPass.fromJson(<String, dynamic>{
        'id': 'x',
        'operator': 'redBus',
        'boardingLocation': 'Bengaluru, Kempegowda Bus Station',
        'dropLocation': 'Mysuru, Mysuru City Bus Stand',
        'status': 'active',
      });
      expect(legacy.fare, '');
      expect(legacy.resolvedBrand, BusPassBrand.redBus);
      expect(legacy.resolvedFromCity, 'Bengaluru');
    });
  });

  group('wallet wiring', () {
    test('the mock repository serves bus passes', () async {
      final List<WalletPassItem> items = await MockPassRepository(
        artificialDelay: Duration.zero,
      ).fetchPasses();

      expect(items.whereType<BusPassItem>(), isNotEmpty);
      expect(mockBusPasses, isNotEmpty);
    });

    test('the bus face shares the train canvas so the cards frame alike', () {
      expect(BusPassMetrics.canvas, WalletCardMetrics.trainCanvas);
    });
  });
}
