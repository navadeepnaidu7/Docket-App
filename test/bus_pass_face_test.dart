import 'package:docket/core/wallet/wallet_card_metrics.dart';
import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/data/mock_pass_repository.dart';
import 'package:docket/features/tickets/domain/bus_pass_models.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_status.dart';
import 'package:docket/features/tickets/presentation/bus/bus_pass_theme.dart';
import 'package:docket/features/tickets/presentation/bus/bus_ticket_face.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BusPass _pass({
  String boarding = 'Hyderabad, Miyapur Bay 12',
  String drop = 'Bengaluru, Madiwala Checkpost',
  String? departAt = '2026-08-20T22:30:00',
  String? arriveAt = '2026-08-21T06:45:00',
  String date = '20 Aug 2026',
  String arrivalDate = '21 Aug 2026',
  String seatDetails = 'L7, L8',
  TicketStatus status = TicketStatus.active,
  List<BusPassenger> passengers = const <BusPassenger>[
    BusPassenger(name: 'Navadeep Naidu', seat: 'L7'),
    BusPassenger(name: 'Ananya Rao', seat: 'L8'),
  ],
}) {
  return BusPass(
    id: 'b',
    operator: 'Orange Travels',
    boardingLocation: boarding,
    dropLocation: drop,
    departTime: '10:30 PM',
    arriveTime: '06:45 AM',
    date: date,
    arrivalDate: arrivalDate,
    departAt: departAt,
    arriveAt: arriveAt,
    seatDetails: seatDetails,
    passengers: passengers,
    bookingId: 'OT8842119',
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
  group('bus face layout', () {
    // The first-cut face used a Spacer inside a Column that was itself poured
    // into a fixed canvas, so it depended on the canvas being at least as tall
    // as its content. Pumping at the exact design size is what catches an
    // overflow, which otherwise only shows as a stripe on a device.
    testWidgets('lays out inside its canvas without overflowing',
        (WidgetTester tester) async {
      await _pumpFace(tester, _pass());
      expect(tester.takeException(), isNull);

      final Size size = tester.getSize(find.byType(BusTicketFace));
      expect(size.width, BusPassMetrics.width);
      expect(size.height, BusPassMetrics.height);
    });

    // A long single-segment place has no comma to split on, and a two-line
    // detail is the widest the block ever gets.
    testWidgets('survives places with no comma and long names',
        (WidgetTester tester) async {
      await _pumpFace(
        tester,
        _pass(
          boarding: 'Thiruvananthapuram Central Bus Station East Wing',
          drop: 'Kanyakumari',
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Kanyakumari'), findsOneWidget);
    });
  });

  group('place split', () {
    testWidgets('sets the city large and the landmark beneath it',
        (WidgetTester tester) async {
      await _pumpFace(tester, _pass());

      expect(find.text('Hyderabad'), findsOneWidget);
      expect(find.text('Miyapur Bay 12'), findsOneWidget);
      expect(find.text('Bengaluru'), findsOneWidget);
      expect(find.text('Madiwala Checkpost'), findsOneWidget);
    });

    testWidgets('keeps an uncommaed place whole rather than inventing a detail',
        (WidgetTester tester) async {
      await _pumpFace(tester, _pass(drop: 'Mangaluru'));
      expect(find.text('Mangaluru'), findsOneWidget);
    });
  });

  group('journey duration', () {
    testWidgets('is computed from the ISO instants', (WidgetTester tester) async {
      await _pumpFace(tester, _pass());
      expect(find.text('8h 15m'), findsOneWidget);
    });

    // The display times carry no date, so an overnight run computed from them
    // would come out negative. Absent instants must drop the label, not guess.
    testWidgets('is absent when the pass carries no ISO instants',
        (WidgetTester tester) async {
      await _pumpFace(tester, _pass(departAt: null, arriveAt: null));
      expect(find.text('8h 15m'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('drops a whole-hour trip to hours only',
        (WidgetTester tester) async {
      await _pumpFace(
        tester,
        _pass(
          departAt: '2026-08-20T22:00:00',
          arriveAt: '2026-08-21T06:00:00',
        ),
      );
      expect(find.text('8h'), findsOneWidget);
    });
  });

  group('overnight marker', () {
    testWidgets('marks an arrival that lands on the next day',
        (WidgetTester tester) async {
      await _pumpFace(tester, _pass());
      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('is absent on a same-day run', (WidgetTester tester) async {
      await _pumpFace(
        tester,
        _pass(
          departAt: '2026-08-20T08:00:00',
          arriveAt: '2026-08-20T14:00:00',
          arrivalDate: '20 Aug 2026',
        ),
      );
      expect(find.text('+1'), findsNothing);
    });

    // Falls back to the display dates when the ISO fields are missing, which is
    // what an extracted ticket without timestamps looks like.
    testWidgets('falls back to the display dates', (WidgetTester tester) async {
      await _pumpFace(tester, _pass(departAt: null, arriveAt: null));
      expect(find.text('+1'), findsOneWidget);
    });
  });

  group('palette', () {
    // The card is a paper facsimile: it must not follow the app theme, or it
    // becomes the only pass in the carousel that inverts in dark mode.
    test('is fixed-light and drains when expired', () {
      expect(
        BusPassColors.of(isExpired: false).surface,
        BusPassPalette.surface,
      );
      expect(
        BusPassColors.of(isExpired: false).accent,
        BusPassPalette.pine,
      );
      expect(
        BusPassColors.of(isExpired: true).accent,
        isNot(BusPassPalette.pine),
      );
    });
  });

  group('wallet wiring', () {
    // buildWalletPassCatalog has always accepted `buses:`, but the mock
    // repository never passed any, so a bus pass could not appear in the wallet
    // at all. That is a data gap no widget test would have caught.
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
