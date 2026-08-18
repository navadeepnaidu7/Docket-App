import 'package:flutter/foundation.dart';

import '../../domain/ticket_models.dart';

/// How loud a halt's status pill is.
enum HaltStatusTone {
  /// Already behind the train — grey.
  neutral,

  /// The train is pulling in right now.
  live,

  /// Confirmed running to schedule.
  positive,

  /// Late, or not running at all.
  warning,
}

/// One resolved status pill on the running-status timeline.
@immutable
class HaltStatus {
  const HaltStatus({required this.label, required this.tone});

  final String label;
  final HaltStatusTone tone;

  @override
  bool operator ==(Object other) =>
      other is HaltStatus && other.label == label && other.tone == tone;

  @override
  int get hashCode => Object.hash(label, tone);

  @override
  String toString() => 'HaltStatus("$label", ${tone.name})';
}

/// What the pill beside [halt] should say, or null when nothing is known.
///
/// Null is a real answer and means "render no pill" — an upcoming halt on a
/// pass the backend has never reported on has no status worth stating.
///
/// "On time" requires [runState] to actually be [TrainRunState.onTime]. The
/// absence of a delay is **not** evidence the train is running to schedule:
/// [delayMinutes] is null when the backend has not said, and inferring
/// punctuality from that would put a confident green pill on every pass that
/// has never been tracked. [resolveTrainBandMessages] enforces the same rule on
/// the wallet card, and the two must not disagree.
HaltStatus? resolveHaltStatus({
  required TicketHalt halt,
  required TrainRunState runState,
  required int? delayMinutes,
  required bool completed,
}) {
  // A cancelled train makes every downstream halt meaningless — there is
  // nothing to be on time for.
  if (runState == TrainRunState.cancelled) {
    return const HaltStatus(label: 'Cancelled', tone: HaltStatusTone.warning);
  }

  switch (halt.state) {
    case HaltState.departed:
      return const HaltStatus(
        label: 'Departed',
        tone: HaltStatusTone.neutral,
      );
    case HaltState.arriving:
      // Once the journey is over nothing is arriving, whatever the halt says.
      if (completed) {
        return const HaltStatus(
          label: 'Departed',
          tone: HaltStatusTone.neutral,
        );
      }
      return const HaltStatus(label: 'Arriving', tone: HaltStatusTone.live);
    case HaltState.upcoming:
      if (completed) return null;
      final int late = delayMinutes ?? 0;
      if (late > 0) {
        return HaltStatus(
          label: '${formatDelay(late)} late',
          tone: HaltStatusTone.warning,
        );
      }
      // Delayed run state with no magnitude means "running late, extent unknown"
      if (runState == TrainRunState.delayed && delayMinutes == null) {
        return const HaltStatus(
          label: 'Delayed',
          tone: HaltStatusTone.warning,
        );
      }
      if (runState == TrainRunState.onTime) {
        return const HaltStatus(
          label: 'On time',
          tone: HaltStatusTone.positive,
        );
      }
      return null;
  }
}

/// Compact delay wording: "12 min", "1 hr", "2 hr 5 min".
String formatDelay(int minutes) {
  if (minutes < 60) return '$minutes min';
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  if (rest == 0) return '$hours hr';
  return '$hours hr $rest min';
}
