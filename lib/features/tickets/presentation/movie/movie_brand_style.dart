import 'package:flutter/material.dart';

import '../../../../core/assets/app_assets.dart';
import '../../domain/movie_pass_models.dart';
import '../../domain/ticket_models.dart' show TicketStatus;

/// Canonical visual policy for a movie pass brand.
/// Layout reads this instead of scattering `brand ==` switches.
@immutable
class MovieBrandStyle {
  const MovieBrandStyle({
    required this.bodyGradient,
    required this.accent,
    required this.glow,
    required this.chipBackground,
    required this.chipLabel,
    required this.presenterPrimary,
    this.presenterSecondary,
    this.logoAsset,
    this.footerLogoAsset,
    this.logoTint,
    this.chipBorder,
    this.showTopHairline = false,
    this.labelAlpha = 0.60,
  });

  final List<Color> bodyGradient;
  final Color accent;
  final Color glow;
  final Color chipBackground;
  final String chipLabel;
  final String presenterPrimary;
  final String? presenterSecondary;
  final String? logoAsset;
  final String? footerLogoAsset;
  final Color? logoTint;
  final Color? chipBorder;
  final bool showTopHairline;
  final double labelAlpha;

  static const MovieBrandStyle _expired = MovieBrandStyle(
    bodyGradient: <Color>[Color(0xFF3A3A3C), Color(0xFF1C1C1E)],
    accent: Color(0xFF8E8E93),
    glow: Color(0xFF636366),
    chipBackground: Color(0xFF48484A),
    chipLabel: 'E-Ticket',
    presenterPrimary: 'Movie Ticket',
    labelAlpha: 0.50,
  );

  static const MovieBrandStyle bookMyShow = MovieBrandStyle(
    bodyGradient: <Color>[Color(0xFFD22533), Color(0xFF9E121E)],
    accent: Color(0xFFFFB3C1),
    glow: Color(0xFFE22636),
    chipBackground: Color(0xFFD22533),
    chipLabel: 'bookmyshow',
    presenterPrimary: 'BookMyShow',
    logoAsset: AppAssets.bookMyShowLogo,
    footerLogoAsset: AppAssets.bookMyShowLogoVector,
    logoTint: Color(0xFFFFB3C1),
    labelAlpha: 0.60,
  );

  static const MovieBrandStyle district = MovieBrandStyle(
    bodyGradient: <Color>[
      Color(0xFF6B42F6),
      Color(0xFF6440F0),
      Color(0xFF5B37E8),
      Color(0xFF7A3FF8),
    ],
    accent: Color(0xFFB5A3FF),
    glow: Color(0xFF5F22D9),
    chipBackground: Color(0xFF5F22D9),
    chipLabel: 'district',
    presenterPrimary: 'district',
    presenterSecondary: ' by Zomato',
    logoAsset: AppAssets.districtLogo,
    logoTint: null,
    chipBorder: null,
    showTopHairline: false,
    labelAlpha: 0.60,
  );

  static const MovieBrandStyle universal = MovieBrandStyle(
    bodyGradient: <Color>[Color(0xFF2C2C2E), Color(0xFF151517)],
    accent: Color(0xFF8E8E93),
    glow: Color(0xFF2C2C2E),
    chipBackground: Color(0xFF2C2C2E),
    chipLabel: 'E-Ticket',
    presenterPrimary: 'Movie Ticket',
    showTopHairline: false,
    labelAlpha: 0.60,
  );

  /// Active brand chrome, or muted greys when [active] is false.
  static MovieBrandStyle of(MoviePassBrand brand, {required bool active}) {
    if (!active) {
      final MovieBrandStyle base = of(brand, active: true);
      return MovieBrandStyle(
        bodyGradient: _expired.bodyGradient,
        accent: _expired.accent,
        glow: _expired.glow,
        chipBackground: _expired.chipBackground,
        chipLabel: base.chipLabel,
        presenterPrimary: base.presenterPrimary,
        presenterSecondary: base.presenterSecondary,
        logoAsset: base.logoAsset,
        logoTint: Colors.white24,
        chipBorder: null,
        showTopHairline: false,
        labelAlpha: _expired.labelAlpha,
      );
    }
    return switch (brand) {
      MoviePassBrand.bookMyShow => bookMyShow,
      MoviePassBrand.district => district,
      MoviePassBrand.universal => universal,
    };
  }

  static MovieBrandStyle forPass(MoviePass pass, {bool useBrandColors = false}) {
    final bool active =
        useBrandColors || pass.status == TicketStatus.active;
    return of(pass.brand, active: active);
  }
}
