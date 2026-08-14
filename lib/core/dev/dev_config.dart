import 'package:flutter/foundation.dart';

/// Compile-time defaults via `--dart-define`.
///
/// ```bash
/// flutter run \
///   --dart-define=USE_MOCK_PASSES=false \
///   --dart-define=API_BASE_URL=https://api.staging.example.com
/// ```
abstract final class DevConfig {
  DevConfig._();

  /// When true (default in debug), Passes uses [MockPassRepository].
  static const bool defaultUseMockPasses = bool.fromEnvironment(
    'USE_MOCK_PASSES',
    defaultValue: true,
  );

  /// Backend origin for [RemotePassRepository], no trailing slash.
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Force-show Developer settings even in release (CI demos only).
  static const bool forceDevMenu = bool.fromEnvironment(
    'FORCE_DEV_MENU',
    defaultValue: false,
  );

  /// Google id token exchanged against `POST /v1/auth/google`.
  ///
  /// Local only: this is the server's `AUTH_DEV_BYPASS_TOKEN`. Never bake a
  /// production token into a release build.
  static const String defaultDevAuthIdToken = String.fromEnvironment(
    'DEV_AUTH_ID_TOKEN',
    defaultValue: '',
  );

  /// In-app Developer section + runtime toggles.
  static bool get showDevMenu =>
      forceDevMenu || kDebugMode || kProfileMode;

  /// Runtime flag changes allowed (never in pure release without force).
  static bool get allowRuntimeOverrides => showDevMenu;
}
