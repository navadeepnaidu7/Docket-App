import 'package:flutter/material.dart';

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

  /// Material icon used as a small glyph on the folder face / strip.
  IconData get icon => switch (this) {
        PassHistoryCategory.train => Icons.train_rounded,
        PassHistoryCategory.movie => Icons.local_movies_rounded,
        PassHistoryCategory.flight => Icons.flight_rounded,
        PassHistoryCategory.event => Icons.confirmation_number_rounded,
        PassHistoryCategory.bus => Icons.directions_bus_rounded,
        PassHistoryCategory.other => Icons.folder_rounded,
      };

  /// Solid accent for strip fills and folder body (light-mode base).
  Color get accentLight => switch (this) {
        PassHistoryCategory.train => const Color(0xFF1F3A60),
        PassHistoryCategory.movie => const Color(0xFF6B3FA0),
        PassHistoryCategory.flight => const Color(0xFF0E7490),
        PassHistoryCategory.event => const Color(0xFFB45309),
        PassHistoryCategory.bus => const Color(0xFF0F766E),
        PassHistoryCategory.other => const Color(0xFF5E5CE6),
      };

  /// Solid accent for strip fills and folder body (dark-mode base).
  Color get accentDark => switch (this) {
        PassHistoryCategory.train => const Color(0xFF3D6BA8),
        PassHistoryCategory.movie => const Color(0xFF9B6DD4),
        PassHistoryCategory.flight => const Color(0xFF22D3EE),
        PassHistoryCategory.event => const Color(0xFFF59E0B),
        PassHistoryCategory.bus => const Color(0xFF2DD4BF),
        PassHistoryCategory.other => const Color(0xFF818CF8),
      };

  Color accent(Brightness brightness) =>
      brightness == Brightness.dark ? accentDark : accentLight;

  /// Lighter folder face tint (tab + body gradient start).
  Color folderFace(Brightness brightness) {
    final Color base = accent(brightness);
    return Color.lerp(
      base,
      brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      brightness == Brightness.dark ? 0.18 : 0.12,
    )!;
  }

  /// Deeper folder body / shadow tone.
  Color folderBody(Brightness brightness) {
    final Color base = accent(brightness);
    return Color.lerp(
      base,
      Colors.black,
      brightness == Brightness.dark ? 0.22 : 0.14,
    )!;
  }

  static PassHistoryCategory fromPassKind(PassKind kind) => switch (kind) {
        PassKind.train => PassHistoryCategory.train,
        PassKind.movie => PassHistoryCategory.movie,
      };
}

extension PassKindHistoryCategoryX on PassKind {
  PassHistoryCategory get historyCategory =>
      PassHistoryCategory.fromPassKind(this);
}
