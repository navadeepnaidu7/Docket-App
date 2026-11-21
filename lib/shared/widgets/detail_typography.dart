import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type roles shared by pass, document and payment-card detail screens.
///
/// The main detail roles use a compact 17/16/14/13 ramp. Small chips and
/// footnotes retain their quieter 12/11 sizes. Reuse a role rather than adding
/// a screen-specific size.
///
/// This covers detail **chrome**: headers, rows, pills, timelines. It is not for
/// the card faces. `TrainPassType` (Geist + Instrument Serif) and the movie and
/// bus faces are facsimiles of printed tickets with their own ramps, and are
/// meant to look like documents rather than like the app.
abstract final class DetailType {
  DetailType._();

  /// Screen header — "E-Ticket". One per screen.
  static TextStyle screenTitle(Color color) => GoogleFonts.inter(
    color: color,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  /// Heading above a group of rows.
  static TextStyle sectionTitle(Color color) => GoogleFonts.inter(
    color: color,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  /// The name of a thing in a list — a station, a cinema, a stop.
  static TextStyle itemTitle(Color color) => GoogleFonts.inter(
    color: color,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.2,
  );

  /// Muted left-hand side of a label/value pair.
  static TextStyle label(Color color) => GoogleFonts.inter(
    color: color,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  /// The value that answers a [label].
  static TextStyle value(Color color) => GoogleFonts.inter(
    color: color,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  /// Secondary line under a title — platform, date, route.
  static TextStyle caption(Color color) => GoogleFonts.inter(
    color: color,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  /// Text inside a chip or pill, where the shape already carries emphasis.
  static TextStyle pill(Color color) => GoogleFonts.inter(
    color: color,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.0,
  );

  /// Footnotes and legends — "All times are in IST".
  static TextStyle micro(Color color) => GoogleFonts.inter(
    color: color,
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  /// A PNR or booking reference shown for the traveller to read out or check
  /// against the physical ticket. Open tracking on purpose: these are read
  /// character by character, not as a word, and the extra step in size is
  /// what makes them findable on a crowded screen.
  static TextStyle code(Color color) => GoogleFonts.inter(
    color: color,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.2,
  );

  /// Kicks off the network fetch for every weight these roles use, so `main()`'s
  /// `GoogleFonts.pendingFonts()` wait covers them.
  ///
  /// google_fonts starts loading on the first call for a family+weight, so the
  /// return values are deliberately discarded — asking is the whole point.
  static void warmUp() {
    const Color black = Color(0xFF000000);
    screenTitle(black);
    itemTitle(black);
    label(black);
    caption(black);
  }
}
