/// Lifecycle of a wallet pass (train or movie).
///
/// Wire format: `"active"` | `"expired"`.
enum TicketStatus {
  active,
  expired;

  static TicketStatus fromJson(Object? raw) {
    final String s = raw?.toString().toLowerCase() ?? '';
    return switch (s) {
      'expired' || 'completed' || 'past' => TicketStatus.expired,
      _ => TicketStatus.active,
    };
  }

  String toJson() => name;
}

/// Live running state of a train, independent of the pass lifecycle.
///
/// [TicketStatus] answers "is this pass still current"; this answers "what is
/// the train doing". They move independently: an active pass can be cancelled,
/// and an expired one arrived hours ago.
///
/// Wire format: `"scheduled"` | `"onTime"` | `"delayed"` | `"arrived"` |
/// `"cancelled"`. Unknown values fall back to [scheduled] rather than throwing,
/// so a backend that adds a state cannot break an installed client.
enum TrainRunState {
  scheduled,
  onTime,
  delayed,
  arrived,
  cancelled;

  static TrainRunState fromJson(Object? raw) {
    final String s = raw?.toString().toLowerCase().replaceAll('_', '') ?? '';
    return switch (s) {
      'ontime' || 'running' => TrainRunState.onTime,
      'delayed' || 'late' => TrainRunState.delayed,
      'arrived' || 'completed' => TrainRunState.arrived,
      'cancelled' || 'canceled' => TrainRunState.cancelled,
      _ => TrainRunState.scheduled,
    };
  }

  String toJson() => name;
}

/// Discriminator for multi-type pass lists.
///
/// Wire format: `"train"` | `"movie"` | `"bus"`.
enum PassKind {
  train,
  movie,
  bus;

  static PassKind fromJson(Object? raw) {
    final String s = raw?.toString().toLowerCase() ?? '';
    return switch (s) {
      'movie' || 'cinema' => PassKind.movie,
      'bus' => PassKind.bus,
      _ => PassKind.train,
    };
  }

  String toJson() => name;
}
