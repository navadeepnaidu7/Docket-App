import 'package:docket/features/tickets/domain/ticket_models.dart';
import 'package:docket/features/tickets/domain/train_booking_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrainBookingState.classify', () {
    test('reads the railway and RedBus spellings', () {
      expect(TrainBookingState.classify('CNF'), TrainBookingState.confirmed);
      expect(
        TrainBookingState.classify('Confirmed'),
        TrainBookingState.confirmed,
      );
      expect(TrainBookingState.classify('RAC-12'), TrainBookingState.rac);
      expect(
        TrainBookingState.classify('Waitlist'),
        TrainBookingState.waitlisted,
      );
      expect(
        TrainBookingState.classify('GNWL/14'),
        TrainBookingState.waitlisted,
      );
      expect(
        TrainBookingState.classify('Your Ticket is Waitlisted'),
        TrainBookingState.waitlisted,
      );
      expect(TrainBookingState.classify('CAN'), TrainBookingState.cancelled);
    });

    test('a berth or an empty field says nothing', () {
      expect(TrainBookingState.classify(''), TrainBookingState.unknown);
      expect(TrainBookingState.classify('B3-16'), TrainBookingState.unknown);
      expect(TrainBookingState.classify('Unknown'), TrainBookingState.unknown);
    });
  });

  group('trainQueueLabel', () {
    test('keeps the prefix and digits as printed', () {
      expect(trainQueueLabel('WL-1'), 'WL 1');
      expect(trainQueueLabel('GNWL/14'), 'GNWL 14');
      expect(trainQueueLabel('GNWL 01'), 'GNWL 01');
      expect(trainQueueLabel('pqwl5'), 'PQWL 5');
      expect(trainQueueLabel('RAC-12'), 'RAC 12');
    });

    test('is empty for anything that is not a queue position', () {
      expect(trainQueueLabel('B3-16'), '');
      expect(trainQueueLabel('Waitlisted'), '');
      expect(trainQueueLabel(''), '');
    });
  });

  group('TicketPassenger', () {
    test('a waitlisted passenger shows the position and no berth', () {
      final TicketPassenger p = TicketPassenger.fromJson(<String, dynamic>{
        'name': 'Ramadevi',
        'coach': '',
        'seat': '',
        'berth': '',
        'currentStatus': 'Waitlist',
        'currentSeatDetails': 'WL-1',
      });
      expect(p.bookingState, TrainBookingState.waitlisted);
      expect(p.statusLabel, 'WL 1');
      expect(p.seatLabel, '');
    });

    test('a confirmed passenger reads Confirmed with the berth', () {
      final TicketPassenger p = TicketPassenger.fromJson(<String, dynamic>{
        'name': 'Asha',
        'coach': 'B3',
        'seat': '16',
        'berth': 'Side Upper',
        'currentStatus': 'CNF',
        'currentSeatDetails': 'B3-16',
      });
      expect(p.bookingState, TrainBookingState.confirmed);
      expect(p.statusLabel, 'Confirmed');
      expect(p.seatLabel, 'B3 · 16 · Side Upper');
    });

    test('a pass never checked has no status rather than a guessed one', () {
      final TicketPassenger p = TicketPassenger.fromJson(<String, dynamic>{
        'name': 'Mohan',
        'coach': 'S2',
        'seat': '40',
        'berth': '',
      });
      expect(p.bookingState, TrainBookingState.unknown);
      expect(p.statusLabel, '');
      expect(p.seatLabel, 'S2 · 40');
    });

    test('booked shows only when it differs from now', () {
      final TicketPassenger moved = TicketPassenger.fromJson(<String, dynamic>{
        'name': 'Ramadevi',
        'coach': '',
        'seat': '',
        'berth': '',
        'currentStatus': 'RAC 46',
        'currentSeatDetails': 'RAC-46',
        'bookingStatus': 'WL 7',
      });
      expect(moved.statusLabel, 'RAC 46');
      expect(moved.bookingState, TrainBookingState.rac);
      expect(moved.bookedLabel, 'WL 7');

      final TicketPassenger still = TicketPassenger.fromJson(<String, dynamic>{
        'name': 'Asha',
        'coach': 'B3',
        'seat': '16',
        'berth': '',
        'currentStatus': 'CNF',
        'currentSeatDetails': 'B3-16',
        'bookingStatus': 'CNF',
      });
      expect(still.bookedLabel, '');
    });

    test('status survives a JSON round trip', () {
      const TicketPassenger p = TicketPassenger(
        name: 'R',
        coach: '',
        seat: '',
        berth: '',
        currentStatus: 'Waitlist',
        currentSeatDetails: 'WL-1',
      );
      final TicketPassenger back = TicketPassenger.fromJson(p.toJson());
      expect(back.currentStatus, 'Waitlist');
      expect(back.currentSeatDetails, 'WL-1');
    });
  });
}
