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

/// Discriminator for multi-type pass lists.
///
/// Wire format: `"train"` | `"movie"`.
enum PassKind {
  train,
  movie;

  static PassKind fromJson(Object? raw) {
    final String s = raw?.toString().toLowerCase() ?? '';
    return switch (s) {
      'movie' || 'cinema' => PassKind.movie,
      _ => PassKind.train,
    };
  }

  String toJson() => name;
}
