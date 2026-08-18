import 'package:flutter_test/flutter_test.dart';

import 'package:docket/features/tickets/domain/ticket_models.dart';
import 'package:docket/features/tickets/presentation/train/halt_status.dart';

TicketHalt _halt(HaltState state) => TicketHalt(
  time: '09:41 AM',
  station: 'Khammam',
  dateLabel: '15 Aug',
  state: state,
);

HaltStatus? _resolve({
  required HaltState state,
  TrainRunState runState = TrainRunState.scheduled,
  int? delayMinutes,
  bool completed = false,
}) {
  return resolveHaltStatus(
    halt: _halt(state),
    runState: runState,
    delayMinutes: delayMinutes,
    completed: completed,
  );
}

void main() {
  group('resolveHaltStatus', () {
    test('a departed halt reads as departed, whatever the train is doing', () {
      expect(
        _resolve(state: HaltState.departed, runState: TrainRunState.delayed),
        const HaltStatus(label: 'Departed', tone: HaltStatusTone.neutral),
      );
    });

    test('the halt being pulled into reads as arriving', () {
      expect(
        _resolve(state: HaltState.arriving, runState: TrainRunState.onTime),
        const HaltStatus(label: 'Arriving', tone: HaltStatusTone.live),
      );
    });

    // Regression guard: the whole point of the pill is that green means the
    // backend said so. Absence of a delay is "unknown", not "punctual".
    test('an untracked upcoming halt gets no pill at all', () {
      expect(_resolve(state: HaltState.upcoming), isNull);
      expect(
        _resolve(state: HaltState.upcoming, runState: TrainRunState.scheduled),
        isNull,
      );
    });

    test('delayed run state with null delayMinutes shows "Delayed"', () {
      expect(
        _resolve(
          state: HaltState.upcoming,
          runState: TrainRunState.delayed,
          delayMinutes: null,
        ),
        const HaltStatus(label: 'Delayed', tone: HaltStatusTone.warning),
      );
    });

    test('"On time" needs runState to actually say so', () {
      expect(
        _resolve(state: HaltState.upcoming, runState: TrainRunState.onTime),
        const HaltStatus(label: 'On time', tone: HaltStatusTone.positive),
      );
    });

    test('a known delay outranks an on-time run state', () {
      expect(
        _resolve(
          state: HaltState.upcoming,
          runState: TrainRunState.onTime,
          delayMinutes: 12,
        ),
        const HaltStatus(label: '12 min late', tone: HaltStatusTone.warning),
      );
    });

    // null and 0 are different answers: null is "the backend has not said",
    // 0 is "running to schedule". Neither may be coerced into the other.
    test('a zero delay is not a delay', () {
      expect(
        _resolve(
          state: HaltState.upcoming,
          runState: TrainRunState.onTime,
          delayMinutes: 0,
        ),
        const HaltStatus(label: 'On time', tone: HaltStatusTone.positive),
      );
      expect(
        _resolve(state: HaltState.upcoming, delayMinutes: 0),
        isNull,
      );
    });

    test('a cancelled train overrides every halt state', () {
      for (final HaltState state in HaltState.values) {
        expect(
          _resolve(state: state, runState: TrainRunState.cancelled),
          const HaltStatus(label: 'Cancelled', tone: HaltStatusTone.warning),
          reason: 'cancelled should win over ${state.name}',
        );
      }
    });

    test('a finished journey never claims something is still arriving', () {
      expect(
        _resolve(state: HaltState.arriving, completed: true),
        const HaltStatus(label: 'Departed', tone: HaltStatusTone.neutral),
      );
      expect(
        _resolve(
          state: HaltState.upcoming,
          completed: true,
          runState: TrainRunState.onTime,
        ),
        isNull,
      );
    });
  });

  group('formatDelay', () {
    test('renders minutes, hours, and both', () {
      expect(formatDelay(1), '1 min');
      expect(formatDelay(59), '59 min');
      expect(formatDelay(60), '1 hr');
      expect(formatDelay(120), '2 hr');
      expect(formatDelay(125), '2 hr 5 min');
    });
  });
}
