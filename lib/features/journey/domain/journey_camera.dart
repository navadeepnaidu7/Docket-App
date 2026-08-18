import 'dart:math' as math;

import 'geo_point.dart';
import 'journey_level.dart';
import 'journey_motion.dart';

/// Where the camera is looking and from how far.
///
/// A value type so `shouldRepaint` can compare two of them for free, and so the
/// destination can live in a Riverpod provider while the interpolated in-flight
/// value lives in an `AnimationController` — putting a value that changes sixty
/// times a second into a provider would rebuild every consumer just as often.
final class GlobeCamera {
  const GlobeCamera({
    required this.targetLat,
    required this.targetLng,
    required this.distance,
  });

  /// The camera framing a whole level over a given point.
  factory GlobeCamera.forLevel(JourneyLevel level, GeoPoint target) =>
      GlobeCamera(
        targetLat: target.lat,
        targetLng: target.lng,
        distance: JourneyMotion.distanceFor(level),
      );

  /// The point on the globe facing the viewer.
  final double targetLat;
  final double targetLng;

  /// Eye distance from the globe centre, in globe radii. Always greater than 1.
  final double distance;

  GeoPoint get target => GeoPoint(targetLat, targetLng);

  Vec3 get targetVector => unitVectorFor(targetLat, targetLng);

  GlobeCamera copyWith({
    double? targetLat,
    double? targetLng,
    double? distance,
  }) =>
      GlobeCamera(
        targetLat: targetLat ?? this.targetLat,
        targetLng: targetLng ?? this.targetLng,
        distance: distance ?? this.distance,
      );

  @override
  bool operator ==(Object other) =>
      other is GlobeCamera &&
      other.targetLat == targetLat &&
      other.targetLng == targetLng &&
      other.distance == distance;

  @override
  int get hashCode => Object.hash(targetLat, targetLng, distance);

  @override
  String toString() =>
      'GlobeCamera($targetLat, $targetLng, d=$distance)';
}

/// `1 - (1-t)^5`. The house deceleration curve, mirrored here as a plain
/// function so the camera math stays free of any Flutter import and testable
/// without a binding.
double easeOutQuintT(double t) {
  final double inv = 1.0 - t;
  return 1.0 - inv * inv * inv * inv * inv;
}

/// Symmetric ease, used for altitude so the pull-back and the descent are even.
double easeInOutCubicT(double t) {
  if (t < 0.5) return 4.0 * t * t * t;
  final double f = -2.0 * t + 2.0;
  return 1.0 - (f * f * f) / 2.0;
}

/// Interpolates a camera along a flight from [a] to [b].
///
/// Three channels, each with its own curve, because one shared curve is exactly
/// what makes an interpolated camera feel cheap:
///
/// * **target** — great-circle slerp, eased with the house curve, so the
///   rotation settles early and the descent finishes calmly. Latitude and
///   longitude are never lerped as scalars: that visibly bends the path and
///   breaks outright across the antimeridian.
/// * **altitude** — an eased base plus an arc that lifts with how much ground
///   is being covered, so the camera pulls back and swoops in rather than
///   sliding along a ramp.
GlobeCamera cameraAt(GlobeCamera a, GlobeCamera b, double t) {
  if (t <= 0.0) return a;
  if (t >= 1.0) return b;

  final Vec3 from = a.targetVector;
  final Vec3 to = b.targetVector;
  final double omega = angularDistance(from, to);

  final Vec3 heading = _slerp(from, to, omega, easeOutQuintT(t));
  final GeoPoint target = geoPointFor(heading);

  final double base = _lerp(a.distance, b.distance, easeInOutCubicT(t));
  final double lift =
      omega * JourneyMotion.arcLiftPerRadian * math.sin(math.pi * t);

  return GlobeCamera(
    targetLat: target.lat,
    targetLng: target.lng,
    distance: base + lift,
  );
}

/// How long a flight from [a] to [b] should take.
///
/// Scales with ground covered between [JourneyMotion.flightMin] and
/// [JourneyMotion.flightMax], so a hop across one city and a hop across the
/// world both feel deliberate.
Duration flightDuration(GlobeCamera a, GlobeCamera b) {
  final double omega = angularDistance(a.targetVector, b.targetVector);
  final double t = (omega / math.pi).clamp(0.0, 1.0);
  final int minMs = JourneyMotion.flightMin.inMilliseconds;
  final int maxMs = JourneyMotion.flightMax.inMilliseconds;
  return Duration(milliseconds: (minMs + (maxMs - minMs) * t).round());
}

/// Spherical linear interpolation between two unit vectors.
///
/// Falls back to a normalised straight lerp when the two directions are nearly
/// identical, because `sin(omega)` goes to zero there and the slerp weights blow
/// up. Antipodal input has no unique great circle, so it also takes the fallback
/// rather than picking an arbitrary one.
Vec3 _slerp(Vec3 from, Vec3 to, double omega, double t) {
  const double epsilon = 1e-6;
  if (omega < epsilon || (math.pi - omega) < epsilon) {
    final Vec3 blended = from * (1.0 - t) + to * t;
    return blended.normalizedOrNull() ?? from;
  }
  final double sinOmega = math.sin(omega);
  final double wFrom = math.sin((1.0 - t) * omega) / sinOmega;
  final double wTo = math.sin(t * omega) / sinOmega;
  return (from * wFrom + to * wTo).normalizedOrNull() ?? from;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
