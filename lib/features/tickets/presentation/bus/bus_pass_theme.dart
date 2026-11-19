import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/wallet/wallet_card_metrics.dart';

/// Geometry for the 382 x 560 bus face — the train canvas, so both pass types
/// frame alike in the carousel.
///
/// Every text line is placed by its **baseline**, never by its top: the
/// fallback face google_fonts paints before Geist resolves has different
/// ascents, and top-placed text would jump once the real font arrives. Spec in
/// `docs/features/bus-pass-redesign.md`.
abstract final class BusPassMetrics {
  BusPassMetrics._();

  static const double width = WalletCardMetrics.trainCanvasWidth;
  static const double height = WalletCardMetrics.trainCanvasHeight;
  static const Size canvas = WalletCardMetrics.trainCanvas;

  static const double cornerR = 24;
  static const double notchR = 10;

  /// Horizontal inset. Every left column starts here and every right column
  /// ends at [contentRight].
  static const double inset = 26;
  static const double contentRight = width - inset;
  static const double contentWidth = width - 2 * inset;

  /// Clear space between the two halves of a split row.
  static const double columnGap = 16;
  static const double halfWidth = (contentWidth - columnGap) / 2;

  // ── Header ──
  static const double nameBaseline = 52;
  static const double bookingBaseline = 76;

  // ── Journey ──
  static const double cityBaseline = 158;
  static const double timeBaseline = 206;

  /// Vertical middle of the times' cap height (Geist cap height is 0.71 em).
  static const double ruleY = timeBaseline - BusPassType.timeSize * 0.71 / 2;
  static const double ruleLift = 24;
  static const double durationGap = 6;
  static const double ruleGap = 14;

  /// First line of the stop names; a second line follows at [stopLineHeight].
  static const double stopBaseline = 230;
  static const double stopLineHeight = 19;

  /// Space between a time's last digit and its meridiem.
  static const double meridiemGap = 4;

  /// The +1 day marker hangs in the right margin, top-aligned to the time's cap
  /// line, so the arrival keeps the shared right edge.
  static const double dayMarkerBaseline =
      timeBaseline - BusPassType.timeSize * 0.71 + 9;
  static const double dayMarkerGap = 4;

  // ── Status ──
  static const double leadBaseline = 300;
  static const double detailBaseline = 327;

  // ── Stub ──
  static const double tearY = 380;
  static const double stubPad = 40;
  static const double labelCap = BusPassType.labelSize * 0.71;
  static const double seatLabelBaseline = tearY + stubPad + labelCap;
  static const double seatBaseline = seatLabelBaseline + 40;
  static const double passengerLabelBaseline = seatBaseline + 32;
  static const double passengerBaseline = passengerLabelBaseline + 24;

  /// Seat runs up to the fare column.
  static const double seatWidth = contentWidth - 110;

  /// Distance from the card's bottom edge to the notch centre.
  static const double notchFromBottom = height - tearY;

  // ── Coach watermark ──
  //
  // Pulls out of the stub's bottom-right corner, wheels cut by the edge. The
  // passenger line stops [coachClearance] short of it.
  static const double coachWidth = 176;
  static const double coachHeight = coachWidth * 50 / 120;
  static const double coachLeft = 222;
  static const double coachTop = height + 5 - coachHeight;
  static const double coachClearance = 12;
  static const double passengerWidth = coachLeft - coachClearance - inset;
}

/// Type ramp — the train face's, plus the meridiem and the seat. Geist only,
/// never heavier than w700, the heaviest weight bundled.
abstract final class BusPassType {
  BusPassType._();

  static const double timeSize = 44;
  static const double timeTracking = -1.76;
  static const double labelSize = 13;

  /// Seat values longer than this drop to [seatLong] instead of wrapping.
  static const int seatShortLength = 7;

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

  /// The light run of a two-run wordmark.
  static TextStyle nameLight(Color c) =>
      name(c).copyWith(fontWeight: FontWeight.w400);

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
  );

  /// Stop names: [small] with a real line height, since they wrap to two.
  static TextStyle stop(Color c) => GoogleFonts.geist(
    color: c,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: BusPassMetrics.stopLineHeight / 14,
  );

  /// The big times. Proportional figures, for the reason given on
  /// `TrainPassType.time`.
  static TextStyle time(Color c) => GoogleFonts.geist(
    color: c,
    fontSize: timeSize,
    fontWeight: FontWeight.w400,
    letterSpacing: timeTracking,
    height: 1.0,
  );

  /// "AM" / "PM" beside a big time, on its baseline.
  static TextStyle meridiem(Color c) => GoogleFonts.geist(
    color: c,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.14,
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
    fontWeight: FontWeight.w600,
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

  /// The seat — the one value a traveller looks for once aboard.
  static TextStyle seat(Color c, {bool long = false}) => GoogleFonts.geist(
    color: c,
    fontSize: long ? 24 : 34,
    fontWeight: FontWeight.w600,
    letterSpacing: long ? -0.36 : -0.68,
    height: 1.0,
  );

  /// Kicks off loading for every weight this face uses, so `main()`'s
  /// `GoogleFonts.pendingFonts()` wait covers them. Return values are
  /// deliberately discarded — asking is the whole point.
  static void warmUp() {
    const Color c = Color(0xFF000000);
    time(c);
    small(c);
    name(c);
  }
}
