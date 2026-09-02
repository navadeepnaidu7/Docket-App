import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'geo_point.dart';
import 'journey_camera.dart';
import 'journey_motion.dart';

/// A projected point in screen space, plus the depth it came from.
final class ProjectedPoint {
  const ProjectedPoint(this.dx, this.dy, this.depth);

  final double dx;
  final double dy;

  /// Position along the view axis: 1.0 at the point facing the camera, falling
  /// to the horizon value as it approaches the limb. Drives dot size and alpha.
  final double depth;

  Offset get offset => Offset(dx, dy);
}

/// Everything a frame needs to project points, computed once per frame.
///
/// Deliberately flat scalars rather than a matrix: projecting a point is then
/// nine multiplies and no allocation, which is what lets tens of thousands of
/// land dots go through the same path every frame.
final class ProjectionParams {
  const ProjectionParams._({
    required this.rightX,
    required this.rightY,
    required this.rightZ,
    required this.upX,
    required this.upY,
    required this.upZ,
    required this.fwdX,
    required this.fwdY,
    required this.fwdZ,
    required this.centerX,
    required this.centerY,
    required this.radiusPx,
    required this.distance,
    required this.cullZ,
  });

  /// Builds the frame's projection from a camera and the canvas size.
  factory ProjectionParams.forCamera(GlobeCamera camera, Size size) {
    final Vec3 fwd = camera.targetVector;

    // Camera basis. The view direction crossed with world up gives screen
    // right, and right crossed back with the view direction gives screen up.
    // The order matters: the opposite convention mirrors the globe east-west,
    // which looks entirely plausible until you notice Chennai is west of
    // Mumbai. At the poles the cross product vanishes, so fall back to a fixed
    // right vector rather than emitting NaN across the whole frame.
    const Vec3 worldUp = Vec3(0.0, 1.0, 0.0);
    final Vec3 right =
        fwd.cross(worldUp).normalizedOrNull() ?? const Vec3(0.0, 0.0, 1.0);
    final Vec3 up = right.cross(fwd);

    final double distance = math.max(camera.distance, 1.0001);
    final double shorterAxis = math.min(size.width, size.height);
    final double discRadius = shorterAxis * 0.5 * JourneyMotion.discFill;

    // Hold the visible disc at a constant on-screen size across levels. The
    // sphere does not grow as you descend — the visible cap shrinks inside a
    // disc that stays put, which is what reads as moving closer rather than as
    // the planet inflating.
    final double radiusPx =
        discRadius * math.sqrt(distance * distance - 1.0) / distance;

    return ProjectionParams._(
      rightX: right.x,
      rightY: right.y,
      rightZ: right.z,
      upX: up.x,
      upY: up.y,
      upZ: up.z,
      fwdX: fwd.x,
      fwdY: fwd.y,
      fwdZ: fwd.z,
      centerX: size.width * 0.5,
      centerY: size.height * 0.5,
      radiusPx: radiusPx,
      distance: distance,
      cullZ: horizonZ(distance),
    );
  }

  final double rightX;
  final double rightY;
  final double rightZ;
  final double upX;
  final double upY;
  final double upZ;
  final double fwdX;
  final double fwdY;
  final double fwdZ;
  final double centerX;
  final double centerY;

  /// Globe radius in logical pixels before perspective scaling.
  final double radiusPx;

  final double distance;

  /// Depth below which a point is over the horizon and must not be drawn.
  final double cullZ;
}

/// Depth of the horizon for an eye [distance] globe-radii from the centre.
///
/// Exactly `1 / distance` — the classic tangent-point result for a unit sphere.
/// Deriving it rather than using a fixed fudge is what keeps the horizon correct
/// as the camera descends, which is precisely where culling starts to matter:
/// at city distance the visible cap is a small fraction of the sphere.
double horizonZ(double distance) => 1.0 / distance;

/// Projects one point. Returns null when the point is over the horizon.
///
/// The readable reference implementation. [projectBatch] is the one the painters
/// actually call, and a test asserts the two agree — that guard is the whole
/// defence against the classic bug where the fast path quietly drifts.
ProjectedPoint? project(Vec3 p, ProjectionParams params) =>
    projectXYZ(p.x, p.y, p.z, params);

/// [project] taking loose components.
///
/// Lets a caller walking a packed `Float32List` — boundary rings, arc samples —
/// project a vertex without building a [Vec3] for each one.
ProjectedPoint? projectXYZ(
  double x,
  double y,
  double z,
  ProjectionParams params,
) {
  final double depth = x * params.fwdX + y * params.fwdY + z * params.fwdZ;
  if (depth <= params.cullZ) return null;

  final double xc = x * params.rightX + y * params.rightY + z * params.rightZ;
  final double yc = x * params.upX + y * params.upY + z * params.upZ;

  final double scale = params.distance / (params.distance - depth);
  return ProjectedPoint(
    params.centerX + xc * params.radiusPx * scale,
    // Screen y grows downward while the camera's up axis grows upward.
    params.centerY - yc * params.radiusPx * scale,
    depth,
  );
}

/// Projects a run of unit vectors into a preallocated buffer.
///
/// Reads `[from, to)` of the three component arrays and appends surviving
/// points to [out] as consecutive x, y pairs, returning how many were written.
/// Allocates nothing, so it can carry the whole land field every frame.
///
/// [out] must have room for `(to - from) * 2` doubles. [depths] is optional and
/// receives the matching depth per surviving point when supplied.
int projectBatch(
  Float32List xs,
  Float32List ys,
  Float32List zs,
  int from,
  int to,
  ProjectionParams params,
  Float32List out, {
  Float32List? depths,
}) {
  int written = 0;
  int cursor = 0;
  for (int i = from; i < to; i++) {
    final double x = xs[i];
    final double y = ys[i];
    final double z = zs[i];

    final double depth =
        x * params.fwdX + y * params.fwdY + z * params.fwdZ;
    if (depth <= params.cullZ) continue;

    final double xc =
        x * params.rightX + y * params.rightY + z * params.rightZ;
    final double yc = x * params.upX + y * params.upY + z * params.upZ;

    final double scale = params.distance / (params.distance - depth);
    out[cursor++] = params.centerX + xc * params.radiusPx * scale;
    out[cursor++] = params.centerY - yc * params.radiusPx * scale;
    if (depths != null) depths[written] = depth;
    written++;
  }
  return written;
}

/// Samples a great-circle arc between two points as unit vectors.
///
/// Sphere-space and camera-independent, so it is computed once per route and
/// only projected per frame. Each sample is lifted off the surface in proportion
/// to how far the arc travels, which is what makes it read as a journey rather
/// than a line drawn on a ball, and lets it stay visible across the limb.
List<Vec3> sampleArc(Vec3 from, Vec3 to, {int? samples, double liftScale = 0.06}) {
  final double omega = angularDistance(from, to);
  final int count = samples ?? (omega * 40.0).round().clamp(8, 64);
  final double sinOmega = math.sin(omega);

  final List<Vec3> out = <Vec3>[];
  for (int i = 0; i < count; i++) {
    final double u = count == 1 ? 0.0 : i / (count - 1);

    final Vec3 onSphere;
    if (sinOmega.abs() < 1e-6) {
      onSphere = from;
    } else {
      final double wFrom = math.sin((1.0 - u) * omega) / sinOmega;
      final double wTo = math.sin(u * omega) / sinOmega;
      onSphere = (from * wFrom + to * wTo).normalizedOrNull() ?? from;
    }

    final double lift = 1.0 + liftScale * omega * math.sin(math.pi * u);
    out.add(onSphere * lift);
  }
  return out;
}
