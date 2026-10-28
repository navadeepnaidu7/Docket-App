import 'package:docket/features/tickets/domain/ticket_models.dart';
import 'package:docket/features/tickets/presentation/pass_code_block.dart';
import 'package:docket/features/tickets/presentation/train/train_pass_theme.dart';
import 'package:docket/features/tickets/presentation/train/train_ticket_face.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

TrainPass _pass({
  String fromName = 'Hyderabad',
  String toName = 'Bengaluru',
  String departTime = '07:10 AM',
  String arriveTime = '02:40 PM',
  String arrivalDate = '16 Aug 2026',
  TrainRunState runState = TrainRunState.scheduled,
  int? delayMinutes,
  String? codePayload,
}) {
  return TrainPass(
    id: 't',
    operator: 'IRCTC',
    trainNumber: '12932',
    trainName: 'Rajdhani Express',
    fromCode: 'HYB',
    fromName: fromName,
    toCode: 'BLR',
    toName: toName,
    departTime: departTime,
    arriveTime: arriveTime,
    date: '16 Aug 2026',
    arrivalDate: arrivalDate,
    duration: '7h 30m',
    ticketClass: 'AC 2 Tier',
    passengers: const <TicketPassenger>[
      TicketPassenger(
        name: 'Navadeep Naidu',
        coach: 'B2',
        seat: '32',
        berth: 'Lower',
      ),
    ],
    pnr: '1234567890',
    bookingId: 'B',
    status: TicketStatus.active,
    runState: runState,
    delayMinutes: delayMinutes,
    codePayload: codePayload,
  );
}

Future<void> _pumpFace(WidgetTester tester, TrainPass pass) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: TrainPassMetrics.width,
            height: TrainPassMetrics.height,
            child: TrainTicketFace(
              ticket: pass,
              density: TrainTicketDensity.glance,
              clock: () => DateTime(2026, 8, 13, 9),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The visible time behind [key]. `find.text` would also match the invisible
/// copies the face lays out to size the route rule.
String? _time(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data;

void main() {
  // Real Geist, from the bundled assets, so geometry checks measure the face as
  // it ships rather than the test font's full-em boxes.
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    TrainPassType.warmUp();
    for (final FontWeight w in <FontWeight>[
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
    ]) {
      GoogleFonts.geist(fontWeight: w);
    }
    await GoogleFonts.pendingFonts();
  });

  testWidgets('prints 24-hour times, the class code and sentence-case labels', (
    tester,
  ) async {
    await _pumpFace(tester, _pass());

    expect(_time(tester, TrainTicketFace.departureKey), '07:10');
    expect(_time(tester, TrainTicketFace.arrivalKey), '14:40');
    expect(find.text('2A'), findsOneWidget);
    expect(find.text('32 Lower'), findsOneWidget);
    expect(find.text('Sun, 16 Aug'), findsOneWidget);
    for (final String label in <String>[
      'Coach',
      'Berth',
      'Class',
      'Passengers',
      'Platform',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('draws no code of any kind', (tester) async {
    await _pumpFace(tester, _pass(codePayload: 'REAL'));
    expect(find.byType(PassCodeBlock), findsNothing);
  });

  testWidgets('an overnight arrival carries a day marker', (tester) async {
    await _pumpFace(
      tester,
      _pass(
        departTime: '16:55',
        arriveTime: '08:35',
        arrivalDate: '17 Aug 2026',
      ),
    );
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('a same-day arrival has none', (tester) async {
    await _pumpFace(tester, _pass());
    expect(find.textContaining('+'), findsNothing);
  });

  group('time alignment', () {
    // The two times are the widest things on the card; their boxes must stay
    // within a few dp of the content edges, which is where the city names and
    // codes above and below them start and end.
    testWidgets('times sit on the content edges', (tester) async {
      await _pumpFace(tester, _pass(departTime: '16:55', arriveTime: '08:35'));
      final Rect card = tester.getRect(find.byType(TrainTicketFace));
      final Rect dep = tester.getRect(find.byKey(TrainTicketFace.departureKey));
      final Rect arr = tester.getRect(find.byKey(TrainTicketFace.arrivalKey));

      expect(
        dep.left - card.left,
        moreOrLessEquals(TrainPassMetrics.inset, epsilon: 3),
      );
      expect(
        card.right - arr.right,
        moreOrLessEquals(TrainPassMetrics.inset, epsilon: 3),
      );
    });

    testWidgets('the route rule spans the gap between the times', (
      tester,
    ) async {
      await _pumpFace(tester, _pass(departTime: '16:55', arriveTime: '08:35'));
      final Rect dep = tester.getRect(find.byKey(TrainTicketFace.departureKey));
      final Rect arr = tester.getRect(find.byKey(TrainTicketFace.arrivalKey));
      final Rect rule = tester.getRect(find.byKey(TrainTicketFace.routeKey));

      expect(rule.left, greaterThan(dep.right));
      expect(rule.right, lessThan(arr.left));
      expect(rule.width, greaterThan(20));
    });
  });

  testWidgets('a known delay moves the departure and strikes the schedule', (
    tester,
  ) async {
    await _pumpFace(
      tester,
      _pass(runState: TrainRunState.delayed, delayMinutes: 25),
    );
    expect(_time(tester, TrainTicketFace.departureKey), '07:35');
    expect(find.text('07:10'), findsOneWidget); // struck, beside the code
    final Text struck = tester.widget<Text>(find.text('07:10'));
    expect(struck.style?.decoration, TextDecoration.lineThrough);
  });

  _backendPayloadTests();
}

// ── Backend payload resilience ────────────────────────────────────────────────

/// Collects overflow/assertion errors raised while rendering.
Future<List<String>> _renderAndCollect(
  WidgetTester tester,
  TrainPass pass,
) async {
  final List<String> errors = <String>[];
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails d) => errors.add(d.toString());
  await _pumpFace(tester, pass);
  FlutterError.onError = previous;
  return errors;
}

void _backendPayloadTests() {
  group('renders a backend payload', () {
    test('unknown runState degrades to scheduled, not a crash', () {
      final TrainPass p = TrainPass.fromJson(<String, dynamic>{
        'id': 'x',
        'runState': 'signal_failure_at_junction',
      });
      expect(p.runState, TrainRunState.scheduled);
    });

    test('delayMinutes survives a stringly-typed backend', () {
      expect(
        TrainPass.fromJson(<String, dynamic>{
          'delayMinutes': '45',
        }).delayMinutes,
        45,
      );
      expect(
        TrainPass.fromJson(<String, dynamic>{
          'delayMinutes': 45.0,
        }).delayMinutes,
        45,
      );
      // Garbage is unknown, not zero.
      expect(
        TrainPass.fromJson(<String, dynamic>{
          'delayMinutes': 'soon',
        }).delayMinutes,
        isNull,
      );
      expect(TrainPass.fromJson(<String, dynamic>{}).delayMinutes, isNull);
    });

    testWidgets('a near-empty payload renders without overflow', (
      WidgetTester tester,
    ) async {
      // Everything optional omitted: no codes, no names, no passengers, no
      // halts, no dates. fromJson has to fill the gaps and the face has to
      // draw something honest rather than blanks or a red box.
      final TrainPass sparse = TrainPass.fromJson(<String, dynamic>{'id': 'x'});

      final List<String> errors = await _renderAndCollect(tester, sparse);
      expect(errors, isEmpty, reason: errors.join(' | '));
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('overlong strings ellipsize instead of overflowing', (
      WidgetTester tester,
    ) async {
      final TrainPass wordy = TrainPass.fromJson(<String, dynamic>{
        'id': 'x',
        'trainName': 'Chhatrapati Shivaji Maharaj Terminus Rajdhani Superfast',
        'fromName': 'Kaziranga National Park Halt Junction',
        'toName': 'Thiruvananthapuram Central Junction',
        'ticketClass': 'Air Conditioned Three Tier Economy Sleeper',
        'pnr': '1234567890',
        'date': '16 Aug 2026',
        'duration': '27h 45m',
        'passengers': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Venkataraman Subrahmanyan Chandrasekhar',
            'coach': 'B12',
            'seat': '64',
            'berth': 'Side Upper',
          },
          <String, dynamic>{'name': 'A', 'coach': 'B13', 'seat': '65'},
        ],
      });

      final List<String> errors = await _renderAndCollect(tester, wordy);
      expect(errors, isEmpty, reason: errors.join(' | '));
    });

    testWidgets('a full payload drives the status sentence', (
      WidgetTester tester,
    ) async {
      final TrainPass live = TrainPass.fromJson(<String, dynamic>{
        'id': 'x',
        'fromCode': 'HYB',
        'toCode': 'BLR',
        'date': '16 Aug 2026',
        'departTime': '07:10 AM',
        'runState': 'delayed',
        'delayMinutes': 45,
        'halts': <Map<String, dynamic>>[
          <String, dynamic>{
            'time': '07:10',
            'station': 'Hyderabad',
            'state': 'upcoming',
            'platform': 'PF 5',
          },
        ],
      });

      final List<String> errors = await _renderAndCollect(tester, live);
      expect(errors, isEmpty, reason: errors.join(' | '));
      expect(find.text('5'), findsOneWidget); // platform, prefix stripped
      expect(
        find.textContaining('Running 45 min late', findRichText: true),
        findsOneWidget,
      );
    });
  });
}
