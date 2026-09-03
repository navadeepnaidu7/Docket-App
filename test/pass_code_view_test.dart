import 'dart:convert';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:docket/features/tickets/domain/bus_pass_models.dart';
import 'package:docket/features/tickets/domain/movie_pass_models.dart';
import 'package:docket/features/tickets/domain/pass_code.dart';
import 'package:docket/features/tickets/presentation/bus/bus_ticket_code_screen.dart';
import 'package:docket/features/tickets/presentation/movie/movie_ticket_code_screen.dart';
import 'package:docket/features/tickets/presentation/pass_code_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

MoviePass _movie({String? codePayload, String? codeFormat}) => MoviePass(
      id: 'm1',
      brand: MoviePassBrand.bookMyShow,
      movieTitle: 'Dune: Part Two',
      movieSubtitle: 'Sci-Fi',
      cinemaName: 'PVR INOX Phoenix',
      cinemaAddress: 'Whitefield, Bengaluru',
      screen: 'Screen 5',
      showDate: '26 Aug 2026',
      showTime: '09:30 PM',
      format: 'IMAX 2D',
      language: 'English',
      seats: const <MovieSeat>[MovieSeat(row: 'J', number: '05')],
      bookingId: 'BMS-99213',
      orderId: 'ORD-1',
      status: TicketStatus.active,
      codePayload: codePayload,
      codeFormat: codeFormat,
    );

BusPass _bus({String? codePayload}) => BusPass(
      id: 'b1',
      operator: 'redBus',
      boardingLocation: 'Bengaluru, Kempegowda Bus Station',
      dropLocation: 'Chennai, Koyambedu',
      departTime: '10:15 PM',
      arriveTime: '05:40 AM',
      date: '26 Aug 2026',
      arrivalDate: '27 Aug 2026',
      status: TicketStatus.active,
      seatDetails: '12A',
      passengers: const <BusPassenger>[
        BusPassenger(name: 'Navadeep Naidu', seat: '12A'),
      ],
      bookingId: 'RB-4471',
      fromCity: 'Bengaluru',
      toCity: 'Chennai',
      codePayload: codePayload,
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
}

void main() {
  group('PassCodeView', () {
    testWidgets('draws a QR through qr_flutter', (WidgetTester tester) async {
      await _pump(
        tester,
        Center(
          child: PassCodeView(
            code: PassCode.parse(payload: 'GATE-1', format: 'qr')!,
            width: 200,
          ),
        ),
      );

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.byType(BarcodeWidget), findsNothing);
    });

    // The whole reason the format travels with the payload: a Code 128 booking
    // reference re-rendered as a QR is a symbol no gate reads.
    testWidgets('draws a linear symbology as a barcode, not a QR',
        (WidgetTester tester) async {
      await _pump(
        tester,
        Center(
          child: PassCodeView(
            code: PassCode.parse(payload: 'GATE-1', format: 'code128')!,
            width: 200,
          ),
        ),
      );

      expect(find.byType(BarcodeWidget), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('renders a byte-mode QR from raw bytes',
        (WidgetTester tester) async {
      final PassCode code = PassCode.parse(
        payloadBase64: base64.encode(<int>[0x00, 0xC3, 0x28, 0xFF]),
        format: 'qr',
      )!;
      expect(code.isBinary, isTrue);

      await _pump(tester, Center(child: PassCodeView(code: code, width: 200)));

      expect(tester.takeException(), isNull);
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('keeps a matrix symbol square and a linear one a strip',
        (WidgetTester tester) async {
      await _pump(
        tester,
        Center(
          child: PassCodeView(
            code: PassCode.parse(payload: '12345678', format: 'dataMatrix')!,
            width: 200,
          ),
        ),
      );
      Size size = tester.getSize(find.byType(BarcodeWidget));
      expect(size.height, size.width);

      await _pump(
        tester,
        Center(
          child: PassCodeView(
            code: PassCode.parse(payload: '12345678', format: 'code39')!,
            width: 200,
          ),
        ),
      );
      size = tester.getSize(find.byType(BarcodeWidget));
      expect(size.height, lessThan(size.width));
    });
  });

  group('PassCodePlate', () {
    testWidgets('shows the empty label and no code when there is none',
        (WidgetTester tester) async {
      await _pump(
        tester,
        const Center(
          child: PassCodePlate(code: null, emptyLabel: 'Nothing to scan'),
        ),
      );

      expect(find.text('Nothing to scan'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.byType(BarcodeWidget), findsNothing);
    });
  });

  // The point of the feature. These screens used to paint a seeded 13x13 grid
  // that encoded nothing, which a user cannot tell from a real code until a
  // scanner rejects it. See docs/features/ticket-code-extraction.md.
  group('code screens draw the real code or none', () {
    testWidgets('movie renders the pass QR', (WidgetTester tester) async {
      await _pump(
        tester,
        MovieTicketCodeScreen(pass: _movie(codePayload: 'BMSQR-1')),
      );
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('movie renders a Code 128 strip when that is what it carries',
        (WidgetTester tester) async {
      await _pump(
        tester,
        MovieTicketCodeScreen(
          pass: _movie(codePayload: 'BMSQR-1', codeFormat: 'code128'),
        ),
      );
      expect(find.byType(BarcodeWidget), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('movie draws nothing scannable without a payload',
        (WidgetTester tester) async {
      await _pump(tester, MovieTicketCodeScreen(pass: _movie()));
      expect(find.byType(QrImageView), findsNothing);
      expect(find.byType(BarcodeWidget), findsNothing);
      expect(find.byType(PassCodeView), findsNothing);
    });

    testWidgets('bus renders the pass QR', (WidgetTester tester) async {
      await _pump(
        tester,
        BusTicketCodeScreen(pass: _bus(codePayload: 'RBQR-1')),
      );
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('bus draws nothing scannable without a payload',
        (WidgetTester tester) async {
      await _pump(tester, BusTicketCodeScreen(pass: _bus()));
      expect(find.byType(PassCodeView), findsNothing);
    });
  });
}
