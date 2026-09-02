import 'dart:math' as math;

/// A point on Earth in degrees.
///
/// Latitude is positive north, longitude positive east — the convention every
/// source the atlas is built from already uses, so nothing is ever negated on
/// the way in.
final class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  /// True when the pair names a real position.
  ///
  /// Latitude past the poles is always a bug; longitude is normalised rather
  /// than rejected because 180 and -180 are the same meridian and feeds
  /// disagree about which one to emit.
  bool get isValid =>
      lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;

  Vec3 get unitVector => unitVectorFor(lat, lng);

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}

/// A vector in globe space, where the sphere is the unit sphere at the origin.
///
/// Deliberately hand-written rather than pulling in `vector_math`: the feature
/// needs six operations, and Flutter only exposes that package transitively.
final class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static const Vec3 zero = Vec3(0.0, 0.0, 0.0);

  double get length => math.sqrt(x * x + y * y + z * z);

  Vec3 operator +(Vec3 other) => Vec3(x + other.x, y + other.y, z + other.z);

  Vec3 operator -(Vec3 other) => Vec3(x - other.x, y - other.y, z - other.z);

  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  double dot(Vec3 other) => x * other.x + y * other.y + z * other.z;

  Vec3 cross(Vec3 other) => Vec3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  /// Scales to unit length, or returns null when there is no direction to keep.
  ///
  /// A zero vector has no meaningful normalisation, and the two callers that
  /// can produce one — the spherical centroid of antipodal points, and a
  /// degenerate slerp — both need to detect it rather than divide by zero and
  /// propagate NaN into the projection.
  Vec3? normalizedOrNull() {
    final double len = length;
    if (len < 1e-12) return null;
    return Vec3(x / len, y / len, z / len);
  }

  @override
  bool operator ==(Object other) =>
      other is Vec3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Vec3($x, $y, $z)';
}

const double _degToRad = math.pi / 180.0;
const double _radToDeg = 180.0 / math.pi;

/// Maps degrees on the sphere to a unit vector, with +Y through the north pole.
///
/// Y-up rather than the Z-up convention geodesy usually writes, because every
/// consumer here is a screen: keeping north on the vertical screen axis means
/// the projection never swaps components.
Vec3 unitVectorFor(double latDeg, double lngDeg) {
  final double lat = latDeg * _degToRad;
  final double lng = lngDeg * _degToRad;
  final double cosLat = math.cos(lat);
  return Vec3(cosLat * math.cos(lng), math.sin(lat), cosLat * math.sin(lng));
}

/// Inverse of [unitVectorFor]. Assumes [v] is already unit length.
GeoPoint geoPointFor(Vec3 v) {
  final double lat = math.asin(v.y.clamp(-1.0, 1.0)) * _radToDeg;
  final double lng = math.atan2(v.z, v.x) * _radToDeg;
  return GeoPoint(lat, lng);
}

/// Angle in radians between two directions on the sphere, in `[0, pi]`.
///
/// Clamped before `acos` because accumulated float error pushes a dot product
/// of two nearly identical unit vectors just past 1.0, and `acos(1.0000001)`
/// is NaN — which then silently poisons every distance-scaled camera duration.
double angularDistance(Vec3 a, Vec3 b) =>
    math.acos(a.dot(b).clamp(-1.0, 1.0));

/// The mean direction of [points], renormalised back onto the sphere.
///
/// Averaging latitude and longitude as scalars is wrong: it drifts toward the
/// equator away from the poles, and two cities either side of the antimeridian
/// average to a point in Africa. Averaging the vectors has neither failure.
///
/// Returns null for an empty input, and for the rare antipodal set whose mean
/// is the origin — there is genuinely no centroid to name in that case.
Vec3? sphericalCentroid(Iterable<Vec3> points) {
  double x = 0.0;
  double y = 0.0;
  double z = 0.0;
  int count = 0;
  for (final Vec3 p in points) {
    x += p.x;
    y += p.y;
    z += p.z;
    count++;
  }
  if (count == 0) return null;
  return Vec3(x / count, y / count, z / count).normalizedOrNull();
}
