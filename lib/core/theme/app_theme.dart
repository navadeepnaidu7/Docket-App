import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color _ink = Color(0xFF0B1B34);
  static const Color _blue = Color(0xFF1F3A60);
  static const Color _teal = Color(0xFFC9A760);
  static const Color _surface = Color(0xFFF6F2EA);

  // Consistent radius tokens
  static const double radiusCard = 24.0;
  static const double radiusButton = 14.0;
  static const double radiusInput = 14.0;

  static ThemeData get lightTheme {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: _blue,
      brightness: Brightness.light,
      surface: _surface,
    ).copyWith(
      primary: _blue,
      secondary: _teal,
      surface: _surface,
    );

    final TextTheme textTheme = GoogleFonts.interTextTheme().copyWith(
      displaySmall: GoogleFonts.inter(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        color: _ink,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: _ink,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: _ink,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 17,
        height: 1.5,
        letterSpacing: -0.2,
        color: _ink,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 15,
        height: 1.45,
        letterSpacing: -0.15,
        color: _ink.withValues(alpha: 0.75),
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: _ink.withValues(alpha: 0.45),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.92),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.4), width: 1.0),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
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
        color: Colors.white.withValues(alpha: 0.85),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
    );
  }
}
