import 'package:flutter/foundation.dart';

/// Central registry for bundled asset paths.
///
/// Layout:
/// - `assets/auth/` — third-party sign-in branding (official vendor filenames)
/// - `assets/wallet/` — in-app card visuals grouped by document type
abstract final class AppAssets {
  AppAssets._();

  // ── Branding ─────────────────────────────────────────────────────────────────

  /// Docket wordmark / app icon SVG (rounded square + monogram).
  static const String docketLogo = 'assets/branding/docket_logo.svg';

  /// BookMyShow mark (movie pass chrome).
  static const String bookMyShowLogo = 'assets/passes/bookmyshow.svg';

  /// BookMyShow official logo vector (for footer).
  static const String bookMyShowLogoVector = 'assets/passes/bookmyshow-logo-vector.svg';

  /// Zomato / District mark (movie pass chrome).
  static const String zomatoLogo = 'assets/passes/zomato.svg';

  /// Zomato District official logo vector (for footer).
  static const String districtLogo = 'assets/passes/district-logo.svg';

  /// Clock-history icon for past / expired passes.
  static const String passesHistory = 'assets/passes/history_clock.svg';

  // ── Auth ─────────────────────────────────────────────────────────────────────

  /// Google Sign-In button assets (dark, rounded). Names follow Google branding.
  static const String googleSignInAndroid =
      'assets/auth/google/android_dark_rd_SI.svg';
  static const String googleSignInIos =
      'assets/auth/google/ios_dark_rd_SI.svg';
  static const String googleSignInIosUnavailable =
      'assets/auth/google/ios_dark_rd_na.svg';

  /// Platform-appropriate Google Sign-In button for the current target.
  static String get googleSignInButton {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return googleSignInIos;
      default:
        return googleSignInAndroid;
    }
  }

  // ── Wallet: passport ───────────────────────────────────────────────────────

  static const String passportAshokaChakra =
      'assets/wallet/passport/ashoka_chakra.svg';

  /// Pre-rasterized emblem PNGs sized for specific card placements.
  /// Rasterized from `tool/design_src/emblem_of_india.svg`, which is kept in the
  /// repo as the design master but deliberately not bundled into the APK.
  static const String passportEmblemHologram =
      'assets/wallet/passport/emblems/emblem_28.png';
  static const String passportEmblemHeader =
      'assets/wallet/passport/emblems/emblem_34.png';
  static const String passportEmblemCompact =
      'assets/wallet/passport/emblems/emblem_22.png';
  static const String passportEmblemStandard =
      'assets/wallet/passport/emblems/emblem_32.png';
  static const String passportEmblemWatermark =
      'assets/wallet/passport/emblems/emblem_120.png';
  static const String passportEmblemLarge =
      'assets/wallet/passport/emblems/emblem_140.png';

  // ── Wallet: Aadhaar ────────────────────────────────────────────────────────

  static const String aadhaarLogo = 'assets/wallet/aadhaar/logo.svg';

  // ── Navigation bar ─────────────────────────────────────────────────────────

  static const String navIdsFilled = 'assets/navbar/ids_filled.svg';
  static const String navIdsUnfilled = 'assets/navbar/ids_unfilled.svg';
  static const String navPassesFilled = 'assets/navbar/passes_filled.svg';
  static const String navPassesUnfilled = 'assets/navbar/passes_unfilled.svg';

  static const String navAltIdsFilled = 'assets/navbar/alt/ids_filled.svg';
  static const String navAltIdsUnfilled = 'assets/navbar/alt/ids_unfilled.svg';
  static const String navAltPassesFilled = 'assets/navbar/alt/passes_filled.svg';
  static const String navAltPassesUnfilled = 'assets/navbar/alt/passes_unfilled.svg';
}