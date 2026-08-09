import 'pass_status.dart';

/// High-level history folder groups for expired passes.
///
/// Maps 1:1 from [PassKind] today (train / movie). Flight, event, bus, and
/// other are scaffolded so the UI can light up when those kinds land without
/// inventing full domain models in this feature.
enum PassHistoryCategory {
  train,
  movie,
  flight,
  event,
  bus,
  other;

  /// Display label for folder titles and category headers.
  String get label => switch (this) {
        PassHistoryCategory.train => 'Trains',
        PassHistoryCategory.movie => 'Movies',
        PassHistoryCategory.flight => 'Flights',
        PassHistoryCategory.event => 'Events',
        PassHistoryCategory.bus => 'Buses',
        PassHistoryCategory.other => 'Other',
      };

  /// Singular label for empty-state copy ("No past train passes").
  String get singularLabel => switch (this) {
        PassHistoryCategory.train => 'train',
        PassHistoryCategory.movie => 'movie',
        PassHistoryCategory.flight => 'flight',
        PassHistoryCategory.event => 'event',
        PassHistoryCategory.bus => 'bus',
        PassHistoryCategory.other => 'other',
      };

  /// Sort priority for the folders grid (lower first).
  int get sortOrder => switch (this) {
        PassHistoryCategory.train => 0,
        PassHistoryCategory.movie => 1,
        PassHistoryCategory.flight => 2,
        PassHistoryCategory.event => 3,
        PassHistoryCategory.bus => 4,
        PassHistoryCategory.other => 5,
      };

  static PassHistoryCategory fromPassKind(PassKind kind) => switch (kind) {
        PassKind.train => PassHistoryCategory.train,
        PassKind.movie => PassHistoryCategory.movie,
      };
}

extension PassKindHistoryCategoryX on PassKind {
  PassHistoryCategory get historyCategory =>
      PassHistoryCategory.fromPassKind(this);
}
