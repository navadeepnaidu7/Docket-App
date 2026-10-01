import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SkyPreviewMode {
  automatic('Auto'),
  sunlight('Sunlight'),
  partlyCloudy('Partly cloudy'),
  mostlyCloudy('Mostly cloudy'),
  clear('Clear sky'),
  cloudy('Cloudy'),
  fog('Fog'),
  drizzle('Drizzle'),
  rain('Rain'),
  heavyRain('Heavy rain'),
  snow('Snow'),
  thunderstorm('Thunderstorm'),
  sunset('Sunset'),
  night('Night');

  const SkyPreviewMode(this.label);
  final String label;
}

// Deliberately session-only. Release rendering always ignores overrides.
final skyPreviewProvider = StateProvider<SkyPreviewMode>(
  (ref) => SkyPreviewMode.automatic,
);
