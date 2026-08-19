import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/journey_providers.dart';
import '../data/journey_atlas.dart';
import '../domain/journey_camera.dart';
import '../domain/journey_event.dart';
import '../domain/journey_index.dart';
import '../domain/journey_level.dart';
import '../domain/journey_motion.dart';
import '../domain/place.dart';
import 'widgets/globe_surface_layer.dart';

/// How much of the world a set of memories actually covers.
final class JourneyReach {
  const JourneyReach({
    required this.countries,
    required this.regions,
    required this.cities,
    required this.memories,
  });

  final int countries;
  final int regions;
  final int cities;
  final int memories;

  bool get isEmpty => memories == 0;

  static JourneyReach of(JourneyIndex index) {
    final Set<String> countries = <String>{};
    final Set<String> regions = <String>{};
    final Set<String> cities = <String>{};

    for (final JourneyEvent event in index.placed) {
      for (final JourneyStop stop in event.placedStops) {
        final Place place = stop.place!;
        if (place.countryCode != null) countries.add(place.countryCode!);
        if (place.regionCode != null) regions.add(place.regionCode!);
        final String? city = place.cityKey;
        if (city != null) cities.add(city);
      }
    }

    return JourneyReach(
      countries: countries.length,
      regions: regions.length,
      cities: cities.length,
      memories: index.placed.length,
    );
  }
}

/// A small, slowly turning globe carrying the user's real coverage.
///
/// Runs the *production* surface painter at a teaser preset — coarsest dot band,
/// no borders, no gestures — rather than a decorative lookalike, so it can never
/// drift out of sync with the real thing, and so what it shows is true.
class JourneyTeaserGlobe extends ConsumerStatefulWidget {
  const JourneyTeaserGlobe({super.key, this.size = 132.0});

  final double size;

  @override
  ConsumerState<JourneyTeaserGlobe> createState() => _JourneyTeaserGlobeState();
}

class _JourneyTeaserGlobeState extends ConsumerState<JourneyTeaserGlobe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  final GlobeSurfaceBuffers _buffers = GlobeSurfaceBuffers();

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: JourneyMotion.idleRevolution,
    );
    // Deferred like every other looping controller in this app.
    Future<void>.delayed(JourneyMotion.idleStartDelay, () {
      if (mounted) _spin.repeat();
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final JourneyAtlas atlas =
        ref.watch(journeyAtlasProvider).valueOrNull ?? JourneyAtlas.wireframe;
    final GlobeCamera home =
        initialCameraFor(ref.watch(journeyEventsProvider));
    final GlobeSurfacePalette palette = GlobeSurfacePalette.of(Theme.of(context));

    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _spin,
          builder: (BuildContext context, Widget? child) {
            return CustomPaint(
              painter: GlobeSurfacePainter(
                atlas: atlas,
                camera: home.copyWith(
                  targetLng: _wrap(home.targetLng + _spin.value * 360.0),
                  distance: JourneyMotion.distanceFor(JourneyLevel.world),
                ),
                // Coarsest band only. At this size the full field is a smudge
                // and costs eight times as much to draw.
                detailBand: 0,
                borderOpacity: 0.0,
                palette: palette,
                buffers: _buffers,
              ),
            );
          },
        ),
      ),
    );
  }

  static double _wrap(double value) {
    double v = value;
    while (v > 180.0) {
      v -= 360.0;
    }
    while (v < -180.0) {
      v += 360.0;
    }
    return v;
  }
}

/// The Journey page in the membership card's story deck.
class JourneyTeaserPage extends ConsumerWidget {
  const JourneyTeaserPage({
    super.key,
    required this.ink,
    required this.muted,
  });

  final Color ink;
  final Color muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final JourneyReach reach = JourneyReach.of(ref.watch(journeyEventsProvider));

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const JourneyTeaserGlobe(),
        const SizedBox(height: 24),
        Text(
          reach.isEmpty ? 'Your atlas is waiting' : _headline(reach),
          style: TextStyle(
            color: ink,
            fontSize: 28,
            height: 1.16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          reach.isEmpty
              ? 'Add a pass and it will appear on the globe.'
              : 'Open Journey to walk back through it.',
          style: TextStyle(color: muted, fontSize: 15, height: 1.4),
        ),
      ],
    );
  }

  static String _headline(JourneyReach reach) {
    final String cities =
        '${reach.cities} ${reach.cities == 1 ? "place" : "places"}';
    if (reach.countries > 1) {
      return 'You have been to $cities across ${reach.countries} countries.';
    }
    if (reach.regions > 1) {
      return 'You have been to $cities across ${reach.regions} states.';
    }
    return 'You have been to $cities.';
  }
}
