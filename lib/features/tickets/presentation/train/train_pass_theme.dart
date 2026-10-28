import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/wallet/wallet_card_metrics.dart';

/// The palette resolved for one pass state.
///
/// One solid surface and nothing else: depth comes from a 1 dp top-edge
/// highlight on the face and a shadow outside it. The face is fixed in both
/// themes, like the movie and passport cards. Spec in
/// `docs/features/train-pass-redesign.md`.
@immutable
class TrainPassColors {
  const TrainPassColors._({
    required this.surface,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.edge,
    required this.warning,
    required this.critical,
    required this.shadowAlpha,
  });

  final Color surface;
  final Color ink;

  /// Labels, city names, codes, the lead words of the status sentence.
  final Color muted;

  /// The route rule and the tear dots.
  final Color faint;

  /// 1 dp highlight along the top edge.
  final Color edge;

  final Color warning;
  final Color critical;
  final double shadowAlpha;

  static const TrainPassColors active = TrainPassColors._(
    surface: Color(0xFF1C1C1E),
    ink: Color(0xFFF5F5F7),
    muted: Color(0x85F5F5F7), // 52%
    faint: Color(0x2BF5F5F7), // 17%
    edge: Color(0x12FFFFFF),
    warning: Color(0xFFFFB340),
    critical: Color(0xFFFF6961),
    shadowAlpha: 0.22,
  );

  /// A spent ticket keeps the layout and loses the night: same card, drained,
  /// so it never reads as a live one at a glance. Tones flatten to [muted].
  static const TrainPassColors spent = TrainPassColors._(
    surface: Color(0xFFE9E8E5),
    ink: Color(0xFF58585C),
    muted: Color(0x853C3C41),
    faint: Color(0x293C3C41),
    edge: Color(0xB3FFFFFF),
    warning: Color(0x853C3C41),
    critical: Color(0x853C3C41),
    shadowAlpha: 0.10,
  );

  static TrainPassColors of({required bool isExpired}) =>
      isExpired ? spent : active;
}

/// Geometry for the 382 x 498 face. Every text line is placed by its
/// **baseline**, never by its top: the fallback face google_fonts paints before
/// Geist resolves has different ascents, and top-placed text would jump once
/// the real font arrives.
abstract final class TrainPassMetrics {
  TrainPassMetrics._();

  /// Derived from [WalletCardMetrics.trainCanvas] rather than restated, because
  /// the card is scaled by the canvas while it is laid out against these — two
  /// independent literals silently stretched every baseline when one moved.
  static const double width = WalletCardMetrics.trainCanvasWidth;
  static const double height = WalletCardMetrics.trainCanvasHeight;
  static const Size canvas = Size(width, height);

  static const double cornerR = 24;
  static const double notchR = 10;

  /// Horizontal inset. Every left column starts here and every right column
  /// ends at [contentRight].
  static const double inset = 26;
  static const double contentRight = width - inset;
  static const double contentWidth = width - 2 * inset;

  // ── Header ──
  static const double nameBaseline = 48;
  static const double numberBaseline = 72;

  // ── Journey ──
  static const double cityBaseline = 140;
  static const double timeBaseline = 188;

  /// Vertical middle of the times' cap height (Geist cap height is 0.71 em).
  static const double ruleY = timeBaseline - TrainPassType.timeSize * 0.71 / 2;

  /// Height reserved above the rule for the duration, and the clear space
  /// between the duration's line box and the rule.
  static const double ruleLift = 24;
  static const double durationGap = 6;

  /// Clear space between a time and the end of the route rule.
  static const double ruleGap = 16;
  static const double codeBaseline = 212;

  /// The +1 day marker hangs in the right margin, top-aligned to the time's cap
  /// line, so the arrival time itself keeps the shared right edge.
  static const double dayMarkerBaseline =
      timeBaseline - TrainPassType.timeSize * 0.71 + 9;
  static const double dayMarkerGap = 3;

  // ── Status ──
  static const double leadBaseline = 275;
  static const double detailBaseline = 301;

  // ── Stub ──
  //
  // The grid holds equal space above the first label's cap line and below the
  // last value's baseline, so it sits optically centred under the tear.
  static const double tearY = 341;
  static const double stubPad = 32;
  static const double labelCap = TrainPassType.labelSize * 0.71;
  static const double firstLabelBaseline = tearY + stubPad + labelCap;
  static const double labelToValue = 24;
  static const double rowPitch = 60;

  static double labelBaseline(int row) => firstLabelBaseline + row * rowPitch;
  static double valueBaseline(int row) => labelBaseline(row) + labelToValue;

  /// Three equal columns across the content width.
  static const double columnWidth = contentWidth / 3;
  static const double columnTwoX = inset + columnWidth;

  /// Berth runs on into the third column's spare room; Class there only ever
  /// holds a two-letter code.
  static const double berthWidth = contentWidth - columnWidth - 64;

  /// Distance from the card's bottom edge to the notch centre.
  static const double notchFromBottom = height - tearY;
}

/// Type ramp. Geist only, and never heavier than w700 — that is the heaviest
/// weight bundled, and google_fonts would otherwise synthesise one.
abstract final class TrainPassType {
  TrainPassType._();

  static const double timeSize = 44;
  static const double timeTracking = -1.76;
  static const double labelSize = 13;

  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextStyle name(Color c) => GoogleFonts.geist(
    color: c,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.0,
  );

  static TextStyle date(Color c) => GoogleFonts.geist(
    color: c,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.0,
  );

  static TextStyle small(Color c) => GoogleFonts.geist(
    color: c,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.0,
    fontFeatures: _tabular,
  );

  /// The big times. Proportional figures on purpose: Geist's tabular "1" sits
  /// centred in a full-width cell, which pushed a time starting with 1 about
  /// 7 dp right of the city name above it. These never animate, so they gain
  /// nothing from `tnum`.
  static TextStyle time(Color c) => GoogleFonts.geist(
    color: c,
    fontSize: timeSize,
    fontWeight: FontWeight.w400,
    letterSpacing: timeTracking,
    height: 1.0,
  );

  static TextStyle duration(Color c) => GoogleFonts.geist(
    color: c,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.0,
    fontFeatures: _tabular,
  );

  static TextStyle dayMarker(Color c) => GoogleFonts.geist(
    color: c,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.0,
  );

  static TextStyle lead(Color c) => GoogleFonts.geist(
    color: c,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.6,
    height: 1.0,
  );

  static TextStyle detail(Color c) => GoogleFonts.geist(
    color: c,
    fontSize: 14.5,
    fontWeight: FontWeight.w500,
    height: 1.0,
  );

  static TextStyle label(Color c) => GoogleFonts.geist(
    color: c,
    fontSize: labelSize,
    fontWeight: FontWeight.w500,
    height: 1.0,
  );

  static TextStyle value(Color c) => GoogleFonts.geist(
    color: c,
    fontSize: 17,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.17,
    height: 1.0,
    fontFeatures: _tabular,
  );

  /// Kicks off loading for every weight this face uses, so `main()`'s
  /// `GoogleFonts.pendingFonts()` wait covers them.
  ///
  /// google_fonts starts loading on the first call for a family+weight, so the
  /// return values are deliberately discarded — asking is the whole point.
  static void warmUp() {
    const Color c = Color(0xFF000000);
    time(c);
    small(c);
    name(c);
  }
}

/// Side bearings of Geist Regular's default (proportional) figures, in em,
/// read off `assets/fonts/Geist-Regular.ttf` with fontTools.
///
/// At 50 dp a figure carries 1-5.5 dp of empty space before and after its ink,
/// against about 1 dp for the 14 dp letters above and below it. Without
/// correction the time looks indented from the city name it sits under.
abstract final class TrainTimeOptics {
  TrainTimeOptics._();

  static const Map<String, double> _lsb = <String, double>{
    '0': 0.050, '1': 0.040, '2': 0.060, '3': 0.050, '4': 0.030,
    '5': 0.060, '6': 0.060, '7': 0.020, '8': 0.040, '9': 0.060,
  };

  static const Map<String, double> _rsb = <String, double>{
    '0': 0.050, '1': 0.110, '2': 0.060, '3': 0.050, '4': 0.050,
    '5': 0.061, '6': 0.061, '7': 0.000, '8': 0.040, '9': 0.061,
  };

  /// Typical side bearing of the 14 dp text the time aligns with.
  static const double _companion = 1.0;

  /// How far to pull a left-aligned time left so its ink meets the edge.
  static double leftPull(String text) {
    if (text.isEmpty) return 0;
    final double lsb = _lsb[text[0]] ?? 0.05;
    return lsb * TrainPassType.timeSize - _companion;
  }

  /// How far to push a right-aligned time right so its ink meets the edge.
  ///
  /// Flutter adds letter spacing after the last glyph too, so with negative
  /// tracking the ink already overhangs the box by that much.
  static double rightPush(String text) {
    if (text.isEmpty) return 0;
    final double rsb = _rsb[text[text.length - 1]] ?? 0.05;
    return rsb * TrainPassType.timeSize + TrainPassType.timeTracking - _companion;
  }
}
