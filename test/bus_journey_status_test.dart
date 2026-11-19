import 'package:docket/features/tickets/domain/bus_pass_models.dart';
import 'package:docket/features/tickets/domain/pass_status.dart';
import 'package:docket/features/tickets/presentation/bus/bus_journey_status.dart';
import 'package:flutter_test/flutter_test.dart';

BusPass _pass({
  String departTime = '08:30 AM',
  String arriveTime = '11:45 AM',
  String? departAt = '2026-08-20T08:30:00',
  String? arriveAt = '2026-08-20T11:45:00',
  String date = '20 Aug 2026',
  String arrivalDate = '20 Aug 2026',
  TicketStatus status = TicketStatus.active,
}) {
  return BusPass(
    id: 'b',
    operator: 'redBus',
    boardingLocation: 'Bengaluru, Kempegowda Bus Station',
    dropLocation: 'Mysuru, Mysuru City Bus Stand',
    departTime: departTime,
    arriveTime: arriveTime,
    date: date,
    arrivalDate: arrivalDate,
    departAt: departAt,
    arriveAt: arriveAt,
    status: status,
  );
}

BusPass _overnight() => _pass(
  departTime: '11:15 PM',
  arriveTime: '05:30 AM',
  departAt: '2026-08-20T23:15:00',
  arriveAt: '2026-08-21T05:30:00',
  arrivalDate: '21 Aug 2026',
);

String _line(BusJourneyStatus s) =>
    s.lead.isEmpty ? s.emphasis : '${s.lead} ${s.emphasis}';

void main() {
  group('before departure', () {
    test('days away', () {
      final BusJourneyStatus s = resolveBusJourneyStatus(
        _pass(),
        DateTime(2026, 8, 18, 10),
      );
      expect(_line(s), 'Departs in 2 days');
      expect(s.detail, isEmpty);
      expect(s.progress, 0);
    });

    test('tomorrow, once the wait is past 12 hours', () {
      expect(
        _line(resolveBusJourneyStatus(_pass(), DateTime(2026, 8, 19, 8))),
        'Departs tomorrow',
      );
    });

    test('a short overnight wait counts hours, not "tomorrow"', () {
      expect(
        _line(resolveBusJourneyStatus(_pass(), DateTime(2026, 8, 19, 22))),
        'Departs in 10h 30m',
      );
    });

    test('minutes within the hour', () {
      expect(
        _line(resolveBusJourneyStatus(_pass(), DateTime(2026, 8, 20, 8, 5))),
        'Departs in 25 min',
      );
    });

    test('boarding for ten minutes after the scheduled time', () {
      expect(
        _line(resolveBusJourneyStatus(_pass(), DateTime(2026, 8, 20, 8, 35))),
        'Boarding now',
      );
    });

    test('an overnight run says when it arrives', () {
      final BusJourneyStatus s = resolveBusJourneyStatus(
        _overnight(),
        DateTime(2026, 8, 20, 22, 50),
      );
      expect(_line(s), 'Departs in 25 min');
      expect(s.detail, 'Overnight, arrives Fri 5:30 AM');
    });

    test('no parseable instant falls back to the printed time', () {
      final BusJourneyStatus s = resolveBusJourneyStatus(
        _pass(departAt: null, arriveAt: null, date: '', arrivalDate: ''),
        DateTime(2026, 8, 18, 10),
      );
      expect(_line(s), 'Departs at 8:30 AM');
    });

    test(
      'folds the display time into the date when the ISO field is absent',
      () {
        final BusJourneyStatus s = resolveBusJourneyStatus(
          _pass(departAt: null, arriveAt: null),
          DateTime(2026, 8, 20, 8, 5),
        );
        expect(_line(s), 'Departs in 25 min');
      },
    );
  });

  group('underway', () {
    test('counts down to arrival and fills the route', () {
      final BusJourneyStatus s = resolveBusJourneyStatus(
        _pass(),
        DateTime(2026, 8, 20, 10),
      );
      expect(_line(s), 'Arrives in 1h 45m');
      expect(s.detail, isEmpty);
      expect(s.progress, closeTo(90 / 195, 0.001));
    });
  });

  group('finished', () {
    test('past arrival reads as arrived', () {
      final BusJourneyStatus s = resolveBusJourneyStatus(
        _pass(),
        DateTime(2026, 8, 20, 12),
      );
      expect(_line(s), 'Arrived 11:45 AM');
      expect(s.detail, 'Journey complete');
      expect(s.progress, 1);
    });

    test('an expired pass is arrived whatever the clock says', () {
      expect(
        _line(
          resolveBusJourneyStatus(
            _pass(status: TicketStatus.expired),
            DateTime(2026, 8, 1),
          ),
        ),
        'Arrived 11:45 AM',
      );
    });
  });

  group('busClock12', () {
    test('drops the leading zero and keeps the meridiem', () {
      expect(busClock12('08:30 AM'), (time: '8:30', meridiem: 'AM'));
      expect(busClock12('12:05 AM'), (time: '12:05', meridiem: 'AM'));
      expect(busClock12('12:05 PM'), (time: '12:05', meridiem: 'PM'));
    });

    test('converts a 24-hour time', () {
      expect(busClock12('23:15'), (time: '11:15', meridiem: 'PM'));
      expect(busClock12('00:40'), (time: '12:40', meridiem: 'AM'));
    });

    test('free text is null', () {
      expect(busClock12('To be announced'), isNull);
    });
  });

  group('derived values', () {
    test('duration comes from the ISO instants only', () {
      expect(busDurationLabel(_pass()), '3h 15m');
      expect(busDurationLabel(_pass(departAt: null, arriveAt: null)), '');
      expect(busDurationLabel(_overnight()), '6h 15m');
    });

    test('the overnight offset counts calendar days, with a date fallback', () {
      expect(busArrivalDayOffset(_pass()), 0);
      expect(busArrivalDayOffset(_overnight()), 1);
      expect(
        busArrivalDayOffset(
          _pass(departAt: null, arriveAt: null, arrivalDate: '21 Aug 2026'),
        ),
        1,
      );
    });
  });
}
