import 'package:flutter/foundation.dart';

import 'dev_config.dart';

/// App-wide switches for mock vs consumer data sources.
@immutable
class DevFlags {
  const DevFlags({
    required this.useMockPasses,
    required this.apiBaseUrl,
  });

  /// Defaults from compile-time defines (no prefs applied yet).
  factory DevFlags.compileTimeDefaults() => DevFlags(
        useMockPasses: DevConfig.defaultUseMockPasses,
        apiBaseUrl: DevConfig.defaultApiBaseUrl,
      );

  /// Release / locked: always compile-time consumer defaults.
  factory DevFlags.lockedConsumer() => DevFlags(
        useMockPasses: DevConfig.defaultUseMockPasses,
        apiBaseUrl: DevConfig.defaultApiBaseUrl,
      );

  final bool useMockPasses;
  final String apiBaseUrl;

  /// True when mock fixtures drive the Passes tab.
  bool get isMockPassesActive =>
      useMockPasses || apiBaseUrl.trim().isEmpty;

  DevFlags copyWith({
    bool? useMockPasses,
    String? apiBaseUrl,
  }) {
    return DevFlags(
      useMockPasses: useMockPasses ?? this.useMockPasses,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DevFlags &&
          useMockPasses == other.useMockPasses &&
          apiBaseUrl == other.apiBaseUrl;

  @override
  int get hashCode => Object.hash(useMockPasses, apiBaseUrl);
}
