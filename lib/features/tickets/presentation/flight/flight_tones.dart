import 'package:flutter/material.dart';

import 'flight_journey_status.dart';

/// Status colours for the flight detail screen, the iOS system palette: green
/// for landed or early, amber for late or changed, blue for live or estimated,
/// red for cancelled. Darkened on light and lifted on dark so they read as
/// text on either surface.
@immutable
class FlightTones {
  const FlightTones({required this.isDark});

  final bool isDark;

  Color get green => isDark ? const Color(0xFF30D158) : const Color(0xFF248A3D);
  Color get amber => isDark ? const Color(0xFFFFB340) : const Color(0xFFB25000);
  Color get blue => isDark ? const Color(0xFF0A84FF) : const Color(0xFF0066CC);
  Color get red => isDark ? const Color(0xFFFF453A) : const Color(0xFFD70015);

  /// Colour for [tone], or null for neutral (the caller's ink or muted).
  Color? of(FlightStatusTone tone) => switch (tone) {
    FlightStatusTone.positive => green,
    FlightStatusTone.warning => amber,
    FlightStatusTone.live => blue,
    FlightStatusTone.neutral => null,
  };
}
