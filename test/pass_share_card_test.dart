import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:docket/features/tickets/domain/bus_pass_models.dart';
import 'package:docket/features/tickets/domain/movie_pass_models.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/ticket_models.dart';
import 'package:docket/features/tickets/presentation/movie/movie_ticket_chrome.dart';
import 'package:docket/features/tickets/presentation/movie/movie_ticket_face.dart';
import 'package:docket/features/tickets/presentation/pass_code_block.dart';
import 'package:docket/features/tickets/presentation/share/pass_share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

TrainPass _train({String? codePayload}) => TrainPass(
      id: 't',
      operator: 'IRCTC',
      trainNumber: '12658',
      trainName: 'KSR Bengaluru Express',
      fromCode: 'SBC',
      fromName: 'KSR Bengaluru',
      toCode: 'MAS',
      toName: 'MGR Chennai Central',
      departTime: '22:40',
      arriveTime: '06:15',
      date: '26 Aug 2026',
      arrivalDate: '27 Aug 2026',
      duration: '7h 35m',
      ticketClass: '3A',
      passengers: const <TicketPassenger>[
        TicketPassenger(
          name: 'Navadeep Naidu',
          coach: 'B2',
          seat: '41',
          berth: 'Lower',
        ),
      ],
      pnr: '1234567890',
      bookingId: 'IRCTC1234567890',
      status: TicketStatus.active,
      bookingStatus: 'CNF',
      chartStatus: 'Chart prepared',
      liveStatusLabel: 'On time',
      runState: TrainRunState.onTime,
      codePayload: codePayload,
    );

BusPass _bus({String? codePayload}) => BusPass(
      id: 'b',
      operator: 'redBus',
      boardingLocation: 'Bengaluru, Kempegowda Bus Station',
      dropLocation: 'Mysuru, Mysuru City Bus Stand',
      departTime: '08:30 AM',
      arriveTime: '11:45 AM',
      date: '20 Aug 2026',
      arrivalDate: '20 Aug 2026',
      status: TicketStatus.active,
      seatDetails: '12A',
      passengers: const <BusPassenger>[
        BusPassenger(name: 'Navadeep Naidu', seat: '12A'),
      ],
      bookingId: 'RB8842119',
      fromCity: 'Bengaluru',
      toCity: 'Mysuru',
      boardingPoint: 'Kempegowda Bus Station',
      platform: 'Platform 15',
      fare: '₹650',
      codePayload: codePayload,
    );

MoviePass _movie({
  String? codePayload,
  String? logoUrl,
  String? posterUrl,
  TicketStatus status = TicketStatus.active,
}) =>
    MoviePass(
      id: 'm',
      brand: MoviePassBrand.bookMyShow,
      movieTitle: 'Dune: Part Two',
      movieSubtitle: 'English',
      cinemaName: 'PVR INOX Phoenix Mall',
      cinemaAddress: 'Phoenix Marketcity, Whitefield, Bengaluru',
      screen: 'Screen 5 - IMAX',
      showDate: '26 Aug 2026',
      showTime: '9:45 PM',
      format: 'IMAX 2D',
      language: 'English',
      seats: const <MovieSeat>[MovieSeat(row: 'H', number: '14')],
      bookingId: 'BMS-8F2K9P1Q',
      orderId: 'ORD-99120',
      status: status,
      posterHint: MoviePosterHint.sciFi,
      codePayload: codePayload,
      logoUrl: logoUrl,
      posterUrl: posterUrl,
    );

/// Pumps the card inside a viewport big enough that nothing is clipped, which
/// is what the off-screen overlay gives it in the app.
Future<void> _pumpCard(WidgetTester tester, WalletPassItem item) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SingleChildScrollView(
          child: RepaintBoundary(child: PassShareCard(item: item)),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('PassShareCard QR', () {
    for (final (String kind, WalletPassItem Function(String?) build) in <
        (String, WalletPassItem Function(String?))>[
      ('train', (String? p) => TrainPassItem(_train(codePayload: p))),
      ('bus', (String? p) => BusPassItem(_bus(codePayload: p))),
      ('movie', (String? p) => MoviePassItem(_movie(codePayload: p))),
    ]) {
      testWidgets('$kind renders a real QR when a payload is present',
          (WidgetTester tester) async {
        await _pumpCard(tester, build('PAYLOAD-$kind'));

        // qr_flutter keeps its payload private, so the exact encoding is
        // covered where the mapping lives (pass_share_text_test). What matters
        // here is that a genuine QrImageView is what got drawn.
        expect(find.byKey(PassShareCard.qrKey), findsOneWidget);
        expect(find.byType(QrImageView), findsOneWidget);
      });

      testWidgets('$kind renders no code block at all without a payload',
          (WidgetTester tester) async {
        await _pumpCard(tester, build(null));

        expect(find.byKey(PassShareCard.qrKey), findsNothing);
        expect(find.byType(QrImageView), findsNothing);
      });

      testWidgets('$kind treats a blank payload the same as no payload',
          (WidgetTester tester) async {
        await _pumpCard(tester, build('   '));

        expect(find.byType(QrImageView), findsNothing);
      });
    }

    // The faces draw decorative code art of their own — a hardcoded 7x7 grid on
    // the train, a procedural painter on the movie. Neither encodes anything.
    // If one of those ever reached the exported image it would look scannable
    // and fail at a gate, which is the exact failure this feature must not ship.
    testWidgets('no decorative code art reaches the exported card',
        (WidgetTester tester) async {
      await _pumpCard(tester, MoviePassItem(_movie(codePayload: 'REAL')));
      expect(find.byType(PassCodeBlock), findsNothing);

      final Iterable<CustomPaint> painters =
          tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      for (final CustomPaint p in painters) {
        expect(p.painter, isNot(isA<TicketQrPainter>()));
        expect(p.foregroundPainter, isNot(isA<TicketQrPainter>()));
      }
    });
  });

  group('PassShareCard composition', () {
    testWidgets('is the same width whatever the pass kind',
        (WidgetTester tester) async {
      final List<double> widths = <double>[];
      for (final WalletPassItem item in <WalletPassItem>[
        TrainPassItem(_train(codePayload: 'A')),
        BusPassItem(_bus(codePayload: 'A')),
        MoviePassItem(_movie(codePayload: 'A')),
      ]) {
        await _pumpCard(tester, item);
        widths.add(tester.getSize(find.byType(PassShareCard)).width);
      }

      expect(widths.toSet(), hasLength(1));
      expect(widths.first, PassShareCard.exportWidth);
    });

    testWidgets('every face is drawn at the same box', (WidgetTester tester) async {
      final List<Size> sizes = <Size>[];
      for (final WalletPassItem item in <WalletPassItem>[
        TrainPassItem(_train()),
        BusPassItem(_bus()),
        MoviePassItem(_movie()),
      ]) {
        await _pumpCard(tester, item);
        sizes.add(tester.getSize(find.byKey(PassShareCard.faceKey)));
      }

      // Within a point: the train canvas aspect is a hair off the ticket one.
      for (final Size s in sizes) {
        expect(s.width, closeTo(sizes.first.width, 0.5));
        expect(s.height, closeTo(sizes.first.height, 1.5));
      }
    });

    // Glance density is what selects the transparent title logo over the 2:3
    // one-sheet. Exporting the poster instead would multiply the PNG's size,
    // which is the whole reason for the choice.
    testWidgets('movie face is glance density, so it uses the title logo',
        (WidgetTester tester) async {
      await _pumpCard(tester, MoviePassItem(_movie()));

      final MovieTicketFace face =
          tester.widget<MovieTicketFace>(find.byType(MovieTicketFace));
      expect(face.density, MovieTicketDensity.glance);
    });

    testWidgets('an expired pass still exports in its live brand colours',
        (WidgetTester tester) async {
      await _pumpCard(
        tester,
        MoviePassItem(_movie(status: TicketStatus.expired)),
      );

      final MovieTicketFace face =
          tester.widget<MovieTicketFace>(find.byType(MovieTicketFace));
      expect(face.useBrandColors, isTrue);
    });

    testWidgets('nothing in the card is tappable', (WidgetTester tester) async {
      await _pumpCard(tester, MoviePassItem(_movie(codePayload: 'A')));

      final MovieTicketFace face =
          tester.widget<MovieTicketFace>(find.byType(MovieTicketFace));
      expect(face.onOpenCodes, isNull);
    });
  });

  group('capture', () {
    // The failure this guards is silent: a boundary that is laid out but never
    // painted still hands back an image, just a blank one. Nothing throws.
    testWidgets('rasterises to non-empty PNG bytes', (WidgetTester tester) async {
      await _pumpCard(tester, TrainPassItem(_train(codePayload: 'CAPTURE')));

      final RenderRepaintBoundary boundary = tester.renderObject(
        find.ancestor(
          of: find.byType(PassShareCard),
          matching: find.byType(RepaintBoundary),
        ).first,
      );

      late Uint8List bytes;
      await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
        final ByteData? data =
            await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        bytes = data!.buffer.asUint8List();
      });

      // PNG magic number, then something substantial after it.
      expect(
        bytes.sublist(0, 8),
        <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
      );
      expect(bytes.length, greaterThan(1000));
    });
  });
}
