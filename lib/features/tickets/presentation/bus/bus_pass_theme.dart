import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/wallet/wallet_card_metrics.dart';

/// Geometry for the bus pass face.
///
/// The card is one clean rounded rectangle: a brand header over a paper body,
/// with no die-cut stub notch between them. Physical-ticket notches read as
/// decoration on a phone and cost a custom clipper plus a border that has to
/// trace the same path.
abstract final class BusPassMetrics {
  BusPassMetrics._();

  /// Derived from [WalletCardMetrics.ticketCanvas] — the canvas the movie face
  /// uses and the one the train canvas was matched to, so all three passes
  /// resolve to the same box in the carousel.
  static const double width = WalletCardMetrics.ticketCanvasWidth;
  static const double height = WalletCardMetrics.ticketCanvasHeight;
  static const Size canvas = WalletCardMetrics.ticketCanvas;

  /// Generous, per the brief. Matches the movie face's card radius.
  static const double cornerR = 30;

  static const double inset = 24;
  static const double contentWidth = width - inset * 2;

  /// Height of the brand header panel.
  ///
  /// A little under half the card: enough for the wordmark and the city route
  /// line to sit at opposite ends with the coach between them, while leaving
  /// the body room for four rows of booking detail without crowding.
  static const double headerHeight = 286;

  /// How far the coach photograph bleeds past the card's right edge, so the
  /// vehicle reads as continuing rather than being cropped to fit.
  static const double coachOverflow = 26;

  /// Width of the coach image. Wider than the space it occupies because of
  /// [coachOverflow].
  ///
  /// Retuned for the close-up photograph, which is 1.31:1 where the previous
  /// full-side shot was 2.19:1. Holding the old 252 width would have made the
  /// vehicle 192dp tall instead of 115 and pushed it into the wordmark.
  static const double coachWidth = 218;

  /// How far the coach sits above the header's bottom edge.
  ///
  /// The coach and the route line are stacked, not side by side: at this card
  /// width there is no arrangement where a legible close-up sits beside a
  /// single-line "Bengaluru to Mysuru" without one running into the other.
  /// This lands the vehicle between the wordmark and the route, overlapping
  /// neither — the wordmark is short and stays left of the coach's edge.
  static const double coachBottom = 96;

  /// Left edge the coach occupies once [coachOverflow] is accounted for.
  /// Header type has to stay clear of this, or it renders under the vehicle.
  static const double coachLeft = width + coachOverflow - coachWidth;

  /// Route rail between the FROM and TO dots on the body.
  static const double stopDotSize = 10;
  static const double stopRailWidth = 22;
}

/// Type ramp for the bus face.
///
/// Inter, matching the movie face. The train face uses Geist and Instrument
/// Serif because it is traced from a Figma export with those metrics baked
/// into its baselines; the bus card has no such constraint, and the brief was
/// to read as cleanly as the movie ticket, which means the same letterforms.
///
/// Sizes stay on a small ladder — 38 / 24 / 17 / 15 / 12 / 11 — so a label is
/// the same size wherever it appears on the card. Reach for the closest role
/// rather than adding a step.
abstract final class BusPassType {
  BusPassType._();

  /// Brand wordmark, light run.
  static TextStyle wordmarkLead(Color color) => GoogleFonts.inter(
        color: color,
        fontSize: 38,
        fontWeight: FontWeight.w400,
        letterSpacing: -1.2,
        height: 1.0,
      );

  /// Brand wordmark, bold run.
  static TextStyle wordmarkTail(Color color) => GoogleFonts.inter(
        color: color,
        fontSize: 38,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.0,
      );

  /// Operator name when the brand ships no wordmark.
  static TextStyle operatorName(Color color) => GoogleFonts.inter(
        color: color,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.1,
      );

  /// The city pair on the header — "Bengaluru to Mysuru".
  static TextStyle headerRoute(Color color) => GoogleFonts.inter(
        color: color,
        fontSize: 24,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.5,
        height: 1.15,
      );

  /// Every field label on the card.
  ///
  /// Sentence case at the train face's label metrics, not the letterspaced
  /// small caps this started as: the other passes set "Date" and "Passenger"
  /// this way, and an all-caps ramp made the bus card the odd one out.
  static TextStyle label(Color color) => GoogleFonts.inter(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.0,
      );

  /// A stop name, and the headline value in the detail grid.
  static TextStyle stopName(Color color) => GoogleFonts.inter(
        color: color,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.2,
      );

  /// The city under a stop name, and other secondary lines.
  static TextStyle secondary(Color color) => GoogleFonts.inter(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.2,
      );

  /// Grid values — date, departure, seat, fare.
  static TextStyle value(Color color) => GoogleFonts.inter(
        color: color,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        height: 1.0,
      );

  /// The closing advisory line.
  static TextStyle note(Color color) => GoogleFonts.inter(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.35,
      );

  /// Kicks off the network fetch for the weights this face uses so `main()`'s
  /// `GoogleFonts.pendingFonts()` wait covers them. Return values are
  /// deliberately discarded — asking is the whole point.
  static void warmUp() {
    wordmarkTail(const Color(0xFF000000));
    headerRoute(const Color(0xFF000000));
    value(const Color(0xFF000000));
    label(const Color(0xFF000000));
  }
}
