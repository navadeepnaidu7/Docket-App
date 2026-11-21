/// Where a train reservation stands: the colour the detail screen gives it.
///
/// Mirrors `classifyStatus` in the server's `trainschedule/policy.go`, so the
/// app and the server read "GNWL/14", "RAC-12" and "CNF" the same way.
enum TrainBookingState {
  confirmed,
  rac,
  waitlisted,
  cancelled,
  unknown;

  static TrainBookingState classify(String raw) {
    final String s = raw.trim().toLowerCase();
    if (s.isEmpty) return TrainBookingState.unknown;
    if (s.contains('cancel') || s.contains('can/') || s == 'can') {
      return TrainBookingState.cancelled;
    }
    // Waitlist before "confirm": a status like "WL / CNF" is still waiting.
    if (s.contains('waitlist') || s.contains('wl') || s.contains('w/l')) {
      return TrainBookingState.waitlisted;
    }
    if (s.contains('rac')) return TrainBookingState.rac;
    if (s.contains('confirm') || s.startsWith('cnf')) {
      return TrainBookingState.confirmed;
    }
    return TrainBookingState.unknown;
  }

  /// The first of [raws] that says anything.
  static TrainBookingState of(Iterable<String> raws) {
    for (final String raw in raws) {
      final TrainBookingState state = classify(raw);
      if (state != TrainBookingState.unknown) return state;
    }
    return TrainBookingState.unknown;
  }
}

/// "WL-1" -> "WL 1", "GNWL/14" -> "GNWL 14", "RAC 012" -> "RAC 012".
///
/// The queue position as the railway printed it, separators turned into one
/// space. Digits are never reformatted: a leading zero is how the ticket reads.
/// Empty when [raw] is not a WL or RAC position.
String trainQueueLabel(String raw) {
  final Match? m = _queuePattern.firstMatch(raw.trim());
  if (m == null) return '';
  return '${m.group(1)!.toUpperCase()} ${m.group(2)}';
}

final RegExp _queuePattern = RegExp(
  r'^([A-Za-z]{0,4}(?:WL|RAC))\s*[-/ ]?\s*(\d+)$',
  caseSensitive: false,
);
