import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Light palette — warm cream, deep navy ink, rich indigo ──────────────────
  static const Color _lightBg = Color(0xFFF5F0E8); // warm cream — not grey
  static const Color _lightSurface = Color(
    0xFFFBF8F2,
  ); // lighter cream for cards
  static const Color _lightInk = Color(0xFF0D1B2A); // deep navy — not black
  static const Color _lightPrimary = Color(0xFF1A3A6B); // rich indigo-navy
  static const Color _lightAccent = Color(0xFFD4A853); // warm gold

  // ── Dark palette — deep space navy, not generic dark ────────────────────────
  static const Color _darkBg = Color(0xFF080E1A); // deep space navy
  static const Color _darkSurface = Color(0xFF0F1829); // slightly lighter navy
  static const Color _darkInk = Color(0xFFE8EEFF); // cool white with blue tint
  static const Color _darkPrimary = Color(0xFF4D8FE0); // electric blue
  static const Color _darkAccent = Color(0xFFE8B84B); // warm amber

  static const double radiusCard = 24.0;
  static const double radiusButton = 14.0;
  static const double radiusInput = 14.0;

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final Color bg = isDark ? _darkBg : _lightBg;
    final Color surface = isDark ? _darkSurface : _lightSurface;
    final Color ink = isDark ? _darkInk : _lightInk;
    final Color primary = isDark ? _darkPrimary : _lightPrimary;
    final Color accent = isDark ? _darkAccent : _lightAccent;

    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: primary,
          secondary: accent,
          surface: surface,
          onSurface: ink,
          onPrimary: Colors.white,
        );

    final TextTheme text = GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.50,
        color: ink,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.40,
        color: ink,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.40,
        color: ink,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.30,
        color: ink,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.20,
        color: ink,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.20,
        color: ink,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 17,
        height: 1.35,
        letterSpacing: -0.20,
        color: ink,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 15,
        height: 1.35,
        letterSpacing: -0.15,
        color: ink.withValues(alpha: 0.72),
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 13,
        height: 1.30,
        letterSpacing: -0.08,
        color: ink.withValues(alpha: 0.60),
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.16,
        color: ink,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.00,
        color: ink.withValues(alpha: 0.50),
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.07,
        color: ink.withValues(alpha: 0.40),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: text,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.80),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFF7A8BAA) : const Color(0xFF5A6478),
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF3D4F6A) : const Color(0xFF9AA3B0),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: isDark
              ? BorderSide(
                  color: Colors.white.withValues(alpha: 0.07),
                  width: 0.5,
                )
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(
            color: primary.withValues(alpha: 0.55),
            width: 1.0,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.75),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
    );
  }
}

/// Shared semantic color tokens used by the reusable studio controls.
class AppTokens {
  AppTokens._();

  static const double sectionPadding = 16.0;

  static Color separator(ColorScheme scheme) =>
      scheme.outline.withValues(alpha: 0.18);

  static Color secondaryLabel(ColorScheme scheme) =>
      scheme.onSurface.withValues(alpha: 0.60);

  static Color groupedFieldFill(ColorScheme scheme, {required bool isDark}) =>
      isDark
      ? scheme.onSurface.withValues(alpha: 0.06)
      : scheme.surfaceContainerHighest.withValues(alpha: 0.55);
}
