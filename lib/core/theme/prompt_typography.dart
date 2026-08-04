import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';

/// Type roles for the prompted entry flow.
///
/// These read from the ambient [TextTheme] rather than calling
/// `GoogleFonts.inter(...)` at the call site. Half the entry chrome used to
/// call GoogleFonts directly while the other half used a bare `TextStyle`,
/// which falls back to the system font — so the scanner and the save
/// celebration rendered in a different typeface from everything around them.
///
/// Body sizes are deliberately limited to three steps (13 tertiary, 15 body,
/// 17 emphasis). The flows previously used 12, 12.5, 13, 14, 15 and 16 for the
/// same roles.
extension PromptTypography on TextTheme {
  /// The question itself. One per screen, never more than two lines.
  TextStyle get promptQuestion => (displaySmall ?? const TextStyle()).copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.15,
      );

  /// The supporting line under a question. Says where to find the value or
  /// why it is needed — never repeats the question.
  TextStyle promptHelper(ColorScheme scheme) =>
      (bodyMedium ?? const TextStyle()).copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppTokens.secondaryLabel(scheme),
      );

  /// Free-text input (names, places).
  TextStyle get promptInput => (bodyLarge ?? const TextStyle()).copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      );

  /// Document numbers and dates. Monospaced with open tracking so digits are
  /// checkable against the physical document character by character.
  TextStyle get promptInputMono => GoogleFonts.robotoMono(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      );

  /// Small label sitting above an input.
  TextStyle promptFieldLabel(ColorScheme scheme) =>
      (bodySmall ?? const TextStyle()).copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppTokens.tertiaryLabel(scheme),
      );

  /// Inline validation message, attached to the field that caused it.
  TextStyle get promptError => (bodySmall ?? const TextStyle()).copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppTheme.danger,
      );

  /// Primary call to action.
  TextStyle get promptCta => (labelLarge ?? const TextStyle()).copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      );

  /// Section heading on the review screen.
  TextStyle promptSectionLabel(ColorScheme scheme) =>
      (labelSmall ?? const TextStyle()).copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: AppTokens.tertiaryLabel(scheme),
      );

  /// Left column of a review row.
  TextStyle promptReviewLabel(ColorScheme scheme) =>
      (bodyMedium ?? const TextStyle()).copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppTokens.secondaryLabel(scheme),
      );

  /// Right column of a review row.
  TextStyle get promptReviewValue => (bodyMedium ?? const TextStyle()).copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
      );

  /// Step counter in the chrome ("3 / 7").
  TextStyle promptStepCount(ColorScheme scheme) =>
      (labelSmall ?? const TextStyle()).copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppTokens.tertiaryLabel(scheme),
      );
}
