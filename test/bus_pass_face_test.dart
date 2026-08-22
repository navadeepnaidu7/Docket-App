import 'package:docket/core/wallet/wallet_card_metrics.dart';
import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/data/mock_pass_repository.dart';
import 'package:docket/features/tickets/domain/bus_pass_models.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_status.dart';
import 'package:docket/features/tickets/presentation/bus/bus_brand_style.dart';
import 'package:docket/features/tickets/presentation/bus/bus_pass_theme.dart';
import 'package:docket/features/tickets/presentation/bus/bus_ticket_face.dart';
import 'package:flutter/material.dart';
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
  String? departAt = '2026-08-20T08:30:00',
  String? arriveAt = '2026-08-20T11:45:00',
  String date = '20 Aug 2026',
  String arrivalDate = '20 Aug 2026',
  String seatDetails = '12A',
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
    departTime: '08:30 AM',
    arriveTime: '11:45 AM',
    date: date,
    arrivalDate: arrivalDate,
    departAt: departAt,
    arriveAt: arriveAt,
    seatDetails: seatDetails,
    fare: fare,
    passengers: const <BusPassenger>[
      BusPassenger(name: 'Navadeep Naidu', seat: '12A'),
    ],
    bookingId: 'RB8842119',
    status: status,
  );
}

Future<void> _pumpFace(WidgetTester tester, BusPass pass) async {
  // The default 800x600 test surface is shorter than the 620dp canvas, which
  // silently clamps the card and makes an overflow assertion meaningless.
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
            child: BusTicketFace(pass: pass),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('layout', () {
    testWidgets('lays out inside its canvas without overflowing',
        (WidgetTester tester) async {
      await _pumpFace(tester, _pass());
      expect(tester.takeException(), isNull);

      final Size size = tester.getSize(find.byType(BusTicketFace));
      expect(size.width, BusPassMetrics.width);
      expect(size.height, BusPassMetrics.height);
    });

    // The body is the half that can run out of room: five stacked rows, two of
    // which carry free text from an operator.
    testWidgets('survives long stops, a long operator and no fare',
        (WidgetTester tester) async {
      await _pumpFace(
        tester,
        _pass(
          operator: 'Thiruvananthapuram Interstate Coach Services Limited',
          brand: null,
          boarding: 'Thiruvananthapuram, Central Bus Station East Wing Bay 22',
          drop: 'Kanyakumari, Vivekananda Kendra Junction Stand',
          boardingPoint: '',
          fare: '',
          platform: '',
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('brand', () {
    test('resolves redBus from an explicit brand and from the operator name',
        () {
      expect(_pass().resolvedBrand, BusPassBrand.redBus);
      expect(
        _pass(brand: null, operator: 'redBus').resolvedBrand,
        BusPassBrand.redBus,
      );
      // Operators write it every which way; an exact match would miss these.
      expect(
        _pass(brand: null, operator: 'Red Bus').resolvedBrand,
        BusPassBrand.redBus,
      );
    });

    test('an unknown operator falls to universal, not to redBus chrome', () {
      final BusPass p = _pass(brand: null, operator: 'KSRTC Airavat');
      expect(p.resolvedBrand, BusPassBrand.universal);

      final BusBrandStyle style = BusBrandStyle.forPass(p);
      expect(style.headerGradient, isNot(BusBrandStyle.redBus.headerGradient));
      expect(style.coachAsset, isNull);
    });

    // A spent ticket keeps the operator's wordmark and coach so it is still
    // recognisably theirs, but loses the colour.
    test('expired drains the colour and keeps the wordmark', () {
      final BusBrandStyle style =
          BusBrandStyle.forPass(_pass(status: TicketStatus.expired));

      expect(style.headerGradient, isNot(BusBrandStyle.redBus.headerGradient));
      expect(style.wordmarkLead, BusBrandStyle.redBus.wordmarkLead);
      expect(style.wordmarkTail, BusBrandStyle.redBus.wordmarkTail);
      expect(style.coachAsset, BusBrandStyle.redBus.coachAsset);
    });

    test('useBrandColors overrides the expiry drain', () {
      final BusBrandStyle style = BusBrandStyle.forPass(
        _pass(status: TicketStatus.expired),
        useBrandColors: true,
      );
      expect(style.headerGradient, BusBrandStyle.redBus.headerGradient);
    });
  });

  group('stops', () {
    testWidgets('sets the station large and the city under it',
        (WidgetTester tester) async {
      await _pumpFace(tester, _pass());

      expect(find.text('Kempegowda Bus Station'), findsWidgets);
      expect(find.text('Mysuru City Bus Stand'), findsOneWidget);
      expect(find.text('Bengaluru'), findsOneWidget);
    });

    // "Mangaluru" has no comma, so station and city resolve to the same
    // string. Printing it on both lines looks like a bug.
    testWidgets('does not print the city twice when the stop has no comma',
        (WidgetTester tester) async {
      await _pumpFace(
        tester,
        _pass(drop: 'Mangaluru', toCity: 'Mangaluru'),
      );
      expect(find.text('Mangaluru'), findsOneWidget);
    });

    testWidgets('the header states the city pair', (WidgetTester tester) async {
      await _pumpFace(tester, _pass());
      expect(find.textContaining('Bengaluru'), findsWidgets);
      expect(find.textContaining('Mysuru'), findsWidgets);
    });
  });

  group('body fields', () {
    testWidgets('shows date, departure, seat, platform and fare',
        (WidgetTester tester) async {
      await _pumpFace(tester, _pass());

      expect(find.text('20 Aug 2026'), findsOneWidget);
      expect(find.text('08:30 AM'), findsOneWidget);
      expect(find.text('12A'), findsOneWidget);
      expect(find.text('Platform 15'), findsOneWidget);
      expect(find.text('₹650'), findsOneWidget);
    });

    // An expired pass must not tell you to be somewhere 30 minutes early.
    testWidgets('the advisory changes once the journey is done',
        (WidgetTester tester) async {
      await _pumpFace(tester, _pass());
      expect(find.textContaining('30 minutes'), findsOneWidget);

      await _pumpFace(tester, _pass(status: TicketStatus.expired));
      expect(find.textContaining('30 minutes'), findsNothing);
    });
  });

  group('derived journey values', () {
    test('duration comes from the ISO instants', () {
      expect(busDurationLabel(_pass()), '3h 15m');
    });

    // The display times carry no date, so an overnight run computed from them
    // alone would come out negative. Absent instants must yield nothing.
    test('duration is empty without ISO instants', () {
      expect(busDurationLabel(_pass(departAt: null, arriveAt: null)), '');
    });

    test('a whole-hour trip drops the minutes', () {
      expect(
        busDurationLabel(
          _pass(
            departAt: '2026-08-20T22:00:00',
            arriveAt: '2026-08-21T06:00:00',
          ),
        ),
        '8h',
      );
    });

    test('the overnight offset counts calendar days, with a date fallback', () {
      expect(busArrivalDayOffset(_pass()), 0);
      expect(
        busArrivalDayOffset(
          _pass(
            departAt: '2026-08-20T22:00:00',
            arriveAt: '2026-08-21T06:00:00',
          ),
        ),
        1,
      );
      expect(
        busArrivalDayOffset(
          _pass(
            departAt: null,
            arriveAt: null,
            date: '20 Aug 2026',
            arrivalDate: '21 Aug 2026',
          ),
        ),
        1,
      );
    });
  });

  group('json', () {
    test('the new fields round-trip and stay optional', () {
      final BusPass p = _pass();
      final BusPass back = BusPass.fromJson(p.toJson());

      expect(back.resolvedBrand, BusPassBrand.redBus);
      expect(back.fromCity, 'Bengaluru');
      expect(back.boardingPoint, 'Kempegowda Bus Station');
      expect(back.platform, 'Platform 15');
      expect(back.fare, '₹650');

      // A payload from before these fields existed must still parse.
      final BusPass legacy = BusPass.fromJson(<String, dynamic>{
        'id': 'x',
        'operator': 'redBus',
        'boardingLocation': 'Bengaluru, Kempegowda Bus Station',
        'dropLocation': 'Mysuru, Mysuru City Bus Stand',
        'status': 'active',
      });
      expect(legacy.fare, '');
      expect(legacy.platform, '');
      expect(legacy.resolvedBrand, BusPassBrand.redBus);
      expect(legacy.resolvedFromCity, 'Bengaluru');
    });
  });

  group('wallet wiring', () {
    test('the mock repository serves bus passes', () async {
      final List<WalletPassItem> items =
          await MockPassRepository(artificialDelay: Duration.zero)
              .fetchPasses();

      expect(items.whereType<BusPassItem>(), isNotEmpty);
      expect(mockBusPasses, isNotEmpty);
    });

    test('the bus face shares the movie canvas so the cards frame alike', () {
      expect(BusPassMetrics.canvas, WalletCardMetrics.ticketCanvas);
      expect(BusPassMetrics.width, WalletCardMetrics.ticketCanvasWidth);
      expect(BusPassMetrics.height, WalletCardMetrics.ticketCanvasHeight);
    });
  });
}
