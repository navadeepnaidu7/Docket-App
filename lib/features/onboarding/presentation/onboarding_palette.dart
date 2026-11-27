import 'package:flutter/material.dart';

/// Colours of the v5 app icon, reused so onboarding reads as the icon opening
/// up into the app. Source: tool/design_src/docket_icon/layers.html.
abstract final class OnboardingPalette {
  // Sky tile, top to horizon.
  static const Color skyTop = Color(0xFF2F8CF0);
  static const Color sky = Color(0xFF5AB0FA);
  static const Color skyHorizon = Color(0xFF8FCDFF);
  static const Color skyLo = Color(0xFFA9DBFF);
  static const Color skyShade = Color(0xFF0F4FA0);
  static const Color skyDeep = Color(0xFF0B3C7D);

  // Porcelain door.
  static const Color porcelain = Color(0xFFFFFFFF);
  static const Color porcelainMid = Color(0xFFF5F8FD);
  static const Color porcelainLo = Color(0xFFDCE8F6);
  static const Color wellTop = Color(0xFFB9D3EC);

  // Amber lock.
  static const Color sunHi = Color(0xFFFFF1BF);
  static const Color sun = Color(0xFFFFB43C);
  static const Color sunLo = Color(0xFFF06A1D);
  static const Color slot = Color(0xFF111113);

  /// Paper behind the tour in light mode: a breath of sky over warm white.
  static const Color paperTop = Color(0xFFE6F2FF);
  static const Color paper = Color(0xFFF7F9FC);

  /// Night behind the tour in dark mode.
  static const Color nightTop = Color(0xFF0C1E36);
  static const Color night = Color(0xFF07090D);

  static Color ink(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFF3F6FA) : const Color(0xFF0D1B2E);

  static Color body(Brightness b) => b == Brightness.dark
      ? const Color(0xFFF3F6FA).withValues(alpha: 0.64)
      : const Color(0xFF0D1B2E).withValues(alpha: 0.60);

  /// Accent for the one emphasised word in a headline.
  static Color accent(Brightness b) =>
      b == Brightness.dark ? sky : skyTop;
}
