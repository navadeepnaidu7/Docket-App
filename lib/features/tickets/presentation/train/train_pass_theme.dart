import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/wallet/wallet_card_metrics.dart';

/// Palette and geometry for the train pass face.
///
/// Every number here was measured off the Figma export by taking the min/max of
/// each glyph path's coordinates, then converting cap heights to font sizes at
/// Geist's 0.727 em and Instrument Serif's ~0.70 em. Coordinates are
/// **card-local** on a [TrainPassMetrics.canvas] box — the raw SVG has the card
/// offset by (32, 16) inside its artboard, and that offset is already removed.
///
/// The face is deliberately fixed-light in both themes. A wallet card is a
/// facsimile of a paper document; [WalletPassportCard] does the same.
abstract final class TrainPassPalette {
  TrainPassPalette._();

  static const Color surface = Color(0xFFFFF6F6);
  static const Color border = Color(0xFFEAD5D8);
  static const Color ink = Color(0xFF1F1619);
  static const Color muted = Color(0xFF6B5A5E);
  static const Color rule = Color(0xFFE8D8DA);
  static const Color qrBorder = Color(0xFFE5D1D4);
  static const Color chipFill = Color(0xFFE8F5E9);
  static const Color chipInk = Color(0xFF2E7D32);

  /// Deeper blush the status band settles into, so the band reads as its own
  /// zone without needing a hard rule across the card.
  static const Color bandTint = Color(0xFFFBEDEE);

  static const Color toneWarning = Color(0xFFB26A00);
  static const Color toneCritical = Color(0xFFC0392B);
}

/// The palette resolved for one pass state.
///
/// An expired pass keeps the layout and loses the warmth — same card, drained,
/// so a spent ticket never reads as a live one at a glance.
@immutable
class TrainPassColors {
  const TrainPassColors({
    required this.surface,
    required this.bandTint,
    required this.border,
    required this.ink,
    required this.muted,
    required this.rule,
    required this.qrBorder,
    required this.chipFill,
    required this.chipInk,
    required this.ghostAlpha,
    required this.shadowAlpha,
  });

  final Color surface;
  final Color bandTint;
  final Color border;
  final Color ink;
  final Color muted;
  final Color rule;
  final Color qrBorder;
  final Color chipFill;
  final Color chipInk;
  final double ghostAlpha;
  final double shadowAlpha;

  static const TrainPassColors active = TrainPassColors(
    surface: TrainPassPalette.surface,
    bandTint: TrainPassPalette.bandTint,
    border: TrainPassPalette.border,
    ink: TrainPassPalette.ink,
    muted: TrainPassPalette.muted,
    rule: TrainPassPalette.rule,
    qrBorder: TrainPassPalette.qrBorder,
    chipFill: TrainPassPalette.chipFill,
    chipInk: TrainPassPalette.chipInk,
    ghostAlpha: 0.06,
    shadowAlpha: 0.25,
  );

  static const TrainPassColors expired = TrainPassColors(
    surface: Color(0xFFF7F5F5),
    bandTint: Color(0xFFF0EDED),
    border: Color(0xFFE2DDDE),
    ink: Color(0xFF4A4548),
    muted: Color(0xFF8A8285),
    rule: Color(0xFFE4E0E0),
    qrBorder: Color(0xFFE0DBDC),
    chipFill: Color(0xFFEDEAEA),
    chipInk: Color(0xFF6B5A5E),
    ghostAlpha: 0.04,
    shadowAlpha: 0.14,
  );

  static TrainPassColors of({required bool isExpired}) =>
      isExpired ? TrainPassColors.expired : TrainPassColors.active;

  /// Colour for a status-band tone. Expired passes flatten every tone to
  /// [muted] — a spent ticket has no live state worth colouring.
  Color tone(Color live) => this == TrainPassColors.expired ? muted : live;

  @override
  bool operator ==(Object other) =>
      other is TrainPassColors &&
      other.surface == surface &&
      other.ink == ink &&
      other.ghostAlpha == ghostAlpha;

  @override
  int get hashCode => Object.hash(surface, ink, ghostAlpha);
}

abstract final class TrainPassMetrics {
  TrainPassMetrics._();

  /// Derived from [WalletCardMetrics.trainCanvas] rather than restated, because
  /// the two were independent literals and the card is scaled by the canvas
  /// while it is *laid out* against these — so a change to one and not the
  /// other silently stretched every baseline instead of failing.
  static const double width = WalletCardMetrics.trainCanvasWidth;
  static const double height = WalletCardMetrics.trainCanvasHeight;
  static const Size canvas = Size(width, height);

  static const double cornerR = 32;

  /// Left inset; the content column is [width] - 2 * [inset] wide.
  static const double inset = 24;
  static const double contentRight = width - inset; // 342

  // ── Station header ──
  static const double codeBaseline = 88;
  static const double codeSize = 57;
  static const double codeMaxWidth = 112.5;
  static const double connectorY = 75.5;

  /// Clear space held between a station code and the first dash of the
  /// connector. The export leaves 31.5 on the left and 30.3 on the right.
  static const double codeConnectorGap = 31;
  static const double stationNameBaseline = 118;

  static const double headerRuleY = 144.5;

  // ── Train identity ──
  static const double trainNameBaseline = 181;
  static const double trainNumberBaseline = 202;
  static const double chipLeft = 295;
  static const double chipTop = 171;
  static const double chipWidth = 47;
  static const double chipHeight = 29;

  // ── Data grid ──
  static const double gridColumnTwoX = 192;
  static const double gridFirstLabelBaseline = 245;
  static const double gridLabelToValue = 22;
  static const double gridRowPitch = 54;

  static double gridLabelBaseline(int row) =>
      gridFirstLabelBaseline + row * gridRowPitch;
  static double gridValueBaseline(int row) =>
      gridLabelBaseline(row) + gridLabelToValue;

  // ── Passenger block ──
  static const double tearRuleY = 407.25;
  static const double passengerLabelBaseline = 443;
  static const double passengerValueBaseline = 465;
  static const double pnrLabelBaseline = 493;
  static const double pnrValueBaseline = 515;

  /// Right edge of the passenger column, leaving a gutter before the QR.
  static const double passengerRight = width - 104; // 262

  // ── QR ──
  static const double qrLeft = 272.5;
  static const double qrTop = 441.5;
  static const double qrSize = 69;

  // ── Status band ──
  //
  // The export gave the band 90dp for a single 15dp line, which made the card
  // taller than every other pass for no content — see
  // [WalletCardMetrics.trainCanvas]. 58dp still centres the line with 21dp of
  // clear space above it (the content block ends at [pnrValueBaseline]) and
  // leaves the band reading as its own zone, which is all it was doing with 90.
  static const double bandTop = 536;
  static const double bandHeight = height - bandTop; // 58

  /// Size of the ghosted wordmark behind the band messages, and how far its
  /// baseline is pushed past the card's bottom edge so the clip cuts it.
  ///
  /// Both are ratios of [bandHeight], not literals: at the export's 68/-24
  /// against a 58dp band the wordmark's cap line rose to the band's top edge
  /// and crowded the message it is supposed to sit behind. Expressed this way,
  /// retuning the band height carries the backdrop with it.
  static const double bandGhostSize = bandHeight * 0.755;
  static const double bandGhostDrop = bandHeight * 0.267;
}

/// Type ramp. Geist for everything structural, Instrument Serif for the codes.
///
/// Geist tops out at w700 and Instrument Serif ships only w400 — nothing here
/// may ask for a weight outside that, or google_fonts silently synthesises the
/// nearest one and the card stops matching the export.
abstract final class TrainPassType {
  TrainPassType._();

  static TextStyle stationCode(Color color) => GoogleFonts.instrumentSerif(
        color: color,
        fontSize: TrainPassMetrics.codeSize,
        fontWeight: FontWeight.w400,
        height: 1.0,
      );

  static TextStyle stationName(Color color) => GoogleFonts.geist(
        color: color,
        fontSize: 10.75,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.0,
      );

  static TextStyle trainName(Color color) => GoogleFonts.geist(
        color: color,
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.0,
      );

  static TextStyle trainNumber(Color color) => GoogleFonts.geist(
        color: color,
        fontSize: 11.7,
        fontWeight: FontWeight.w500,
        height: 1.0,
      );

  static TextStyle chip(Color color) => GoogleFonts.geist(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.0,
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

  static TextStyle secondary(Color color) => GoogleFonts.geist(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.0,
      );

  static TextStyle bandMessage(Color color) => GoogleFonts.geist(
        color: color,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.0,
      );

  static TextStyle bandGhost(Color color) => GoogleFonts.instrumentSerif(
        color: color,
        fontSize: TrainPassMetrics.bandGhostSize,
        fontWeight: FontWeight.w400,
        height: 1.0,
      );

  /// Kicks off the network fetch for every weight this face uses, so `main()`'s
  /// `GoogleFonts.pendingFonts()` wait covers them.
  ///
  /// google_fonts starts loading on the first call for a family+weight, so the
  /// return values are deliberately discarded — asking is the whole point.
  static void warmUp() {
    stationCode(const Color(0xFF000000));
    label(const Color(0xFF000000));
    value(const Color(0xFF000000));
  }
}
