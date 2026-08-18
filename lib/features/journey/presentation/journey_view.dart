import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/entry_reveal.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/bounce_tap.dart';
import '../application/journey_providers.dart';
import '../data/journey_atlas.dart';
import '../domain/journey_camera.dart';
import '../domain/journey_cluster.dart';
import '../domain/journey_event.dart';
import '../domain/journey_index.dart';
import '../domain/journey_level.dart';
import '../domain/journey_motion.dart';
import 'widgets/globe_overlay_layer.dart';
import 'widgets/globe_surface_layer.dart';
import 'widgets/journey_memory_sheet.dart';

/// Journey: the globe you explore to revisit where you have been.
///
/// Not a map and not for navigation. Four discrete levels, tap to descend, and
/// the camera flies. See `docs/features/journey.md` for the product spec.
class JourneyView extends ConsumerStatefulWidget {
  const JourneyView({super.key});

  @override
  ConsumerState<JourneyView> createState() => _JourneyViewState();
}

class _JourneyViewState extends ConsumerState<JourneyView>
    with TickerProviderStateMixin {
  /// Interpolates between the settled camera the navigator holds and the next
  /// one. The in-flight value deliberately lives here rather than in a
  /// provider: it changes every frame, and a provider would rebuild every
  /// consumer just as often.
  late final AnimationController _flight;

  /// Idle rotation at world level, before the first touch.
  late final AnimationController _idle;

  /// Arcs draw in once a level settles.
  late final AnimationController _reveal;

  GlobeCamera? _from;
  GlobeCamera? _to;

  /// Drag offsets applied on top of the settled camera, reset on every descent
  /// so a level always opens framed on what was tapped.
  double _dragLat = 0.0;
  double _dragLng = 0.0;
  bool _interacted = false;

  final GlobeSurfaceBuffers _buffers = GlobeSurfaceBuffers();
  final List<MarkerHit> _hits = <MarkerHit>[];
  final Map<String, TextPainter> _labels = <String, TextPainter>{};

  GlobeArcGeometry _arcs = GlobeArcGeometry.emptyGeometry;
  Object? _arcsBuiltFrom;

  @override
  void initState() {
    super.initState();
    _flight = AnimationController(vsync: this, duration: JourneyMotion.flightMin);
    _reveal = AnimationController(
      vsync: this,
      duration: JourneyMotion.arcReveal,
      value: 1.0,
    );
    _idle = AnimationController(
      vsync: this,
      duration: JourneyMotion.idleRevolution,
    );

    // Deferred exactly like WalletBackdrop: the frames right after a view swap
    // belong to layout, not to a looping animation.
    Future<void>.delayed(JourneyMotion.idleStartDelay, () {
      if (mounted && !_interacted) _idle.repeat();
    });
  }

  @override
  void dispose() {
    _flight.dispose();
    _idle.dispose();
    _reveal.dispose();
    for (final TextPainter painter in _labels.values) {
      painter.dispose();
    }
    super.dispose();
  }

  void _flyTo(GlobeCamera next) {
    final GlobeCamera current = _settledCamera;
    if (current == next) return;
    _from = current;
    _to = next;
    _dragLat = 0.0;
    _dragLng = 0.0;
    _flight
      ..duration = flightDuration(current, next)
      ..forward(from: 0.0);
    _reveal.forward(from: 0.0);
  }

  GlobeCamera get _settledCamera =>
      _to ?? ref.read(journeyNavigatorProvider).camera;

  /// The camera actually rendered this frame: the flight, plus drag, plus idle.
  GlobeCamera _liveCamera(GlobeCamera anchor, JourneyLevel level) {
    final GlobeCamera base = _flight.isAnimating && _from != null && _to != null
        ? cameraAt(_from!, _to!, _flight.value)
        : anchor;

    final double idleSpin =
        (!_interacted && level.idleRotates) ? _idle.value * 360.0 : 0.0;

    return base.copyWith(
      targetLat: (base.targetLat + _dragLat).clamp(-85.0, 85.0),
      targetLng: _wrapLongitude(base.targetLng + _dragLng + idleSpin),
    );
  }

  void _stopIdle() {
    if (_interacted) return;
    _interacted = true;
    _idle.stop();
  }

  void _handleTap(Offset position) {
    _stopIdle();
    for (final MarkerHit hit in _hits) {
      if (!hit.contains(position)) continue;
      final JourneyCluster cluster = hit.cluster;
      if (cluster.isMemory) {
        showJourneyMemorySheet(context, cluster.events.first);
        ref.read(journeyNavigatorProvider.notifier).select(cluster.events.first.id);
      } else {
        ref.read(journeyNavigatorProvider.notifier).descendInto(cluster);
      }
      return;
    }
  }

  void _handleDrag(DragUpdateDetails details, JourneyLevel level, Size size) {
    if (level == JourneyLevel.city) return;
    _stopIdle();
    // Scale by the projected size so a drag moves the surface under the finger
    // by roughly the same amount at every level.
    final double perPixel = 140.0 / math.max(size.width, 1.0);
    setState(() {
      _dragLng = _wrapLongitude(_dragLng - details.delta.dx * perPixel);
      _dragLat = (_dragLat + details.delta.dy * perPixel).clamp(-85.0, 85.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final JourneyNavState nav = ref.watch(journeyNavigatorProvider);
    final JourneyIndex index = ref.watch(journeyEventsProvider);
    final ClusterSet clusters = ref.watch(journeyClustersProvider(nav.scope));
    final JourneyAtlas atlas =
        ref.watch(journeyAtlasProvider).valueOrNull ?? JourneyAtlas.wireframe;

    ref.listen<JourneyNavState>(journeyNavigatorProvider,
        (JourneyNavState? previous, JourneyNavState next) {
      if (previous?.camera != next.camera) _flyTo(next.camera);
    });

    // Arc geometry only changes when the visible memories do.
    if (!identical(_arcsBuiltFrom, clusters)) {
      _arcsBuiltFrom = clusters;
      // A memory spanning several clusters appears in each of them, so the
      // route would otherwise be sampled and drawn more than once.
      final Set<JourneyEvent> unique = <JourneyEvent>{
        for (final JourneyCluster cluster in clusters.clusters)
          ...cluster.events,
      };
      _arcs = GlobeArcGeometry.build(unique.toList());
      _labels.clear();
    }

    final GlobeSurfacePalette surfacePalette = GlobeSurfacePalette.of(theme);
    final GlobeOverlayPalette overlayPalette = GlobeOverlayPalette.of(theme);

    return PopScope(
      canPop: !nav.canGoBack && nav.selectedEventId == null,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) ref.read(journeyNavigatorProvider.notifier).back();
      },
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size size = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // The globe bleeds upward behind the dashboard header. The header
              // sits in a Column above this view, and restructuring that Column
              // is a high-blast-radius change to a very large screen for a
              // purely visual win — so the globe overflows instead.
              Positioned.fill(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  maxHeight: constraints.maxHeight + _headerBleed,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (TapUpDetails d) => _handleTap(d.localPosition),
                    onPanUpdate: (DragUpdateDetails d) =>
                        _handleDrag(d, nav.level, size),
                    child: AnimatedBuilder(
                      animation: Listenable.merge(
                        <Listenable>[_flight, _idle, _reveal],
                      ),
                      builder: (BuildContext context, Widget? child) {
                        final GlobeCamera camera =
                            _liveCamera(nav.camera, nav.level);
                        return Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            RepaintBoundary(
                              child: CustomPaint(
                                painter: GlobeSurfacePainter(
                                  atlas: atlas,
                                  camera: camera,
                                  detailBand: _bandFor(camera.distance),
                                  borderOpacity: _borderOpacity(camera.distance),
                                  palette: surfacePalette,
                                  buffers: _buffers,
                                ),
                              ),
                            ),
                            RepaintBoundary(
                              child: CustomPaint(
                                painter: GlobeOverlayPainter(
                                  camera: camera,
                                  clusters: clusters.clusters,
                                  arcs: _arcs,
                                  arcReveal: _reveal.value,
                                  palette: overlayPalette,
                                  selectedEventId: nav.selectedEventId,
                                  textCache: _labels,
                                  hits: _hits,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              _JourneyChrome(
                nav: nav,
                clusters: clusters,
                index: index,
                onBack: () => ref.read(journeyNavigatorProvider.notifier).back(),
              ),
            ],
          );
        },
      ),
    );
  }

  /// How far the globe reaches up behind the header.
  static const double _headerBleed = 132.0;

  /// Level of detail from the camera's own altitude, so the field thickens
  /// continuously through a flight rather than popping at the end of it.
  static int _bandFor(double distance) {
    if (distance > 2.6) return 0;
    if (distance > 1.8) return 1;
    return 2;
  }

  /// Borders fade in as the camera drops below world altitude. Derived from
  /// distance rather than driven by a separate controller, so it can never fall
  /// out of step with where the camera actually is.
  static double _borderOpacity(double distance) {
    final double world = JourneyMotion.distanceFor(JourneyLevel.world);
    final double country = JourneyMotion.distanceFor(JourneyLevel.country);
    return ((world - distance) / (world - country)).clamp(0.0, 1.0);
  }
}

double _wrapLongitude(double value) {
  double v = value;
  while (v > 180.0) {
    v -= 360.0;
  }
  while (v < -180.0) {
    v += 360.0;
  }
  return v;
}

/// Level title, counts, back affordance and the unplaced row.
class _JourneyChrome extends StatelessWidget {
  const _JourneyChrome({
    required this.nav,
    required this.clusters,
    required this.index,
    required this.onBack,
  });

  final JourneyNavState nav;
  final ClusterSet clusters;
  final JourneyIndex index;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(
            children: <Widget>[
              if (nav.canGoBack)
                EntryReveal(
                  slideY: 8,
                  duration: const Duration(milliseconds: 320),
                  child: BounceTap(
                    onTap: onBack,
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTokens.elevatedSurface(scheme).withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        border: Border.all(
                          color: AppTokens.separator(scheme),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.chevron_left_rounded,
                              size: 18, color: scheme.onSurface),
                          const SizedBox(width: 2),
                          Text(
                            'Back',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                nav.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _summary(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTokens.secondaryLabel(scheme),
                ),
              ),
              if (index.unplaced.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  '${index.unplaced.length} '
                  '${index.unplaced.length == 1 ? "memory" : "memories"} without a place',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTokens.tertiaryLabel(scheme),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _summary() {
    if (clusters.isEmpty) {
      return 'No memories placed yet';
    }
    final int markers = clusters.clusters.length;
    final int memories = clusters.memoryCount;
    final String noun = nav.level.markerNoun;
    if (nav.level == JourneyLevel.city) {
      return '$memories ${memories == 1 ? "memory" : "memories"} here';
    }
    return '$markers $noun · $memories '
        '${memories == 1 ? "memory" : "memories"}';
  }
}
