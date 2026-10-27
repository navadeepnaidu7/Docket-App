import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// The one UI face. Geist ships Regular to Bold in `assets/fonts/` and
/// runtime fetching is off, so heavier weights are clamped rather than left to
/// miss the asset lookup and fall back to Roboto.
abstract final class AppFonts {
  static TextStyle ui({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
    FontStyle? fontStyle,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    List<Shadow>? shadows,
  }) {
    final FontWeight w = fontWeight == null
        ? FontWeight.w400
        : (fontWeight.value > 700 ? FontWeight.w700 : fontWeight);
    return GoogleFonts.geist(
      fontSize: fontSize,
      fontWeight: w,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
      fontStyle: fontStyle,
      fontFeatures: fontFeatures,
      decoration: decoration,
      shadows: shadows,
    );
  }

  /// Tabular figures for numbers that change or align (ids, dates, counts).
  static const List<FontFeature> tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];
}

class AppTheme {
  // ── Light palette — neutral paper, near-black ink ──────────────────────────
  // Colour lives in the cards, not the chrome. The page is a quiet warm grey so
  // a gradient card is the brightest thing on screen; ink doubles as the
  // primary so the main action reads as a solid black pill.
  static const Color _lightBg = Color(0xFFF4F4F2);
  static const Color _lightSurface = Color(0xFFFFFFFF); // grouped cards
  static const Color _lightElevated = Color(0xFFFFFFFF);
  static const Color _lightInk = Color(0xFF111113);
  static const Color _lightPrimary = Color(0xFF111113);
  static const Color _lightAccent = Color(0xFFD4A853); // warm gold

  // ── Dark palette — neutral graphite ─────────────────────────────────────────
  static const Color _darkBg = Color(0xFF0B0B0C);
  static const Color _darkSurface = Color(0xFF161618); // grouped cards
  static const Color _darkElevated = Color(0xFF1E1E21); // sheets / raised
  static const Color _darkInk = Color(0xFFF5F5F7);
  static const Color _darkPrimary = Color(0xFFF5F5F7); // light fill (not blue)
  static const Color _darkAccent = Color(0xFFE8B84B); // warm amber

  static const Color success = Color(0xFF30D158);
  static const Color danger = Color(0xFFFF453A);

  // ── Shape and size tokens ──────────────────────────────────────────────────
  // One value per role. The entry flows previously used twelve distinct corner
  // radii for six roles (CTAs alone appeared at 8, 14, 16 and 18) and five
  // button heights for a single role, so the same control looked different
  // depending on which file drew it.

  /// Chips, badges, small pills.
  static const double radiusControl = 10.0;

  /// All text inputs.
  static const double radiusInput = 14.0;

  /// All primary and secondary buttons. Fully rounded: the primary action is
  /// a pill, never a rounded rectangle.
  static const double radiusButton = 999.0;

  /// Grouped sections and cards.
  static const double radiusCard = 20.0;

  /// Bottom sheets. Shared by [AppleSheet] and `bottomSheetTheme`, which used
  /// to disagree (36 vs 28) while rendering side by side.
  static const double radiusSheet = 28.0;

  /// Fully rounded.
  static const double radiusPill = 999.0;

  /// Primary CTAs, inputs, action rows.
  static const double controlHeight = 56.0;

  /// Secondary and text buttons, icon hit targets.
  static const double controlHeightSm = 44.0;

  /// Public palette accessors for shared chrome (backdrops, sheets).
  static Color background(Brightness b) =>
      b == Brightness.dark ? _darkBg : _lightBg;

  static Color surface(Brightness b) =>
      b == Brightness.dark ? _darkSurface : _lightSurface;

  static Color elevated(Brightness b) =>
      b == Brightness.dark ? _darkElevated : _lightElevated;

  static Color ink(Brightness b) => b == Brightness.dark ? _darkInk : _lightInk;

  static Color primaryOf(Brightness b) =>
      b == Brightness.dark ? _darkPrimary : _lightPrimary;

  static Color accentOf(Brightness b) =>
      b == Brightness.dark ? _darkAccent : _lightAccent;

  /// Transparent system bars so each screen's own scaffold shows through
  /// the status bar and the gesture pill. An opaque nav color becomes a
  /// distinct strip that cannot match every page.
  static SystemUiOverlayStyle systemOverlayStyleFor({
    required Brightness brightness,
  }) {
    final bool dark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );
  }

  static List<Color> studioGradient(Brightness b) {
    if (b == Brightness.dark) {
      return const <Color>[
        Color(0xFF0B0B0C),
        Color(0xFF111113),
        Color(0xFF0B0B0C),
      ];
    }
    return const <Color>[
      Color(0xFFF4F4F2),
      Color(0xFFF8F8F6),
      Color(0xFFEFEFEC),
    ];
  }

  /// Cached — [GoogleFonts] resolution is expensive; never rebuild per frame.
  static ThemeData? _lightTheme;
  static ThemeData? _darkTheme;

  static ThemeData get lightTheme => _lightTheme ??= _build(Brightness.light);
  static ThemeData get darkTheme => _darkTheme ??= _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final Color bg = isDark ? _darkBg : _lightBg;
    final Color surface = isDark ? _darkSurface : _lightSurface;
    final Color elevated = isDark ? _darkElevated : _lightElevated;
    final Color ink = isDark ? _darkInk : _lightInk;
    final Color primary = isDark ? _darkPrimary : _lightPrimary;
    final Color accent = isDark ? _darkAccent : _lightAccent;
    final Color outline = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : ink.withValues(alpha: 0.12);

    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      // Dark primary is a light fill — ink must be dark for contrast on CTAs.
      onPrimary: isDark ? _darkBg : Colors.white,
      secondary: accent,
      onSecondary: isDark ? _darkBg : _lightInk,
      error: danger,
      onError: Colors.white,
      surface: surface,
      onSurface: ink,
      surfaceContainerHighest: elevated,
      outline: outline,
      outlineVariant: outline.withValues(alpha: 0.6),
    );

    final TextTheme text = GoogleFonts.geistTextTheme().copyWith(
      displayLarge: AppFonts.ui(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.05,
        color: ink,
      ),
      displayMedium: AppFonts.ui(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.08,
        color: ink,
      ),
      displaySmall: AppFonts.ui(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.7,
        height: 1.12,
        color: ink,
      ),
      titleLarge: AppFonts.ui(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.2,
        color: ink,
      ),
      titleMedium: AppFonts.ui(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.35,
        color: ink,
      ),
      titleSmall: AppFonts.ui(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: ink,
      ),
      bodyLarge: AppFonts.ui(
        fontSize: 17,
        height: 1.4,
        letterSpacing: -0.2,
        color: ink,
      ),
      bodyMedium: AppFonts.ui(
        fontSize: 15,
        height: 1.4,
        letterSpacing: -0.1,
        color: ink.withValues(alpha: isDark ? 0.72 : 0.62),
      ),
      bodySmall: AppFonts.ui(
        fontSize: 13,
        height: 1.35,
        letterSpacing: -0.05,
        color: ink.withValues(alpha: isDark ? 0.60 : 0.52),
      ),
      labelLarge: AppFonts.ui(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: ink,
      ),
      labelMedium: AppFonts.ui(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: ink.withValues(alpha: isDark ? 0.56 : 0.48),
      ),
      // Small-caps eyebrow, e.g. "WALLET BALANCE".
      labelSmall: AppFonts.ui(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
        color: ink.withValues(alpha: isDark ? 0.50 : 0.42),
      ),
    );

    final Color fieldFill = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.80);
    final Color cardColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.75);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: outline,
      textTheme: text,
      iconTheme: IconThemeData(color: ink.withValues(alpha: 0.85)),
      primaryIconTheme: const IconThemeData(color: Colors.white),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF5A6478),
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: ink.withValues(alpha: isDark ? 0.68 : 0.60),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: isDark
              ? BorderSide(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 0.5,
                )
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(
            color: primary.withValues(alpha: 0.65),
            width: 1.0,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isDark ? _darkBg : Colors.white,
          disabledBackgroundColor: ink.withValues(alpha: 0.12),
          disabledForegroundColor: ink.withValues(alpha: 0.38),
          minimumSize: const Size(48, controlHeightSm + 4),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          elevation: 0,
          splashFactory: NoSplash.splashFactory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, controlHeightSm + 4),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          side: BorderSide(color: outline),
          splashFactory: NoSplash.splashFactory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 48),
          textStyle: text.labelLarge,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: ink,
        systemOverlayStyle: systemOverlayStyleFor(brightness: brightness),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: elevated.withValues(alpha: isDark ? 0.96 : 0.98),
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: elevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusSheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? _darkInk : _lightInk,
        contentTextStyle: AppFonts.ui(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? _darkBg : Colors.white,
        ),
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 0.5, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: ink.withValues(alpha: 0.85),
        textColor: ink,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? const Color(0xFF8E9BB0) : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return success;
          return isDark
              ? Colors.white.withValues(alpha: 0.14)
              : ink.withValues(alpha: 0.18);
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        indicatorColor: primary.withValues(alpha: isDark ? 0.22 : 0.14),
        labelTextStyle: WidgetStatePropertyAll(
          text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      // Ink ripples read as stock Android chrome; presses are shown with scale
      // and a soft highlight instead (see BounceTap / DocketButton).
      splashFactory: NoSplash.splashFactory,
      highlightColor: ink.withValues(alpha: isDark ? 0.06 : 0.04),
    );
  }
}

/// Shared semantic color tokens used across studio controls and chrome.
class AppTokens {
  AppTokens._();

  static const double sectionPadding = 16.0;

  static bool _isDark(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark;

  static Color separator(ColorScheme scheme) =>
      scheme.outline.withValues(alpha: _isDark(scheme) ? 0.22 : 0.18);

  static Color secondaryLabel(ColorScheme scheme) =>
      scheme.onSurface.withValues(alpha: _isDark(scheme) ? 0.68 : 0.60);

  static Color tertiaryLabel(ColorScheme scheme) =>
      scheme.onSurface.withValues(alpha: _isDark(scheme) ? 0.52 : 0.40);

  static Color groupedFieldFill(ColorScheme scheme, {required bool isDark}) =>
      isDark
      ? scheme.onSurface.withValues(alpha: 0.08)
      : scheme.surfaceContainerHighest.withValues(alpha: 0.55);

  static Color elevatedSurface(ColorScheme scheme) => _isDark(scheme)
      ? AppTheme.elevated(Brightness.dark)
      : AppTheme.elevated(Brightness.light);

  static Color fieldFill(ColorScheme scheme, {bool focused = false}) {
    final bool dark = _isDark(scheme);
    if (dark) {
      return scheme.onSurface.withValues(alpha: focused ? 0.12 : 0.08);
    }
    return focused ? Colors.white : Colors.white.withValues(alpha: 0.62);
  }

  static Color fieldBorder(ColorScheme scheme, {bool focused = false}) {
    final bool dark = _isDark(scheme);
    if (focused) return scheme.primary.withValues(alpha: 0.65);
    return dark
        ? scheme.onSurface.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.72);
  }

  static Color sheetBackground(ColorScheme scheme) {
    final bool dark = _isDark(scheme);
    final Color base = AppTheme.elevated(
      dark ? Brightness.dark : Brightness.light,
    );
    return base.withValues(alpha: dark ? 0.92 : 0.94);
  }

  static Color sheetHandle(ColorScheme scheme) => _isDark(scheme)
      ? scheme.onSurface.withValues(alpha: 0.28)
      : const Color(0xFFE5E5EA);

  static Color scrim(ColorScheme scheme) =>
      Colors.black.withValues(alpha: _isDark(scheme) ? 0.55 : 0.35);

  static Color chipInactiveBorder(ColorScheme scheme) => _isDark(scheme)
      ? scheme.onSurface.withValues(alpha: 0.15)
      : scheme.onSurface.withValues(alpha: 0.15);

  static Color hairline(ColorScheme scheme) => _isDark(scheme)
      ? scheme.onSurface.withValues(alpha: 0.06)
      : const Color(0x1207111F);

  static Color success(ColorScheme scheme) => AppTheme.success;
  static Color danger(ColorScheme scheme) => AppTheme.danger;
}
