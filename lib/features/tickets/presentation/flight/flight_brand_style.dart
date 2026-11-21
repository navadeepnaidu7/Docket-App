import 'package:flutter/material.dart';

import '../../domain/airline_brands.dart';
import '../../domain/flight_pass_models.dart';
import '../../domain/pass_status.dart';

/// Visual policy for a flight pass: one solid airline surface with the
/// train/bus ink ramp on top.
///
/// The surface comes from [AirlineBrand]; the logo is fetched separately
/// (`airline_logo.dart`). Airlines outside the table get [universal], a
/// midnight blue that is nobody's livery. Spec in
/// `docs/features/flight-pass.md`.
@immutable
class FlightBrandStyle {
  const FlightBrandStyle({
    required this.surface,
    this.ink = const Color(0xFFFFFFFF),
    this.muted = const Color(0x9EFFFFFF), // 62%
    this.faint = const Color(0x3DFFFFFF), // 24%
    this.edge = const Color(0x29FFFFFF),
    this.shadowAlpha = 0.22,
  });

  final Color surface;
  final Color ink;
  final Color muted;
  final Color faint;
  final Color edge;
  final double shadowAlpha;

  /// Light liveries (Vueling, Scoot, Jetstar) print in near-black.
  static FlightBrandStyle _dark(Color surface) => FlightBrandStyle(
    surface: surface,
    ink: const Color(0xFF17181B),
    muted: const Color(0xB317181B), // 70%
    faint: const Color(0x3317181B), // 20%
    edge: const Color(0x4DFFFFFF),
    shadowAlpha: 0.18,
  );

  static const FlightBrandStyle universal = FlightBrandStyle(
    surface: Color(0xFF1E2A3B),
    muted: Color(0x8CF0F4F8), // 55%
    faint: Color(0x2EF0F4F8), // 18%
    edge: Color(0x14FFFFFF),
  );

  /// The train and bus spent palette, so every finished journey looks alike.
  static const FlightBrandStyle spent = FlightBrandStyle(
    surface: Color(0xFFE9E8E5),
    ink: Color(0xFF58585C),
    muted: Color(0x853C3C41),
    faint: Color(0x293C3C41),
    edge: Color(0xB3FFFFFF),
    shadowAlpha: 0.10,
  );

  /// Spent keeps the logo, so the card stays that airline's pass; only the
  /// colour goes.
  static FlightBrandStyle of(AirlineBrand? brand, {required bool active}) {
    if (!active) return spent;
    if (brand == null) return universal;
    final Color surface = Color(brand.surface);
    return brand.darkInk ? _dark(surface) : FlightBrandStyle(surface: surface);
  }

  static FlightBrandStyle forPass(
    FlightPass pass, {
    bool useBrandColors = false,
  }) {
    final bool active = useBrandColors || pass.status == TicketStatus.active;
    return of(pass.brand, active: active);
  }
}
