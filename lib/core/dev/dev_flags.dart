import 'package:flutter/foundation.dart';

import 'dev_config.dart';

enum CardFluidScheme {
  auto,
  titaniumClassic,
  emerald,
  vibrantSunset,
  neonAurora,
  goldenHour;

  String get label => switch (this) {
        CardFluidScheme.auto => 'Auto (Item history)',
        CardFluidScheme.titaniumClassic => 'Titanium Classic',
        CardFluidScheme.emerald => 'Emerald & Mint',
        CardFluidScheme.vibrantSunset => 'Vibrant Sunset',
        CardFluidScheme.neonAurora => 'Neon Aurora',
        CardFluidScheme.goldenHour => 'Golden Hour',
      };
}

/// App-wide switches for mock vs consumer data sources.
@immutable
class DevFlags {
  const DevFlags({
    required this.useMockPasses,
    required this.apiBaseUrl,
    this.cardFluidScheme = CardFluidScheme.auto,
    this.mockSignedIn = false,
    this.devAuthIdToken = '',
  });

  /// Defaults from compile-time defines (no prefs applied yet).
  factory DevFlags.compileTimeDefaults() => DevFlags(
        useMockPasses: DevConfig.defaultUseMockPasses,
        apiBaseUrl: DevConfig.defaultApiBaseUrl,
        cardFluidScheme: CardFluidScheme.auto,
        mockSignedIn: false,
        devAuthIdToken: DevConfig.defaultDevAuthIdToken,
      );

  /// Release / locked: always compile-time consumer defaults.
  factory DevFlags.lockedConsumer() => DevFlags(
        useMockPasses: DevConfig.defaultUseMockPasses,
        apiBaseUrl: DevConfig.defaultApiBaseUrl,
        cardFluidScheme: CardFluidScheme.auto,
        mockSignedIn: false,
        devAuthIdToken: DevConfig.defaultDevAuthIdToken,
      );

  final bool useMockPasses;
  final String apiBaseUrl;
  final CardFluidScheme cardFluidScheme;

  /// Preview signed-in Account UI + membership name (dev/profile only).
  /// Off → Google button on card, no Account section.
  final bool mockSignedIn;

  /// Google id token for `POST /v1/auth/google` (dev bypass or a real idToken).
  final String devAuthIdToken;

  /// True when mock fixtures drive the Passes tab.
  bool get isMockPassesActive =>
      useMockPasses || apiBaseUrl.trim().isEmpty;

  DevFlags copyWith({
    bool? useMockPasses,
    String? apiBaseUrl,
    CardFluidScheme? cardFluidScheme,
    bool? mockSignedIn,
    String? devAuthIdToken,
  }) {
    return DevFlags(
      useMockPasses: useMockPasses ?? this.useMockPasses,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      cardFluidScheme: cardFluidScheme ?? this.cardFluidScheme,
      mockSignedIn: mockSignedIn ?? this.mockSignedIn,
      devAuthIdToken: devAuthIdToken ?? this.devAuthIdToken,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DevFlags &&
          useMockPasses == other.useMockPasses &&
          apiBaseUrl == other.apiBaseUrl &&
          cardFluidScheme == other.cardFluidScheme &&
          mockSignedIn == other.mockSignedIn &&
          devAuthIdToken == other.devAuthIdToken;

  @override
  int get hashCode => Object.hash(
        useMockPasses,
        apiBaseUrl,
        cardFluidScheme,
        mockSignedIn,
        devAuthIdToken,
      );
}
