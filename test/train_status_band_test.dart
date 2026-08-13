import 'package:docket/features/tickets/domain/ticket_models.dart';
import 'package:docket/features/tickets/presentation/train/train_status_band.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docket/features/tickets/presentation/train/train_pass_theme.dart';

/// 13 Aug 2026, 09:00 local — every expectation below is relative to this.
final DateTime _now = DateTime(2026, 8, 13, 9);

TrainPass _pass({
  String date = '13 Aug 2026',
  String departTime = '09:00',
  String? departAt,
  TicketStatus status = TicketStatus.active,
  TrainRunState runState = TrainRunState.scheduled,
  int? delayMinutes,
  List<TicketHalt> halts = const <TicketHalt>[],
}) {
  return TrainPass(
    id: 't',
    operator: 'IRCTC',
    trainNumber: '12932',
    trainName: 'Rajdhani Express',
    fromCode: 'HYB',
    fromName: 'Hyderabad',
    toCode: 'BLR',
    toName: 'Bengaluru',
    departTime: departTime,
    arriveTime: '17:00',
    date: date,
    arrivalDate: date,
    duration: '8h 00m',
    ticketClass: 'AC 2 Tier',
    passengers: const <TicketPassenger>[
      TicketPassenger(name: 'A', coach: 'B2', seat: '32', berth: 'Lower'),
    ],
    pnr: '1234567890',
    bookingId: 'B',
    status: status,
    runState: runState,
    delayMinutes: delayMinutes,
    departAt: departAt,
    halts: halts,
  );
}

List<String> _texts(TrainPass p, [DateTime? at]) =>
    resolveTrainBandMessages(p, at ?? _now)
        .map((TrainBandMessage m) => m.text)
        .toList();

void main() {
  group('resolveTrainBandMessages', () {
    test('a cancelled train says only that', () {
      final List<TrainBandMessage> out = resolveTrainBandMessages(
        _pass(
          runState: TrainRunState.cancelled,
          delayMinutes: 45,
          halts: const <TicketHalt>[
            TicketHalt(
              time: '09:00',
              station: 'HYB',
              dateLabel: '',
              state: HaltState.upcoming,
              platform: 'PF 5',
            ),
          ],
        ),
        _now,
      );

      // A platform or countdown next to "Cancelled" would be actively harmful.
      expect(out, hasLength(1));
      expect(out.single.text, 'Cancelled');
      expect(out.single.tone, TrainBandTone.critical);
    });

    test('an arrived or expired pass collapses to one neutral line', () {
      expect(
        _texts(_pass(runState: TrainRunState.arrived)),
        <String>['Journey complete'],
      );
      expect(
        _texts(_pass(status: TicketStatus.expired)),
        <String>['Journey complete'],
      );
    });

    test('a delay leads, and reads in hours past an hour', () {
      expect(
        _texts(
          _pass(
            date: '17 Aug 2026',
            runState: TrainRunState.delayed,
            delayMinutes: 45,
          ),
        ).first,
        '45 mins delayed',
      );
      expect(
        _texts(_pass(delayMinutes: 75)).first,
        '1 hr 15 mins delayed',
      );
      expect(_texts(_pass(delayMinutes: 120)).first, '2 hrs delayed');
      expect(_texts(_pass(delayMinutes: 1)).first, '1 min delayed');
    });

    test('delayMinutes 0 is on schedule, not a delay', () {
      expect(
        _texts(_pass(delayMinutes: 0)),
        isNot(contains(contains('delayed'))),
      );
    });

    test('"On time" is only claimed when the backend says so', () {
      expect(_texts(_pass()), isNot(contains('On time')));
      expect(
        _texts(_pass(runState: TrainRunState.onTime)),
        contains('On time'),
      );
      // A delay outranks a stale onTime flag.
      expect(
        _texts(_pass(runState: TrainRunState.onTime, delayMinutes: 20)),
        isNot(contains('On time')),
      );
    });

    group('platform', () {
      List<String> withPlatform(String? raw) => _texts(
            _pass(
              halts: <TicketHalt>[
                TicketHalt(
                  time: '09:00',
                  station: 'HYB',
                  dateLabel: '',
                  state: HaltState.upcoming,
                  platform: raw,
                ),
              ],
            ),
          );

      test('normalises the halt label', () {
        expect(withPlatform('PF 3'), contains('Platform 3'));
        expect(withPlatform('3'), contains('Platform 3'));
        expect(withPlatform('Platform 4'), contains('Platform 4'));
      });

      test('is dropped when absent or blank', () {
        expect(withPlatform(null), isNot(contains(startsWith('Platform'))));
        expect(withPlatform('   '), isNot(contains(startsWith('Platform'))));
      });

      test('follows the train once it is underway', () {
        final List<String> out = _texts(
          _pass(
            halts: const <TicketHalt>[
              TicketHalt(
                time: '08:00',
                station: 'origin',
                dateLabel: '',
                state: HaltState.departed,
                platform: 'PF 1',
              ),
              TicketHalt(
                time: '11:00',
                station: 'next',
                dateLabel: '',
                state: HaltState.arriving,
                platform: 'PF 9',
              ),
            ],
          ),
        );
        expect(out, contains('Platform 9'));
        expect(out, isNot(contains('Platform 1')));
      });
    });

    group('countdown', () {
      String? countdownFor({
        required String date,
        required String departTime,
        String? departAt,
      }) {
        final List<String> out =
            _texts(_pass(date: date, departTime: departTime, departAt: departAt));
        return out.isEmpty ? null : out.first;
      }

      test('counts whole calendar days out', () {
        expect(
          countdownFor(date: '17 Aug 2026', departTime: '09:00'),
          '4 days to go',
        );
        // Late-evening departure tomorrow is still "Tomorrow", not "2 days".
        expect(
          countdownFor(date: '14 Aug 2026', departTime: '23:30'),
          'Tomorrow',
        );
      });

      test('switches to hours and minutes on the day', () {
        expect(
          countdownFor(date: '13 Aug 2026', departTime: '15:00'),
          'in 6 hours',
        );
        expect(
          countdownFor(date: '13 Aug 2026', departTime: '10:00'),
          'in 1 hour',
        );
        expect(
          countdownFor(date: '13 Aug 2026', departTime: '09:25'),
          'Departs in 25 min',
        );
      });

      test('holds "Boarding now" through the grace window, then stops', () {
        expect(
          countdownFor(date: '13 Aug 2026', departTime: '08:55'),
          'Boarding now',
        );
        // Twenty minutes past departure there is nothing left to count down.
        expect(countdownFor(date: '13 Aug 2026', departTime: '08:40'), isNull);
      });

      test('falls back to date + departTime when departAt is absent', () {
        // Midnight from the date alone would read "in 9 hours" early.
        expect(
          trainDepartureAt(_pass(date: '13 Aug 2026', departTime: '06:15 PM')),
          DateTime(2026, 8, 13, 18, 15),
        );
        expect(
          trainDepartureAt(_pass(date: '13 Aug 2026', departTime: '12:05 AM')),
          DateTime(2026, 8, 13, 0, 5),
        );
      });

      test('prefers the ISO field over the display strings', () {
        expect(
          trainDepartureAt(
            _pass(
              date: '01 Jan 2020',
              departTime: '03:00',
              departAt: '2026-08-16T07:10:00',
            ),
          ),
          DateTime(2026, 8, 16, 7, 10),
        );
      });

      test('an unparseable date yields no countdown rather than a wrong one', () {
        expect(trainDepartureAt(_pass(date: 'sometime soon')), isNull);
        expect(_texts(_pass(date: 'sometime soon')), isEmpty);
      });
    });

    test('orders delay, platform, countdown, on time', () {
      final List<String> out = _texts(
        _pass(
          date: '17 Aug 2026',
          runState: TrainRunState.onTime,
          delayMinutes: 15,
          halts: const <TicketHalt>[
            TicketHalt(
              time: '09:00',
              station: 'HYB',
              dateLabel: '',
              state: HaltState.upcoming,
              platform: 'PF 7',
            ),
          ],
        ),
      );
      expect(out, <String>['15 mins delayed', 'Platform 7', '4 days to go']);
    });
  });

  group('TrainStatusBand widget', () {
    Widget host(TrainPass pass, {Duration dwell = const Duration(seconds: 4)}) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 366,
              child: TrainStatusBand(
                pass: pass,
                colors: TrainPassColors.active,
                clock: () => _now,
                dwell: dwell,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('cycles between messages', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          _pass(date: '17 Aug 2026', runState: TrainRunState.onTime),
          dwell: const Duration(seconds: 2),
        ),
      );
      await tester.pump();

      expect(find.text('4 days to go'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(TrainStatusBand.fade);
      expect(find.text('On time'), findsOneWidget);

      // Tear the tree down so the cycle timer is cancelled before teardown.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('runs no timer for a single static message',
        (WidgetTester tester) async {
      await tester.pumpWidget(host(_pass(runState: TrainRunState.arrived)));
      await tester.pump();

      expect(find.text('Journey complete'), findsOneWidget);

      // If a periodic timer had been started, this test would fail teardown
      // with a pending-timer error even after the tree is gone.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a lone countdown still refreshes itself',
        (WidgetTester tester) async {
      // Only message: the countdown. Without a tick it would sit on the first
      // value forever, so the clock advances between pumps here.
      DateTime now = DateTime(2026, 8, 13, 9);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 366,
              child: TrainStatusBand(
                pass: _pass(date: '13 Aug 2026', departTime: '09:25'),
                colors: TrainPassColors.active,
                clock: () => now,
                dwell: const Duration(seconds: 1),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Departs in 25 min'), findsOneWidget);

      now = DateTime(2026, 8, 13, 9, 15);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(TrainStatusBand.fade);
      expect(find.text('Departs in 10 min'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('an empty message list leaves the ghost alone',
        (WidgetTester tester) async {
      await tester.pumpWidget(host(_pass(date: 'sometime soon')));
      await tester.pump();

      expect(find.text('IRCTC'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
