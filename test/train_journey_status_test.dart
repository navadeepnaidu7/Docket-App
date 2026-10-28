import 'package:docket/features/tickets/domain/ticket_models.dart';
import 'package:docket/features/tickets/presentation/train/train_journey_status.dart';
import 'package:flutter_test/flutter_test.dart';

TrainPass _pass({
  String date = '16 Aug 2026',
  String arrivalDate = '16 Aug 2026',
  String departTime = '07:10',
  String arriveTime = '14:40',
  String? departAt,
  TicketStatus status = TicketStatus.active,
  TrainRunState runState = TrainRunState.scheduled,
  int? delayMinutes,
  String bookingStatus = 'Confirmed',
  String chartStatus = '',
  double progressFraction = 0,
  List<TicketHalt> halts = const <TicketHalt>[],
  String trainNumber = '12932',
}) {
  return TrainPass(
    id: 't',
    operator: 'IRCTC',
    trainNumber: trainNumber,
    trainName: 'Rajdhani Express',
    fromCode: 'HYB',
    fromName: 'Hyderabad',
    toCode: 'BLR',
    toName: 'Bengaluru',
    departTime: departTime,
    arriveTime: arriveTime,
    date: date,
    arrivalDate: arrivalDate,
    departAt: departAt,
    duration: '7h 30m',
    ticketClass: 'AC 2 Tier',
    passengers: const <TicketPassenger>[
      TicketPassenger(name: 'N', coach: 'B2', seat: '32', berth: 'Lower'),
    ],
    pnr: '1234567890',
    bookingId: 'B',
    status: status,
    runState: runState,
    delayMinutes: delayMinutes,
    bookingStatus: bookingStatus,
    chartStatus: chartStatus,
    progressFraction: progressFraction,
    halts: halts,
  );
}

TicketHalt _halt(String station, HaltState state, {String time = '11:00'}) =>
    TicketHalt(time: time, station: station, dateLabel: '', state: state);

void main() {
  group('countdown', () {
    test('minutes inside the hour', () {
      final TrainJourneyStatus s = resolveTrainJourneyStatus(
        _pass(),
        DateTime(2026, 8, 16, 6, 45),
      );
      expect((s.lead, s.emphasis), ('Departs in', '25 min'));
    });

    test('hours and minutes on the day', () {
      final TrainJourneyStatus s = resolveTrainJourneyStatus(
        _pass(),
        DateTime(2026, 8, 16, 5, 0),
      );
      expect(s.emphasis, '2h 10m');
    });

    test('a short overnight wait stays in hours, not "tomorrow"', () {
      final TrainJourneyStatus s = resolveTrainJourneyStatus(
        _pass(),
        DateTime(2026, 8, 15, 22, 0),
      );
      expect(s.emphasis, '9h 10m');
    });

    test('tomorrow, then whole calendar days', () {
      expect(
        resolveTrainJourneyStatus(_pass(), DateTime(2026, 8, 15, 9)).emphasis,
        'tomorrow',
      );
      expect(
        resolveTrainJourneyStatus(_pass(), DateTime(2026, 8, 12, 23)).emphasis,
        '4 days',
      );
    });

    test('boarding through the grace window, then underway', () {
      expect(
        resolveTrainJourneyStatus(_pass(), DateTime(2026, 8, 16, 7, 15))
            .emphasis,
        'Boarding now',
      );
      expect(
        resolveTrainJourneyStatus(_pass(), DateTime(2026, 8, 16, 7, 25)).lead,
        'Arrives in',
      );
    });

    test('prefers the ISO field over the display strings', () {
      final TrainJourneyStatus s = resolveTrainJourneyStatus(
        _pass(departAt: '2026-08-16T09:10:00'),
        DateTime(2026, 8, 16, 9, 0),
      );
      expect(s.emphasis, '10 min');
    });

    test('an unparseable date falls back to the printed time', () {
      final TrainJourneyStatus s = resolveTrainJourneyStatus(
        _pass(date: 'someday', departTime: '07:10 PM'),
        DateTime(2026, 8, 16),
      );
      expect((s.lead, s.emphasis), ('Departs at', '19:10'));
    });
  });

  group('details', () {
    test('"on time" only when the backend says so', () {
      final DateTime now = DateTime(2026, 8, 16, 5);
      expect(resolveTrainJourneyStatus(_pass(), now).details, isEmpty);
      expect(
        resolveTrainJourneyStatus(
          _pass(runState: TrainRunState.onTime),
          now,
        ).detailText,
        'On time',
      );
    });

    test('a delay replaces "on time", is a warning, and shifts departure', () {
      final TrainJourneyStatus s = resolveTrainJourneyStatus(
        _pass(runState: TrainRunState.onTime, delayMinutes: 70),
        DateTime(2026, 8, 16, 5),
      );
      expect(s.details.first.text, 'running 1h 10m late');
      expect(s.details.first.tone, TrainStatusTone.warning);
      expect(s.departureShiftMinutes, 70);
      expect(s.arrivalShiftMinutes, isNull);
      // The countdown runs to the expected departure, not the scheduled one.
      expect(s.emphasis, '3h 20m');
    });

    test('delayMinutes 0 is on schedule, not a delay', () {
      final TrainJourneyStatus s = resolveTrainJourneyStatus(
        _pass(runState: TrainRunState.onTime, delayMinutes: 0),
        DateTime(2026, 8, 16, 5),
      );
      expect(s.detailText, 'On time');
      expect(s.departureShiftMinutes, isNull);
    });

    test('unconfirmed bookings and a prepared chart join the sentence', () {
      final TrainJourneyStatus s = resolveTrainJourneyStatus(
        _pass(
          runState: TrainRunState.onTime,
          bookingStatus: 'WL 12',
          chartStatus: 'Chart prepared',
        ),
        DateTime(2026, 8, 16, 5),
      );
      expect(s.detailText, 'On time, WL 12, chart prepared');
      expect(s.details[1].tone, TrainStatusTone.warning);
    });

    test('"chart not prepared" is noise and stays out', () {
      final TrainJourneyStatus s = resolveTrainJourneyStatus(
        _pass(chartStatus: 'Chart not prepared'),
        DateTime(2026, 8, 16, 5),
      );
      expect(s.details, isEmpty);
    });
  });

  group('underway', () {
    test('counts down to arrival and names the next stop', () {
      final TrainJourneyStatus s = resolveTrainJourneyStatus(
        _pass(
          halts: <TicketHalt>[
            _halt('Hyderabad', HaltState.departed, time: '07:10'),
            _halt('Kurnool City', HaltState.upcoming, time: '10:05 AM'),
          ],
        ),
        DateTime(2026, 8, 16, 9, 0),
      );
      expect((s.lead, s.emphasis), ('Arrives in', '5h 40m'));
      expect(s.detailText, 'Next stop Kurnool City at 10:05');
    });

    test('a delay moves arrival once the train has left', () {
      final TrainJourneyStatus s = resolveTrainJourneyStatus(
        _pass(delayMinutes: 20),
        DateTime(2026, 8, 16, 10, 0),
      );
      expect(s.arrivalShiftMinutes, 20);
      expect(s.departureShiftMinutes, isNull);
    });

    test('progress prefers the backend, else elapsed time', () {
      final DateTime now = DateTime(2026, 8, 16, 10, 55); // halfway
      expect(
        resolveTrainJourneyStatus(_pass(progressFraction: 0.3), now).progress,
        0.3,
      );
      expect(
        resolveTrainJourneyStatus(_pass(), now).progress,
        closeTo(0.5, 0.01),
      );
    });
  });

  group('terminal states', () {
    test('cancelled says only that, in the critical tone', () {
      final TrainJourneyStatus s = resolveTrainJourneyStatus(
        _pass(runState: TrainRunState.cancelled, delayMinutes: 30),
        DateTime(2026, 8, 16, 5),
      );
      expect(s.emphasis, 'Cancelled');
      expect(s.emphasisTone, TrainStatusTone.critical);
      expect(s.details, isEmpty);
    });

    test('arrived or expired shows the arrival with a full line', () {
      for (final TrainPass p in <TrainPass>[
        _pass(runState: TrainRunState.arrived),
        _pass(status: TicketStatus.expired),
      ]) {
        final TrainJourneyStatus s =
            resolveTrainJourneyStatus(p, DateTime(2026, 8, 20));
        expect((s.lead, s.emphasis), ('Arrived', '14:40'));
        expect(s.progress, 1);
      }
    });

    test('a PNR still waiting on its journey says so', () {
      final TrainJourneyStatus s = resolveTrainJourneyStatus(
        TrainPass.fromJson(<String, dynamic>{'id': 'x', 'pnr': '1234567890'}),
        DateTime(2026, 8, 16),
      );
      expect(s.emphasis, 'Fetching journey');
    });
  });

  group('formatting', () {
    test('trainClock24 converts meridiem times and wraps shifts', () {
      expect(trainClock24('07:10 AM'), '07:10');
      expect(trainClock24('12:05 AM'), '00:05');
      expect(trainClock24('02:40 PM'), '14:40');
      expect(trainClock24('23:50', shiftMinutes: 25), '00:15');
      expect(trainClock24('soon'), 'soon');
    });

    test('day offset reads calendar days between the two dates', () {
      expect(trainArrivalDayOffset(_pass(arrivalDate: '17 Aug 2026')), 1);
      expect(trainArrivalDayOffset(_pass()), 0);
      expect(trainArrivalDayOffset(_pass(arrivalDate: '')), 0);
    });
  });
}
