import 'package:flutter/material.dart';

import '../../../../core/assets/app_assets.dart';
import '../../domain/bus_pass_models.dart';
import '../../domain/pass_status.dart';

/// Canonical visual policy for a bus pass brand.
///
/// Mirrors `MovieBrandStyle`: the face reads a resolved style object rather
/// than scattering `operator ==` checks through layout. Adding an operator is
/// a new constant plus one arm of [of] — nothing in the face changes.
@immutable
class BusBrandStyle {
  const BusBrandStyle({
    required this.headerGradient,
    required this.headerInk,
    required this.headerMuted,
    required this.accent,
    required this.bodySurface,
    required this.ink,
    required this.muted,
    required this.rule,
    required this.tagline,
    this.wordmarkLead = '',
    this.wordmarkTail = '',
    this.coachAsset,
    this.coachOpacity = 1.0,
    this.shadowAlpha = 0.22,
  });

  /// Top panel wash. Two stops, painted top-to-bottom.
  final List<Color> headerGradient;

  /// Type colour on the header panel.
  final Color headerInk;

  /// Secondary type on the header panel — labels, tagline.
  final Color headerMuted;

  /// Route dots and rules on the body. The brand colour at body contrast.
  final Color accent;

  /// The lower panel — the "paper" half of the card.
  final Color bodySurface;

  final Color ink;
  final Color muted;
  final Color rule;

  /// Small caps line under the wordmark.
  final String tagline;

  /// The wordmark is set as two runs so a brand like redBus keeps its
  /// light-then-bold lockup ("red" + "Bus") without shipping a logo asset that
  /// would need its own tint, scale and dark-mode handling.
  final String wordmarkLead;
  final String wordmarkTail;

  /// Vehicle photograph bled off the header's right edge. Null renders the
  /// header as type only, which is what an unbranded operator gets.
  final String? coachAsset;

  final double coachOpacity;
  final double shadowAlpha;

  /// True when this style carries a two-run wordmark rather than falling back
  /// to the operator's name.
  bool get hasWordmark => wordmarkLead.isNotEmpty || wordmarkTail.isNotEmpty;

  static const BusBrandStyle redBus = BusBrandStyle(
    headerGradient: <Color>[Color(0xFFC0393F), Color(0xFFA5272F)],
    headerInk: Color(0xFFFFFFFF),
    headerMuted: Color(0xFFF2D6D6),
    accent: Color(0xFFB4343C),
    bodySurface: Color(0xFFEEE9E4),
    ink: Color(0xFF1A1A1A),
    muted: Color(0xFF6E6A66),
    rule: Color(0xFFD8D1CA),
    tagline: 'YOUR JOURNEY',
    wordmarkLead: 'red',
    wordmarkTail: 'Bus',
    coachAsset: AppAssets.redBusCoach,
  );

  /// Any operator we have no chrome for. A neutral slate header rather than
  /// someone else's red — an unbranded ticket must not look like a redBus one.
  static const BusBrandStyle universal = BusBrandStyle(
    headerGradient: <Color>[Color(0xFF34403F), Color(0xFF1F2827)],
    headerInk: Color(0xFFFFFFFF),
    headerMuted: Color(0xFFC9D2D0),
    accent: Color(0xFF2F6F66),
    bodySurface: Color(0xFFEDEAE6),
    ink: Color(0xFF1A1A1A),
    muted: Color(0xFF6E6A66),
    rule: Color(0xFFD8D1CA),
    tagline: 'BUS TICKET',
  );

  /// A spent ticket: same layout, colour drained out, so it can never be
  /// mistaken for a live one at a glance. Matches how the train and movie
  /// faces handle expiry.
  static const BusBrandStyle _expired = BusBrandStyle(
    headerGradient: <Color>[Color(0xFF565B5A), Color(0xFF3A3F3E)],
    headerInk: Color(0xFFEDEDED),
    headerMuted: Color(0xFFBFC2C1),
    accent: Color(0xFF7A7F7E),
    bodySurface: Color(0xFFEFEEEC),
    ink: Color(0xFF4A4D4C),
    muted: Color(0xFF8A8D8C),
    rule: Color(0xFFDCDAD7),
    tagline: 'BUS TICKET',
    coachOpacity: 0.28,
    shadowAlpha: 0.12,
  );

  /// Active brand chrome, or the drained variant when [active] is false.
  ///
  /// The expired style keeps the live brand's wordmark and coach so the card
  /// stays recognisable as *that operator's* ticket; only the colour goes.
  static BusBrandStyle of(BusPassBrand brand, {required bool active}) {
    final BusBrandStyle base = switch (brand) {
      BusPassBrand.redBus => redBus,
      BusPassBrand.universal => universal,
    };
    if (active) return base;

    return BusBrandStyle(
      headerGradient: _expired.headerGradient,
      headerInk: _expired.headerInk,
      headerMuted: _expired.headerMuted,
      accent: _expired.accent,
      bodySurface: _expired.bodySurface,
      ink: _expired.ink,
      muted: _expired.muted,
      rule: _expired.rule,
      tagline: base.tagline,
      wordmarkLead: base.wordmarkLead,
      wordmarkTail: base.wordmarkTail,
      coachAsset: base.coachAsset,
      coachOpacity: _expired.coachOpacity,
      shadowAlpha: _expired.shadowAlpha,
    );
  }

  static BusBrandStyle forPass(BusPass pass, {bool useBrandColors = false}) {
    final bool active = useBrandColors || pass.status == TicketStatus.active;
    return of(pass.resolvedBrand, active: active);
  }
}
