import 'package:flutter/material.dart';

import '../../domain/bus_pass_models.dart';
import '../../domain/pass_status.dart';

/// Canonical visual policy for a bus pass brand.
///
/// One solid operator surface, the train face's ink/muted/faint ramp on top of
/// it, and the tones the coach watermark is drawn in. Spec in
/// `docs/features/bus-pass-redesign.md`.
///
/// Mirrors `MovieBrandStyle`: the face reads a resolved style object rather
/// than scattering `operator ==` checks through layout. Adding an operator is
/// a new constant plus one arm of [of] — nothing in the face changes.
@immutable
class BusBrandStyle {
  const BusBrandStyle({
    required this.surface,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.edge,
    required this.coachBody,
    required this.coachShade,
    this.wordmarkLead = '',
    this.wordmarkTail = '',
    this.shadowAlpha = 0.22,
  });

  final Color surface;
  final Color ink;

  /// Labels, cities, stops, the lead words of the status sentence.
  final Color muted;

  /// The route rule and the tear dots.
  final Color faint;

  /// 1 dp highlight along the top edge.
  final Color edge;

  /// The watermark coach's body, tone on tone with [surface].
  final Color coachBody;

  /// The watermark coach's windows and tyres — a shade darker than [surface].
  final Color coachShade;

  /// The wordmark is set as two runs so a brand like redBus keeps its
  /// light-then-bold lockup ("red" + "Bus") without shipping a logo asset that
  /// would need its own tint, scale and dark-mode handling.
  final String wordmarkLead;
  final String wordmarkTail;

  final double shadowAlpha;

  /// True when this style carries a two-run wordmark rather than falling back
  /// to the operator's name.
  bool get hasWordmark => wordmarkLead.isNotEmpty || wordmarkTail.isNotEmpty;

  static const BusBrandStyle redBus = BusBrandStyle(
    surface: Color(0xFFA3262E),
    ink: Color(0xFFFFFFFF),
    muted: Color(0x9EFFFFFF), // 62%
    faint: Color(0x3DFFFFFF), // 24%
    edge: Color(0x29FFFFFF),
    coachBody: Color(0x1FFFFFFF), // 12%
    coachShade: Color(0x4D3C0006), // 30%
    wordmarkLead: 'red',
    wordmarkTail: 'Bus',
  );

  /// Any operator we have no chrome for. A petrol teal rather than someone
  /// else's red — an unbranded ticket must not look like a redBus one — and
  /// far enough from the train's graphite that the two never read as one.
  static const BusBrandStyle universal = BusBrandStyle(
    surface: Color(0xFF1F3533),
    ink: Color(0xFFFFFFFF),
    muted: Color(0x8CF0F6F5), // 55%
    faint: Color(0x2EF0F6F5), // 18%
    edge: Color(0x14FFFFFF),
    coachBody: Color(0x1FFFFFFF),
    coachShade: Color(0x4D000000),
  );

  /// A spent ticket: same layout, colour drained out, so it can never be
  /// mistaken for a live one at a glance. The train's spent palette, so every
  /// finished journey looks alike.
  static const BusBrandStyle _spent = BusBrandStyle(
    surface: Color(0xFFE9E8E5),
    ink: Color(0xFF58585C),
    muted: Color(0x853C3C41),
    faint: Color(0x293C3C41),
    edge: Color(0xB3FFFFFF),
    coachBody: Color(0x123C3C41), // 7%
    coachShade: Color(0x0F3C3C41), // 6%
    shadowAlpha: 0.10,
  );

  /// Active brand chrome, or the drained variant when [active] is false.
  ///
  /// The spent style keeps the live brand's wordmark so the card stays
  /// recognisable as *that operator's* ticket; only the colour goes.
  static BusBrandStyle of(BusPassBrand brand, {required bool active}) {
    final BusBrandStyle base = switch (brand) {
      BusPassBrand.redBus => redBus,
      BusPassBrand.universal => universal,
    };
    if (active) return base;

    return BusBrandStyle(
      surface: _spent.surface,
      ink: _spent.ink,
      muted: _spent.muted,
      faint: _spent.faint,
      edge: _spent.edge,
      coachBody: _spent.coachBody,
      coachShade: _spent.coachShade,
      wordmarkLead: base.wordmarkLead,
      wordmarkTail: base.wordmarkTail,
      shadowAlpha: _spent.shadowAlpha,
    );
  }

  static BusBrandStyle forPass(BusPass pass, {bool useBrandColors = false}) {
    final bool active = useBrandColors || pass.status == TicketStatus.active;
    return of(pass.resolvedBrand, active: active);
  }
}
