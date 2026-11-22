import 'dart:convert';
import 'dart:typed_data';

import 'package:docket/core/wallet/wallet_card_metrics.dart';
import 'package:docket/features/tickets/data/mock_flight_fixtures.dart';
import 'package:docket/features/tickets/domain/bcbp.dart';
import 'package:docket/features/tickets/domain/flight_pass_models.dart';
import 'package:docket/features/tickets/presentation/flight/airline_logo.dart';
import 'package:docket/features/tickets/presentation/flight/flight_pass_detail_screen.dart';
import 'package:docket/features/tickets/presentation/flight/flight_ticket_face.dart';
import 'package:docket/features/tickets/presentation/flight/flight_updates_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpScreen(WidgetTester t, FlightPass pass) async {
    t.view.physicalSize = const Size(393, 2200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: FlightPassDetailScreen(pass: pass)),
      ),
    );
    await t.pump();
  }

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

  test('fixture codes are real boarding passes', () {
    for (final FlightPass f in mockFlightPasses) {
      final String? code = f.codePayload;
      if (code == null) continue;
      final BcbpPass? parsed = parseBcbp(code);
      expect(parsed, isNotNull, reason: f.id);
      expect(parsed!.legs.single.pnr, f.bookingRef, reason: f.id);
      expect(parsed.legs.single.from, f.origin.code, reason: f.id);
      expect(parsed.legs.single.to, f.destination.code, reason: f.id);
      expect(
        parsed.legs.single.displayFlightNumber,
        f.flightNumber,
        reason: f.id,
      );
    }
  });

  testWidgets('every fixture lays out without overflow', (
    WidgetTester t,
  ) async {
    for (final FlightPass f in mockFlightPasses) {
      await t.pumpWidget(host(FlightTicketFace(pass: f)));
      expect(t.takeException(), isNull, reason: f.id);
      expect(find.byKey(FlightTicketFace.originKey), findsOneWidget);
      // Each code is laid out twice: once visible, once invisibly to measure
      // the flight path between them.
      expect(
        find.descendant(
          of: find.byKey(FlightTicketFace.originKey),
          matching: find.text(f.origin.code),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(FlightTicketFace.destinationKey),
          matching: find.text(f.destination.code),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('codes sit on the shared edges', (WidgetTester t) async {
    await t.pumpWidget(host(FlightTicketFace(pass: mockFlightPasses.first)));
    final Rect face = t.getRect(find.byType(FlightTicketFace));
    final Rect from = t.getRect(find.byKey(FlightTicketFace.originKey));
    final Rect to = t.getRect(find.byKey(FlightTicketFace.destinationKey));
    expect(from.left - face.left, closeTo(25, 1.5));
    expect(face.right - to.right, closeTo(25, 1.5));
  });

  testWidgets('flight time sits between the codes, on their middle', (
    WidgetTester t,
  ) async {
    await t.pumpWidget(host(FlightTicketFace(pass: mockFlightPasses.first)));
    final Rect from = t.getRect(find.byKey(FlightTicketFace.originKey));
    final Rect to = t.getRect(find.byKey(FlightTicketFace.destinationKey));
    final Rect time = t.getRect(find.byKey(FlightTicketFace.durationKey));
    expect(time.left, greaterThanOrEqualTo(from.right));
    expect(time.right, lessThanOrEqualTo(to.left));
    final double middle = (time.top + time.bottom) / 2;
    expect(middle, inExclusiveRange(from.top, from.bottom));
  });

  testWidgets('a long gate narrows its flaps and keeps clear of the seat', (
    WidgetTester t,
  ) async {
    final FlightPass pass = FlightPass.fromJson(<String, dynamic>{
      ...mockFlightPasses[1].toJson(),
      'gate': 'B12A7',
    });
    await t.pumpWidget(host(FlightTicketFace(pass: pass)));
    expect(t.takeException(), isNull);
    final Rect gate = t.getRect(find.byKey(FlightTicketFace.gateKey));
    final Rect seat = t.getRect(find.text('Seat'));
    expect(gate.right, lessThan(seat.left));
  });

  testWidgets('the airline logo replaces the name once it loads', (
    WidgetTester t,
  ) async {
    const String svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 80 20">'
        '<rect width="80" height="20" fill="#000"/></svg>';
    AirlineLogos.debugLoader = (String code) async =>
        code == 'EK' ? Uint8List.fromList(utf8.encode(svg)) : null;
    addTearDown(() => AirlineLogos.debugLoader = null);
    final FlightPass emirates = FlightPass.fromJson(<String, dynamic>{
      ...mockFlightPasses[1].toJson(),
      'airline': 'Emirates',
      'airlineCode': 'EK',
      'flightNumber': 'EK 500',
    });
    await t.pumpWidget(host(FlightTicketFace(pass: emirates)));
    expect(find.text('Emirates'), findsOneWidget);
    await t.pumpAndSettle();
    expect(find.text('Emirates'), findsNothing);
    expect(find.bySemanticsLabel('Emirates'), findsOneWidget);
  });

  testWidgets('delayed fixture shows the revision and the new gate', (
    WidgetTester t,
  ) async {
    await t.pumpWidget(host(FlightTicketFace(pass: mockFlightPasses.first)));
    expect(
      find.descendant(
        of: find.byKey(FlightTicketFace.gateKey),
        matching: find.byType(Text),
      ),
      findsNWidgets(2),
    );
    expect(
      find.bySemanticsLabel('Gate 17'),
      findsOneWidget,
      reason: 'live gate wins',
    );
    expect(find.textContaining('Delayed'), findsOneWidget);
  });

  testWidgets('detail screen switches to Updates and lists the feed', (
    WidgetTester t,
  ) async {
    // No network or cache plugin in tests; the photo is not under test.
    FlightAircraftCard.debugPhotoBuilder = (_) => const SizedBox.expand();
    addTearDown(() => FlightAircraftCard.debugPhotoBuilder = null);
    await pumpScreen(t, mockFlightPasses.first);
    await t.tap(find.text('Updates'));
    // The map's live pulse repeats, so pump by time, never to idle.
    for (int i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Gate changed to 17'), findsOneWidget);
    expect(find.text('Was gate 12'), findsOneWidget);
    // Face, headline, departure row and the list all say it.
    expect(find.text('Delayed 25 min'), findsWidgets);
    expect(find.text('Gate 12 assigned'), findsOneWidget);
    expect(find.text('Aircraft found'), findsOneWidget);
    expect(find.text('Your aircraft'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a pass with no feed says so instead of inventing one', (
    WidgetTester t,
  ) async {
    await pumpScreen(t, mockFlightPasses[1]);
    await t.tap(find.text('Updates'));
    await t.pumpAndSettle();
    expect(find.textContaining('will appear here'), findsOneWidget);
    expect(find.textContaining('On time'), findsNothing);
  });
}
