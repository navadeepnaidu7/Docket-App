import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/geo_point.dart';
import '../../domain/globe_projection.dart';
import '../../domain/journey_camera.dart';
import '../../domain/journey_cluster.dart';
import '../../domain/journey_event.dart';
import '../../domain/journey_motion.dart';
import '../../domain/pin_declutter.dart';

/// Arc geometry for a set of memories, in sphere space.
///
/// Built once per cluster set and reused across frames. Arc samples do not
/// depend on the camera, so the only per-frame work is projecting them — this
/// is the general rule the whole render layer follows: sphere space is
/// precomputed and immutable, screen space is per frame.
final class GlobeArcGeometry {
  const GlobeArcGeometry({
    required this.x,
    required this.y,
    required this.z,
    required this.starts,
    required this.lengths,
    required this.eventIds,
  });

  static const GlobeArcGeometry emptyGeometry = GlobeArcGeometry(
    x: <double>[],
    y: <double>[],
    z: <double>[],
    starts: <int>[],
    lengths: <int>[],
    eventIds: <String>[],
  );

  final List<double> x;
  final List<double> y;
  final List<double> z;

  /// One entry per drawn segment.
  final List<int> starts;
  final List<int> lengths;
  final List<String> eventIds;

  int get segmentCount => starts.length;

  /// Samples every route in [events] into one flat buffer.
  static GlobeArcGeometry build(List<JourneyEvent> events) {
    final List<double> x = <double>[];
    final List<double> y = <double>[];
    final List<double> z = <double>[];
    final List<int> starts = <int>[];
    final List<int> lengths = <int>[];
    final List<String> ids = <String>[];

    for (final JourneyEvent event in events) {
      if (!event.isRoute) continue;
      final List<JourneyStop> stops = event.placedStops.toList();
      for (int i = 0; i < stops.length - 1; i++) {
        final Vec3 from = stops[i].place!.point.unitVector;
        final Vec3 to = stops[i + 1].place!.point.unitVector;
        final List<Vec3> samples = sampleArc(from, to);
        if (samples.length < 2) continue;

        starts.add(x.length);
        lengths.add(samples.length);
        ids.add(event.id);
        for (final Vec3 sample in samples) {
          x.add(sample.x);
          y.add(sample.y);
          z.add(sample.z);
        }
      }
    }

    return GlobeArcGeometry(
      x: x, y: y, z: z, starts: starts, lengths: lengths, eventIds: ids,
    );
  }
}

/// Colours for arcs, clusters and pins.
final class GlobeOverlayPalette {
  const GlobeOverlayPalette({
    required this.arc,
    required this.marker,
    required this.markerInk,
    required this.pin,
    required this.selected,
    required this.label,
    required this.shadow,
  });

  factory GlobeOverlayPalette.of(ThemeData theme) {
    final bool isDark = theme.brightness == Brightness.dark;
    return GlobeOverlayPalette(
      arc: isDark ? const Color(0xFFE8B84B) : const Color(0xFFB07C1B),
      marker: isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1A3A6B),
      markerInk: isDark ? const Color(0xFF0A0A0D) : const Color(0xFFFFFFFF),
      pin: isDark ? const Color(0xFFE8B84B) : const Color(0xFFC8891F),
      selected: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0D1B2A),
      label: isDark ? const Color(0xFFF2F2F7) : const Color(0xFF0D1B2A),
      shadow: const Color(0xFF000000),
    );
  }

  final Color arc;
  final Color marker;
  final Color markerInk;
  final Color pin;
  final Color selected;
  final Color label;
  final Color shadow;
}

/// A marker's on-screen position, kept so hit testing matches what was drawn.
final class MarkerHit {
  const MarkerHit(this.cluster, this.center, this.radius);

  final JourneyCluster cluster;
  final Offset center;
  final double radius;

  bool contains(Offset point) => (point - center).distance <= radius;
}

/// Draws flight and rail arcs, cluster bubbles and city pins.
///
/// Kept separate from the surface layer because it repaints at a different
/// rate: a pulsing selection or a revealing arc must not force twelve thousand
/// land dots to re-rasterise.
class GlobeOverlayPainter extends CustomPainter {
  GlobeOverlayPainter({
    required this.camera,
    required this.clusters,
    required this.arcs,
    required this.arcReveal,
    required this.palette,
    required this.selectedEventId,
    required this.textCache,
    required this.hits,
  });

  final GlobeCamera camera;
  final List<JourneyCluster> clusters;
  final GlobeArcGeometry arcs;

  /// 0 to 1. Arcs draw progressively as a level settles.
  final double arcReveal;

  final GlobeOverlayPalette palette;
  final String? selectedEventId;

  /// Laid-out labels, keyed by cluster key. `layout()` is the expensive call,
  /// so it happens once per cluster set rather than once per frame.
  final Map<String, TextPainter> textCache;

  /// Written during paint so the gesture handler hit-tests exactly what the
  /// user can see, including any declutter nudge.
  final List<MarkerHit> hits;

  @override
  void paint(Canvas canvas, Size size) {
    final ProjectionParams params = ProjectionParams.forCamera(camera, size);
    hits.clear();

    _paintArcs(canvas, params);
    _paintMarkers(canvas, params);
  }

  void _paintArcs(Canvas canvas, ProjectionParams params) {
    if (arcs.segmentCount == 0 || arcReveal <= 0.01) return;

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int segment = 0; segment < arcs.segmentCount; segment++) {
      final int start = arcs.starts[segment];
      final int length = arcs.lengths[segment];
      final bool isSelected = arcs.eventIds[segment] == selectedEventId;

      // Reveal by drawing a growing prefix of the samples.
      final int drawn = math.max(2, (length * arcReveal).round());
      final Float32List run = Float32List(drawn * 2);
      int written = 0;

      for (int i = 0; i < drawn; i++) {
        final ProjectedPoint? p = projectXYZ(
          arcs.x[start + i],
          arcs.y[start + i],
          arcs.z[start + i],
          params,
        );
        if (p == null) {
          // Crossed the limb. Flush what we have and start a fresh run rather
          // than joining two visible ends straight through the planet.
          _strokeRun(canvas, run, written, stroke, isSelected);
          written = 0;
          continue;
        }
        run[written] = p.dx;
        run[written + 1] = p.dy;
        written += 2;
      }
      _strokeRun(canvas, run, written, stroke, isSelected);
    }
  }

  void _strokeRun(
    Canvas canvas,
    Float32List buffer,
    int written,
    Paint stroke,
    bool isSelected,
  ) {
    if (written < 4) return;
    stroke.color = (isSelected ? palette.selected : palette.arc)
        .withValues(alpha: isSelected ? 0.95 : 0.62);
    canvas.drawRawPoints(
      ui.PointMode.polygon,
      Float32List.view(buffer.buffer, 0, written),
      stroke,
    );
  }

  void _paintMarkers(Canvas canvas, ProjectionParams params) {
    final List<JourneyCluster> visible = <JourneyCluster>[];
    final List<Offset> raw = <Offset>[];
    final List<double> depths = <double>[];

    for (final JourneyCluster cluster in clusters) {
      final ProjectedPoint? p = project(cluster.position, params);
      if (p == null) continue;
      visible.add(cluster);
      raw.add(p.offset);
      depths.add(p.depth);
    }
    if (visible.isEmpty) return;

    final List<Offset> placed = declutter(
      raw,
      minSpacing: JourneyMotion.pinMinSpacing,
    );

    final int maxCount = visible.fold<int>(
      1,
      (int a, JourneyCluster c) => math.max(a, c.count),
    );

    // Back to front, so nearer markers overlap further ones.
    final List<int> order = List<int>.generate(visible.length, (int i) => i)
      ..sort((int a, int b) => depths[a].compareTo(depths[b]));

    for (final int index in order) {
      final JourneyCluster cluster = visible[index];
      if (cluster.isMemory) {
        _paintPin(canvas, cluster, placed[index]);
      } else {
        _paintCluster(canvas, cluster, placed[index], maxCount);
      }
    }
  }

  void _paintCluster(
    Canvas canvas,
    JourneyCluster cluster,
    Offset at,
    int maxCount,
  ) {
    final double t = maxCount <= 1 ? 1.0 : cluster.count / maxCount;
    final double radius = JourneyMotion.clusterRadiusMin +
        (JourneyMotion.clusterRadiusMax - JourneyMotion.clusterRadiusMin) *
            math.sqrt(t);

    canvas.drawCircle(
      at,
      radius + 5.0,
      Paint()..color = palette.marker.withValues(alpha: 0.14),
    );
    canvas.drawCircle(at, radius, Paint()..color = palette.marker);

    final TextPainter label = _countLabel(cluster, radius);
    label.paint(canvas, at - Offset(label.width / 2, label.height / 2));

    hits.add(MarkerHit(cluster, at, radius + 10.0));
  }

  void _paintPin(Canvas canvas, JourneyCluster cluster, Offset at) {
    const double head = 7.0;
    const double height = 22.0;
    final bool isSelected = cluster.events.first.id == selectedEventId;
    final Color body = isSelected ? palette.selected : palette.pin;

    // Ground shadow, so a pin reads as standing on the surface rather than
    // floating over it.
    canvas.drawOval(
      Rect.fromCenter(center: at, width: head * 1.7, height: head * 0.7),
      Paint()
        ..color = palette.shadow.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );

    final Offset centre = at.translate(0.0, -height + head);
    final Path pin = Path()
      ..addOval(Rect.fromCircle(center: centre, radius: head))
      ..moveTo(at.dx - head * 0.55, at.dy - height + head * 1.6)
      ..lineTo(at.dx, at.dy)
      ..lineTo(at.dx + head * 0.55, at.dy - height + head * 1.6)
      ..close();

    canvas.drawPath(pin, Paint()..color = body);
    canvas.drawCircle(
      centre,
      head * 0.36,
      Paint()..color = palette.markerInk.withValues(alpha: 0.9),
    );

    if (isSelected) {
      canvas.drawCircle(
        centre,
        head + 4.0,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = body.withValues(alpha: 0.55),
      );
    }

    hits.add(MarkerHit(cluster, centre, head + 12.0));
  }

  TextPainter _countLabel(JourneyCluster cluster, double radius) {
    final String key = '${cluster.key}:${cluster.count}';
    final TextPainter? cached = textCache[key];
    if (cached != null) return cached;

    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: '${cluster.count}',
        style: TextStyle(
          color: palette.markerInk,
          fontSize: radius * 0.95,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textCache[key] = painter;
    return painter;
  }

  @override
  bool shouldRepaint(covariant GlobeOverlayPainter old) =>
      old.camera != camera ||
      old.arcReveal != arcReveal ||
      old.selectedEventId != selectedEventId ||
      !identical(old.clusters, clusters) ||
      !identical(old.arcs, arcs);
}
