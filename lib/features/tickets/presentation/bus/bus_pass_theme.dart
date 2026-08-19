import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/wallet/wallet_card_metrics.dart';

/// Palette and geometry for the bus pass face.
///
/// Sibling to `train_pass_theme.dart`, and deliberately the same *kind* of
/// object: a fixed-light paper facsimile that does not follow the app theme. A
/// wallet card stands in for a printed ticket, so it keeps its own paper in
/// both themes exactly as the train and passport faces do. The previous bus
/// face read `AppTheme.surface(brightness)` and inverted in dark mode, which
/// made it the only pass in the carousel that did.
///
/// The hue is the one difference. Teal/pine is already the bus identity in the
/// archive (`history_visuals.dart` paints its strip #2DD4BF -> #115E59), so the
/// card carries the same accent over cool mint paper — a sibling to the train's
/// warm blush rather than a copy of it.
abstract final class BusPassPalette {
  BusPassPalette._();

  /// Kept from the first-cut face: these two are the bus brand colours and are
  /// referenced by the archive strip.
  static const Color pine = Color(0xFF115E59);
  static const Color teal = Color(0xFF2DD4BF);

  static const Color surface = Color(0xFFF3FAF8);
  static const Color border = Color(0xFFD2E8E3);
  static const Color ink = Color(0xFF14201E);
  static const Color muted = Color(0xFF5C6E6A);
  static const Color rule = Color(0xFFDBEDE8);
  static const Color codeBorder = Color(0xFFD9EAE6);
  static const Color chipFill = Color(0xFFDCF5EF);
  static const Color chipInk = pine;
}

/// The palette resolved for one pass state.
///
/// An expired pass keeps the layout and loses the colour — same card, drained,
/// so a spent ticket never reads as a live one at a glance. Mirrors
/// `TrainPassColors`.
@immutable
class BusPassColors {
  const BusPassColors({
    required this.surface,
    required this.border,
    required this.ink,
    required this.muted,
    required this.rule,
    required this.accent,
    required this.codeBorder,
    required this.chipFill,
    required this.chipInk,
    required this.shadowAlpha,
  });

  final Color surface;
  final Color border;
  final Color ink;
  final Color muted;
  final Color rule;

  /// Route dots and the operator wordmark.
  final Color accent;

  final Color codeBorder;
  final Color chipFill;
  final Color chipInk;
  final double shadowAlpha;

  static const BusPassColors active = BusPassColors(
    surface: BusPassPalette.surface,
    border: BusPassPalette.border,
    ink: BusPassPalette.ink,
    muted: BusPassPalette.muted,
    rule: BusPassPalette.rule,
    accent: BusPassPalette.pine,
    codeBorder: BusPassPalette.codeBorder,
    chipFill: BusPassPalette.chipFill,
    chipInk: BusPassPalette.chipInk,
    shadowAlpha: 0.25,
  );

  static const BusPassColors expired = BusPassColors(
    surface: Color(0xFFF6F7F7),
    border: Color(0xFFE0E3E3),
    ink: Color(0xFF474D4C),
    muted: Color(0xFF848C8A),
    rule: Color(0xFFE3E7E6),
    accent: Color(0xFF6B7573),
    codeBorder: Color(0xFFDEE2E1),
    chipFill: Color(0xFFECEEEE),
    chipInk: Color(0xFF6B7573),
    shadowAlpha: 0.14,
  );

  static BusPassColors of({required bool isExpired}) =>
      isExpired ? BusPassColors.expired : BusPassColors.active;
}

abstract final class BusPassMetrics {
  BusPassMetrics._();

  /// Derived from [WalletCardMetrics.ticketCanvas] — the canvas the movie face
  /// already uses and the one the trimmed train canvas was matched to. All
  /// three passes therefore resolve to the same box in the carousel. Restating
  /// the numbers here is what let the train's two copies drift, so the bus face
  /// reads them instead.
  static const double width = WalletCardMetrics.ticketCanvasWidth;
  static const double height = WalletCardMetrics.ticketCanvasHeight;
  static const Size canvas = WalletCardMetrics.ticketCanvas;

  static const double cornerR = 32;

  /// Left inset; the content column is [width] - 2 * [inset] wide.
  static const double inset = 24;
  static const double contentWidth = width - inset * 2; // 334

  /// Width of the time column in the route block. Sized for "12:45 AM" at
  /// [BusPassType.routeTime] with the fallback face, which is wider than Geist.
  static const double timeColumnWidth = 108;

  /// Gap between the time column and the dot rail.
  static const double timeToRail = 14;

  /// Width of the rail holding the route dots and their connector.
  static const double railWidth = 14;

  /// Gap between the rail and the place column.
  static const double railToPlace = 16;

  static const double dotSize = 11;

  /// Height of the dashed connector between the two route dots.
  ///
  /// Long on purpose. The bus card carries less data than the train's (no
  /// coach, class, or live status), so at the shared canvas height the lower
  /// half was ~120dp of dead air. The rail absorbs it and earns it back by
  /// carrying the journey duration at its midpoint.
  static const double connectorHeight = 150;

  static const double codeSize = 69;
}

/// Type ramp. Geist throughout — the train's Instrument Serif is reserved for
/// its station codes, and a bus has none to set.
///
/// Geist tops out at w700; nothing here may ask for more or google_fonts
/// silently synthesises the nearest weight.
abstract final class BusPassType {
  BusPassType._();

  static TextStyle operatorName(Color color) => GoogleFonts.geist(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        height: 1.0,
      );

  /// The route headline. Times carry the hierarchy a train card gives its
  /// station codes, because a bus stop has no code to set large.
  static TextStyle routeTime(Color color) => GoogleFonts.geist(
        color: color,
        fontSize: 30,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
        height: 1.0,
      );

  /// Marks an arrival that lands on a later calendar day.
  static TextStyle dayOffset(Color color) => GoogleFonts.geist(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.0,
      );

  static TextStyle placeName(Color color) => GoogleFonts.geist(
        color: color,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.1,
      );

  /// Journey duration, set beside the rail midpoint.
  static TextStyle duration(Color color) => GoogleFonts.geist(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.0,
      );

  static TextStyle placeDetail(Color color) => GoogleFonts.geist(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.15,
      );

  static TextStyle label(Color color) => GoogleFonts.geist(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.0,
      );

  static TextStyle value(Color color) => GoogleFonts.geist(
        color: color,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.0,
      );

  static TextStyle chip(Color color) => GoogleFonts.geist(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.0,
      );

  /// Kicks off the network fetch for the weights this face uses so `main()`'s
  /// `GoogleFonts.pendingFonts()` wait covers them. Return values are
  /// deliberately discarded — asking is the whole point.
  static void warmUp() {
    routeTime(const Color(0xFF000000));
    placeName(const Color(0xFF000000));
    label(const Color(0xFF000000));
  }
}
