import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/journey_atlas.dart';
import '../../domain/globe_projection.dart';
import '../../domain/journey_camera.dart';
import '../../domain/journey_motion.dart';

/// Colours the globe surface draws with, resolved from the theme once.
final class GlobeSurfacePalette {
  const GlobeSurfacePalette({
    required this.space,
    required this.sphereNear,
    required this.sphereFar,
    required this.land,
    required this.rim,
    required this.border,
  });

  factory GlobeSurfacePalette.of(ThemeData theme) {
    final bool isDark = theme.brightness == Brightness.dark;
    return GlobeSurfacePalette(
      space: isDark ? const Color(0xFF07070A) : const Color(0xFFF0EAE0),
      sphereNear: isDark ? const Color(0xFF16161C) : const Color(0xFFFFFFFF),
      sphereFar: isDark ? const Color(0xFF0B0B10) : const Color(0xFFE4DED2),
      land: isDark ? const Color(0xFFE8E8ED) : const Color(0xFF1A3A6B),
      rim: isDark ? const Color(0xFFE8B84B) : const Color(0xFF1A3A6B),
      border: isDark ? const Color(0xFF6F6F7A) : const Color(0xFF8A93A6),
    );
  }

  final Color space;
  final Color sphereNear;
  final Color sphereFar;
  final Color land;
  final Color rim;
  final Color border;
}

/// Reusable per-frame scratch space for the surface painter.
///
/// Owned by the widget's `State`, not by the painter, and written into during
/// `paint`. That looks alarming and is the standard shape for this pattern: the
/// alternative is allocating hundreds of kilobytes of `Float32List` sixty times
/// a second, which is exactly what a globe cannot afford.
final class GlobeSurfaceBuffers {
  Float32List _xy = Float32List(0);
  Float32List _depths = Float32List(0);
  List<Float32List> _buckets = const <Float32List>[];
  Float32List _ring = Float32List(0);

  void ensureDots(int count) {
    if (_depths.length >= count && _buckets.length == JourneyMotion.depthBuckets) {
      return;
    }
    _xy = Float32List(count * 2);
    _depths = Float32List(count);
    _buckets = List<Float32List>.generate(
      JourneyMotion.depthBuckets,
      (_) => Float32List(count * 2),
      growable: false,
    );
  }

  void ensureRing(int vertices) {
    if (_ring.length >= vertices * 2) return;
    _ring = Float32List(vertices * 2);
  }
}

/// Draws the sphere, its land-dot field and, once descended, state outlines.
///
/// The whole planet costs [JourneyMotion.depthBuckets] draw calls. Points are
/// projected into a flat buffer and binned by depth, then each bin goes through
/// one `drawRawPoints` with its own `Paint` — so dot size and opacity still ramp
/// with distance without a per-dot `Paint` or a per-dot `drawCircle`.
class GlobeSurfacePainter extends CustomPainter {
  GlobeSurfacePainter({
    required this.atlas,
    required this.camera,
    required this.detailBand,
    required this.borderOpacity,
    required this.palette,
    required this.buffers,
  });

  final JourneyAtlas atlas;
  final GlobeCamera camera;
  final int detailBand;
  final double borderOpacity;
  final GlobeSurfacePalette palette;
  final GlobeSurfaceBuffers buffers;

  @override
  void paint(Canvas canvas, Size size) {
    final ProjectionParams params = ProjectionParams.forCamera(camera, size);
    final Offset centre = Offset(params.centerX, params.centerY);
    final double disc = params.radiusPx *
        params.distance /
        math.sqrt(params.distance * params.distance - 1.0);

    _paintSphere(canvas, centre, disc);
    _paintLand(canvas, params);
    if (borderOpacity > 0.01) _paintBorders(canvas, params);
    _paintRim(canvas, centre, disc);
  }

  void _paintSphere(Canvas canvas, Offset centre, double disc) {
    // A single radial gradient stands in for a lighting model. The offset focal
    // point is what stops the sphere reading as a flat circle.
    final Rect bounds = Rect.fromCircle(center: centre, radius: disc);
    final Paint body = Paint()
      ..shader = ui.Gradient.radial(
        centre.translate(-disc * 0.28, -disc * 0.34),
        disc * 1.32,
        <Color>[palette.sphereNear, palette.sphereFar],
        <double>[0.0, 1.0],
      );
    canvas.drawCircle(centre, disc, body);

    // Inner shading toward the limb, so the edge falls away rather than
    // stopping dead against the background.
    final Paint falloff = Paint()
      ..shader = ui.Gradient.radial(
        centre,
        disc,
        <Color>[
          palette.space.withValues(alpha: 0.0),
          palette.space.withValues(alpha: 0.55),
        ],
        <double>[0.72, 1.0],
      );
    canvas.drawRect(bounds, falloff);
  }

  void _paintLand(Canvas canvas, ProjectionParams params) {
    final int count = atlas.dotsForBand(detailBand);
    if (count == 0) return;

    buffers.ensureDots(count);
    final int visible = projectBatch(
      atlas.dotX,
      atlas.dotY,
      atlas.dotZ,
      0,
      count,
      params,
      buffers._xy,
      depths: buffers._depths,
    );
    if (visible == 0) return;

    const int bucketCount = JourneyMotion.depthBuckets;
    final List<int> filled = List<int>.filled(bucketCount, 0);
    final double span = math.max(1.0 - params.cullZ, 1e-6);

    for (int i = 0; i < visible; i++) {
      final double t = ((buffers._depths[i] - params.cullZ) / span).clamp(0.0, 1.0);
      int bucket = (t * bucketCount).floor();
      if (bucket >= bucketCount) bucket = bucketCount - 1;
      final Float32List target = buffers._buckets[bucket];
      final int at = filled[bucket];
      target[at] = buffers._xy[i * 2];
      target[at + 1] = buffers._xy[i * 2 + 1];
      filled[bucket] = at + 2;
    }

    for (int bucket = 0; bucket < bucketCount; bucket++) {
      final int written = filled[bucket];
      if (written == 0) continue;
      final double t = bucketCount == 1 ? 1.0 : bucket / (bucketCount - 1);
      final Paint paint = Paint()
        ..color = palette.land.withValues(
          alpha: _lerp(JourneyMotion.dotAlphaFar, JourneyMotion.dotAlphaNear, t),
        )
        ..strokeWidth =
            _lerp(JourneyMotion.dotRadiusFar, JourneyMotion.dotRadiusNear, t)
        ..strokeCap = StrokeCap.round;
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.view(buffers._buckets[bucket].buffer, 0, written),
        paint,
      );
    }
  }

  void _paintBorders(Canvas canvas, ProjectionParams params) {
    if (atlas.ringCount == 0) return;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeJoin = StrokeJoin.round
      ..color = palette.border.withValues(alpha: 0.55 * borderOpacity);

    for (int ring = 0; ring < atlas.ringCount; ring++) {
      final int start = atlas.ringStarts[ring];
      final int length = atlas.ringLengths[ring];
      buffers.ensureRing(length);

      // Split into runs of consecutive front-facing vertices, so a ring that
      // crosses the horizon does not draw a chord straight across the globe.
      int run = 0;
      for (int v = start; v < start + length; v++) {
        final ProjectedPoint? p = projectXYZ(
          atlas.ringX[v],
          atlas.ringY[v],
          atlas.ringZ[v],
          params,
        );
        if (p == null) {
          run = _flushRun(canvas, buffers._ring, run, paint);
          continue;
        }
        buffers._ring[run] = p.dx;
        buffers._ring[run + 1] = p.dy;
        run += 2;
      }
      _flushRun(canvas, buffers._ring, run, paint);
    }
  }

  int _flushRun(Canvas canvas, Float32List buffer, int written, Paint paint) {
    if (written >= 4) {
      canvas.drawRawPoints(
        ui.PointMode.polygon,
        Float32List.view(buffer.buffer, 0, written),
        paint,
      );
    }
    return 0;
  }

  void _paintRim(Canvas canvas, Offset centre, double disc) {
    canvas.drawCircle(
      centre,
      disc,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = palette.rim.withValues(alpha: 0.22),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant GlobeSurfacePainter old) =>
      old.camera != camera ||
      old.detailBand != detailBand ||
      old.borderOpacity != borderOpacity ||
      !identical(old.atlas, atlas) ||
      old.palette.land != palette.land;
}
