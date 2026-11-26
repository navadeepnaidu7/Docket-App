import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/wallet/wallet_card_metrics.dart';

/// Geometry for the 382 x 560 flight face — the train canvas, so every pass
/// frames alike in the carousel.
///
/// Placed by baseline, like the train and bus faces, so the fallback font
/// google_fonts paints before Geist resolves cannot make lines jump. Spec in
/// `docs/features/flight-pass.md`.
abstract final class FlightPassMetrics {
  FlightPassMetrics._();

  static const double width = WalletCardMetrics.trainCanvasWidth;
  static const double height = WalletCardMetrics.trainCanvasHeight;
  static const Size canvas = WalletCardMetrics.trainCanvas;

  static const double cornerR = 24;
  static const double notchR = 10;

  static const double inset = 26;
  static const double contentRight = width - inset;
  static const double contentWidth = width - 2 * inset;
  static const double columnGap = 16;
  static const double halfWidth = (contentWidth - columnGap) / 2;

  // ── Header ──
  static const double nameBaseline = 52;

  static const double flightBaseline = 76;

  // ── Journey ──
  static const double cityBaseline = 118;

  /// The airport codes are the hero, where the bus and train put the times.
  static const double codeBaseline = 212;

  /// Top of the codes' capitals (Geist caps are 0.71 em).
  static const double codeCapTop =
      codeBaseline - FlightPassType.codeSize * 0.71;

  /// The route arc rises over the codes, from above one to above the other.
  /// Its feet sit [arcFootGap] over the capitals; its crown [arcRise] higher.
  static const double arcFootGap = 14;
  static const double arcRise = 34;
  static const double arcFootY = codeCapTop - arcFootGap;
  static const double arcTop = arcFootY - arcRise - 6;
  static const double arcHeight = arcRise + 12;

  /// Horizontal inset of the arc's feet from the content edges: over the
  /// middle of a three-letter code.
  static const double arcFootInset = 52;

  /// The flight time sits between the codes, centred on their capitals, so
  /// it reads as the distance between the two ends.
  static const double durationBaseline =
      (codeCapTop + codeBaseline) / 2 + FlightPassType.durationSize * 0.71 / 2;

  static const double timeBaseline = 246;
  static const double terminalBaseline = 270;

  /// The +1 marker hangs in the right margin, top-aligned to the arrival
  /// time's cap line, so the time keeps the shared right edge.
  static const double dayMarkerBaseline =
      timeBaseline - FlightPassType.timeSize * 0.71 + 9;
  static const double dayMarkerGap = 4;

  // ── Status ──
  static const double leadBaseline = 316;
  static const double detailBaseline = 342;

  // ── Stub ──
  static const double tearY = 380;
  static const double stubPad = 40;
  static const double labelCap = FlightPassType.labelSize * 0.71;
  static const double stubLabelBaseline = tearY + stubPad + labelCap;
  static const double stubValueBaseline = stubLabelBaseline + 38;
  static const double passengerLabelBaseline = stubValueBaseline + 32;
  static const double passengerBaseline = passengerLabelBaseline + 24;

  /// The stub reads gate, seat, boarding: the first column starts at
  /// [inset], the second is centred on the card, the third ends at
  /// [contentRight].
  static const double seatWidth = 120;
  static const double seatLeft = (width - seatWidth) / 2;

  /// The gate as departure-board flaps, one per character, centred on the
  /// cap height of the seat and boarding time beside it.
  static const double flapWidth = 27;
  static const double flapHeight = 40;
  static const double flapGap = 3;
  static const double flapRadius = 4;
  static const double flapCentreY =
      stubValueBaseline - FlightPassType.stubSize * 0.71 / 2;

  /// Room for the flaps before they would crowd the seat column.
  static const double gateMaxWidth = seatLeft - inset - 4;

  static const double notchFromBottom = height - tearY;

  static const double passengerWidth = contentWidth;
}

/// Type ramp — the train and bus faces', with the airport code promoted to
/// the hero size. Geist only, never heavier than w700.
abstract final class FlightPassType {
  FlightPassType._();

  static const double codeSize = 56;
  static const double timeSize = 22;
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
  );

  /// "BLR". Medium rather than light: three capitals have to carry the card.
  static TextStyle code(Color c) => GoogleFonts.geist(
    color: c,
    fontSize: codeSize,
    fontWeight: FontWeight.w500,
    letterSpacing: -1.4,
    height: 1.0,
  );

  static TextStyle time(Color c) => GoogleFonts.geist(
    color: c,
    fontSize: timeSize,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.44,
    height: 1.0,
    fontFeatures: _tabular,
  );

  /// A scheduled time beside its revision, struck through.
  static TextStyle timeStruck(Color c) => time(c).copyWith(
    fontWeight: FontWeight.w500,
    decoration: TextDecoration.lineThrough,
    decorationColor: c,
    decorationThickness: 1.6,
  );

  static const double durationSize = 13;

  static TextStyle duration(Color c) => GoogleFonts.geist(
    color: c,
    fontSize: durationSize,
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

  static const double stubSize = 30;
  static const double flapSize = 26;

  /// Gate, seat and boarding time — what a traveller looks for at the airport.
  static TextStyle stub(Color c) => GoogleFonts.geist(
    color: c,
    fontSize: stubSize,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
    height: 1.0,
    fontFeatures: _tabular,
  );

  /// One character on a gate flap.
  static TextStyle flap(Color c) => GoogleFonts.geist(
    color: c,
    fontSize: flapSize,
    fontWeight: FontWeight.w600,
    height: 1.0,
    fontFeatures: _tabular,
  );
}
