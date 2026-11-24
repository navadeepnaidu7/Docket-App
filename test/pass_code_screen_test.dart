import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/features/tickets/data/mock_flight_fixtures.dart';
import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/domain/bus_pass_models.dart';
import 'package:docket/features/tickets/domain/flight_pass_models.dart';
import 'package:docket/features/tickets/domain/movie_pass_models.dart';
import 'package:docket/features/tickets/domain/pass_code.dart';
import 'package:docket/features/tickets/domain/ticket_models.dart';
import 'package:docket/features/tickets/presentation/bus/bus_pass_detail_screen.dart';
import 'package:docket/features/tickets/presentation/bus/bus_ticket_code_screen.dart';
import 'package:docket/features/tickets/presentation/flight/flight_pass_detail_screen.dart';
import 'package:docket/features/tickets/presentation/flight/flight_ticket_code_screen.dart';
import 'package:docket/features/tickets/presentation/movie/movie_ticket_code_screen.dart';
import 'package:docket/features/tickets/presentation/movie_pass_detail_screen.dart';
import 'package:docket/features/tickets/presentation/pass_code_row.dart';
import 'package:docket/features/tickets/presentation/pass_code_screen.dart';
import 'package:docket/features/tickets/presentation/pass_code_view.dart';
import 'package:docket/features/tickets/presentation/ticket_detail_screen.dart';
import 'package:docket/features/tickets/presentation/train/train_ticket_code_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

List<
  ({String kind, Widget scan, Widget detail, String reference, String label})
>
cases({bool hasCode = true}) {
  Map<String, dynamic> fields(Map<String, dynamic> json) => <String, dynamic>{
    ...json,
    'codePayload': hasCode ? 'SCAN-ORIGINAL' : null,
    'codePayloadBase64': null,
    'codeFormat': 'code128',
    'posterUrl': null,
    'logoUrl': null,
  };
  final TrainPass train = TrainPass.fromJson(
    fields(mockTrainPasses.first.toJson()),
  );
  final MoviePass movie = MoviePass.fromJson(
    fields(mockMoviePasses.first.toJson()),
  );
  final BusPass bus = BusPass.fromJson(fields(mockBusPasses.first.toJson()));
  final FlightPass flight = FlightPass.fromJson(
    fields(mockFlightPasses.first.toJson()),
  );
  return [
    (
      kind: 'train',
      scan: TrainTicketCodeScreen(ticket: train),
      detail: TicketDetailScreen(ticket: train),
      reference: train.pnr,
      label: 'PNR',
    ),
    (
      kind: 'movie',
      scan: MovieTicketCodeScreen(pass: movie),
      detail: MoviePassDetailScreen(pass: movie),
      reference: movie.bookingId,
      label: 'Booking ID',
    ),
    (
      kind: 'bus',
      scan: BusTicketCodeScreen(pass: bus),
      detail: BusPassDetailScreen(pass: bus),
      reference: bus.bookingId,
      label: 'Booking ID',
    ),
    (
      kind: 'flight',
      scan: FlightTicketCodeScreen(pass: flight),
      detail: FlightPassDetailScreen(pass: flight),
      reference: flight.bookingRef,
      label: 'PNR',
    ),
  ];
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.lightTheme, home: child),
      ),
    );
    // Drain mock repository hydration started by the detail action controls.
    await tester.pump(const Duration(milliseconds: 500));
  }

  for (final c in cases()) {
    testWidgets('${c.kind} shares viewer and preserves code and reference', (
      tester,
    ) async {
      await pump(tester, c.scan);
      expect(find.byType(PassCodeScreen), findsOneWidget);
      expect(find.text(c.reference), findsOneWidget);
      expect(find.text(c.label), findsOneWidget);
      final code = tester.widget<PassCodeView>(find.byType(PassCodeView)).code;
      expect(code.format, PassCodeFormat.code128);
      expect(code.text, 'SCAN-ORIGINAL');
      expect(tester.takeException(), isNull);
    });

    testWidgets('${c.kind} scan row opens fullscreen and closes to details', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.reset);
      await pump(tester, c.detail);
      await tester.scrollUntilVisible(
        find.byType(PassCodeRow).hitTestable(),
        350,
      );
      await tester.tap(find.byType(PassCodeRow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PassCodeScreen), findsOneWidget);
      final context = tester.element(find.byType(PassCodeScreen));
      final route = ModalRoute.of(context)! as MaterialPageRoute<void>;
      expect(route.fullscreenDialog, isTrue);
      await tester.tap(find.byType(CloseButton).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PassCodeScreen), findsNothing);
      expect(find.byType(PassCodeRow), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final c in cases(hasCode: false)) {
    testWidgets('${c.kind} omits scan affordance without genuine data', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 2400);
      addTearDown(tester.view.reset);
      await pump(tester, c.detail);
      expect(find.byType(PassCodeRow), findsNothing);
      await pump(tester, c.scan);
      expect(find.byType(PassCodeView), findsNothing);
      expect(find.text('This ticket has no scannable code'), findsOneWidget);
      expect(find.text(c.reference), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final format in ['qr', 'aztec', 'dataMatrix', 'pdf417', 'code128']) {
    testWidgets('$format fits narrow screen with large text and scrolls', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(280, 480);
      addTearDown(tester.view.reset);
      await pump(
        tester,
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: PassCodeScreen(
            code: PassCode.parse(payload: 'ORIGINAL-12345', format: format),
            title: 'A long journey title that needs several lines',
            subtitle: '26 November 2026 · 10:15 PM',
            reference: 'REFERENCE-1234567890',
          ),
        ),
      );
      final Rect plate = tester.getRect(find.byType(PassCodePlate));
      expect(plate.left, greaterThanOrEqualTo(24));
      expect(plate.right, lessThanOrEqualTo(256));
      await tester.ensureVisible(find.text('REFERENCE-1234567890'));
      await tester.pump();
      expect(find.text('REFERENCE-1234567890').hitTestable(), findsOneWidget);
      expect(find.byType(CloseButton).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
