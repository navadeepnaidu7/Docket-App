import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:docket/features/journey/domain/geo_point.dart';
import 'package:docket/features/journey/domain/globe_projection.dart';
import 'package:docket/features/journey/domain/journey_camera.dart';
import 'package:docket/features/journey/domain/journey_level.dart';
import 'package:docket/features/journey/domain/journey_motion.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _canvas = Size(390.0, 844.0);

GlobeCamera _camera({
  double lat = 20.0,
  double lng = 78.0,
  double distance = 3.2,
}) =>
    GlobeCamera(targetLat: lat, targetLng: lng, distance: distance);

void main() {
  group('horizon', () {
    test('is exactly the reciprocal of the eye distance', () {
      // The tangent-point result for a unit sphere. Derived rather than fudged,
      // so it stays correct as the camera descends.
      expect(horizonZ(3.2), closeTo(1.0 / 3.2, 1e-12));
      expect(horizonZ(1.28), closeTo(1.0 / 1.28, 1e-12));
    });

    test('the visible cap shrinks as the camera descends', () {
      expect(
        horizonZ(JourneyMotion.distanceFor(JourneyLevel.city)),
        greaterThan(horizonZ(JourneyMotion.distanceFor(JourneyLevel.world))),
      );
    });
  });

  group('projection', () {
    test('the camera target lands at the centre of the canvas', () {
      final GlobeCamera camera = _camera();
      final ProjectionParams params =
          ProjectionParams.forCamera(camera, _canvas);
      final ProjectedPoint? p = project(camera.targetVector, params);

      expect(p, isNotNull);
      expect(p!.dx, closeTo(_canvas.width / 2, 1e-9));
      expect(p.dy, closeTo(_canvas.height / 2, 1e-9));
      expect(p.depth, closeTo(1.0, 1e-12));
    });

    test('the far side of the globe is culled', () {
      final GlobeCamera camera = _camera();
      final ProjectionParams params =
          ProjectionParams.forCamera(camera, _canvas);
      expect(project(camera.targetVector * -1.0, params), isNull);
    });

    test('a point just past the horizon is culled, just inside is not', () {
      final GlobeCamera camera = _camera(lat: 0.0, lng: 0.0, distance: 2.0);
      final ProjectionParams params =
          ProjectionParams.forCamera(camera, _canvas);

      // Horizon sits at depth 0.5 for distance 2. Depth here is cos(lng).
      final double horizonLng = math.acos(0.5) * 180.0 / math.pi;
      expect(project(unitVectorFor(0.0, horizonLng - 0.5), params), isNotNull);
      expect(project(unitVectorFor(0.0, horizonLng + 0.5), params), isNull);
    });

    test('north of the target projects above it on screen', () {
      // Screen y grows downward while the camera up axis grows upward; getting
      // this backwards flips the globe and nothing else would catch it.
      final GlobeCamera camera = _camera(lat: 0.0, lng: 0.0);
      final ProjectionParams params =
          ProjectionParams.forCamera(camera, _canvas);

      final ProjectedPoint north = project(unitVectorFor(20.0, 0.0), params)!;
      expect(north.dy, lessThan(_canvas.height / 2));
    });

    test('east of the target projects to the right of it', () {
      final GlobeCamera camera = _camera(lat: 0.0, lng: 0.0);
      final ProjectionParams params =
          ProjectionParams.forCamera(camera, _canvas);

      final ProjectedPoint east = project(unitVectorFor(0.0, 20.0), params)!;
      expect(east.dx, greaterThan(_canvas.width / 2));
    });

    test('a target at the pole still produces a finite basis', () {
      // World up crossed with the view direction vanishes at the poles, and an
      // un-guarded normalise emits NaN that silently poisons the whole frame.
      final ProjectionParams params = ProjectionParams.forCamera(
        _camera(lat: 90.0, lng: 0.0),
        _canvas,
      );
      final ProjectedPoint? p = project(unitVectorFor(89.0, 30.0), params);

      expect(p, isNotNull);
      expect(p!.dx.isFinite, isTrue);
      expect(p.dy.isFinite, isTrue);
    });

    test('the visible disc stays the same size at every level', () {
      // The composition is meant to hold while the cap shrinks inside it.
      double discRadius(JourneyLevel level) {
        final ProjectionParams p = ProjectionParams.forCamera(
          _camera(distance: JourneyMotion.distanceFor(level)),
          _canvas,
        );
        // Projected radius of the horizon circle.
        return p.radiusPx * p.distance / math.sqrt(p.distance * p.distance - 1.0);
      }

      final double expected = _canvas.width * 0.5 * JourneyMotion.discFill;
      for (final JourneyLevel level in JourneyLevel.values) {
        expect(discRadius(level), closeTo(expected, 1e-6),
            reason: 'disc moved at ${level.name}');
      }
    });
  });

  group('batch projection', () {
    test('agrees with the reference implementation', () {
      // The fast path allocates nothing and is what every frame actually runs.
      // If it drifts from the readable version, the globe is subtly wrong in a
      // way no visual check would catch.
      final math.Random random = math.Random(20260818);
      const int count = 4000;

      final Float32List xs = Float32List(count);
      final Float32List ys = Float32List(count);
      final Float32List zs = Float32List(count);
      final List<Vec3> points = <Vec3>[];

      for (int i = 0; i < count; i++) {
        final double lat = random.nextDouble() * 180.0 - 90.0;
        final double lng = random.nextDouble() * 360.0 - 180.0;
        final Vec3 v = unitVectorFor(lat, lng);
        points.add(v);
        xs[i] = v.x;
        ys[i] = v.y;
        zs[i] = v.z;
      }

      final ProjectionParams params =
          ProjectionParams.forCamera(_camera(), _canvas);
      final Float32List out = Float32List(count * 2);
      final Float32List depths = Float32List(count);
      final int written =
          projectBatch(xs, ys, zs, 0, count, params, out, depths: depths);

      final List<ProjectedPoint> reference = <ProjectedPoint>[];
      for (final Vec3 p in points) {
        final ProjectedPoint? projected = project(p, params);
        if (projected != null) reference.add(projected);
      }

      expect(written, reference.length);
      expect(written, greaterThan(0));
      for (int i = 0; i < written; i++) {
        // Float32 storage of the inputs costs a little precision versus the
        // double reference, so the tolerance is on screen pixels, not epsilon.
        expect(out[i * 2], closeTo(reference[i].dx, 1e-2));
        expect(out[i * 2 + 1], closeTo(reference[i].dy, 1e-2));
        expect(depths[i], closeTo(reference[i].depth, 1e-6));
      }
    });

    test('culls the far hemisphere', () {
      final math.Random random = math.Random(7);
      const int count = 2000;
      final Float32List xs = Float32List(count);
      final Float32List ys = Float32List(count);
      final Float32List zs = Float32List(count);
      for (int i = 0; i < count; i++) {
        final Vec3 v = unitVectorFor(
          random.nextDouble() * 180.0 - 90.0,
          random.nextDouble() * 360.0 - 180.0,
        );
        xs[i] = v.x;
        ys[i] = v.y;
        zs[i] = v.z;
      }

      final ProjectionParams params =
          ProjectionParams.forCamera(_camera(), _canvas);
      final int written = projectBatch(
        xs, ys, zs, 0, count, params, Float32List(count * 2));

      // Under half the sphere is ever visible, and less than half at altitude.
      expect(written, lessThan(count ~/ 2));
    });
  });

  group('camera flight', () {
    final GlobeCamera bengaluru = GlobeCamera(
      targetLat: 12.9716,
      targetLng: 77.5946,
      distance: JourneyMotion.distanceFor(JourneyLevel.city),
    );
    final GlobeCamera hyderabad = GlobeCamera(
      targetLat: 17.3850,
      targetLng: 78.4867,
      distance: JourneyMotion.distanceFor(JourneyLevel.city),
    );
    final GlobeCamera world = GlobeCamera(
      targetLat: 20.0,
      targetLng: 78.0,
      distance: JourneyMotion.distanceFor(JourneyLevel.world),
    );
    final GlobeCamera peru = GlobeCamera(
      targetLat: -12.0,
      targetLng: -77.0,
      distance: JourneyMotion.distanceFor(JourneyLevel.city),
    );

    test('endpoints are exact', () {
      expect(cameraAt(bengaluru, world, 0.0), bengaluru);
      expect(cameraAt(bengaluru, world, 1.0), world);
    });

    test('the target stays on the sphere for the whole flight', () {
      for (double t = 0.0; t <= 1.0; t += 0.05) {
        final GlobeCamera c = cameraAt(bengaluru, peru, t);
        expect(c.targetVector.length, closeTo(1.0, 1e-9),
            reason: 'left the sphere at t=$t');
        expect(c.targetLat.isFinite && c.targetLng.isFinite, isTrue);
      }
    });

    test('a long flight pulls back further than either end', () {
      final double mid = cameraAt(bengaluru, peru, 0.5).distance;
      expect(mid, greaterThan(bengaluru.distance));
      expect(mid, greaterThan(peru.distance));
    });

    test('a short hop barely lifts', () {
      // Two cities in neighbouring states should not launch the camera into
      // orbit — that is the difference between premium and seasick.
      final double mid = cameraAt(bengaluru, hyderabad, 0.5).distance;
      expect(mid - bengaluru.distance, lessThan(0.05));
    });

    test('crossing the antimeridian does not sweep the long way round', () {
      // Lerping longitude as a scalar would run 358 degrees the wrong way.
      const GlobeCamera east = GlobeCamera(
        targetLat: 0.0,
        targetLng: 179.0,
        distance: 2.0,
      );
      const GlobeCamera west = GlobeCamera(
        targetLat: 0.0,
        targetLng: -179.0,
        distance: 2.0,
      );

      // The eased midpoint is deliberately not the geometric midpoint — the
      // house curve front-loads the rotation — so assert the property that
      // actually matters: the path never wanders away from the two degrees of
      // arc separating the endpoints.
      final double omega =
          angularDistance(east.targetVector, west.targetVector);
      for (double t = 0.0; t <= 1.0; t += 0.05) {
        final GlobeCamera c = cameraAt(east, west, t);
        expect(
          angularDistance(east.targetVector, c.targetVector),
          lessThanOrEqualTo(omega + 1e-9),
          reason: 'went the long way round at t=$t',
        );
        expect(c.targetLng.abs(), greaterThan(178.9));
        expect(c.targetLat, closeTo(0.0, 1e-6));
      }
    });

    test('a flight between identical cameras is stable', () {
      final GlobeCamera mid = cameraAt(bengaluru, bengaluru, 0.5);
      expect(mid.targetLat, closeTo(bengaluru.targetLat, 1e-9));
      expect(mid.targetLng, closeTo(bengaluru.targetLng, 1e-9));
      expect(mid.distance.isFinite, isTrue);
    });

    test('the first flight starts from where the camera actually was', () {
      // Regression. The navigator has already stored the destination by the
      // time its listener fires, so an origin read back out of it equals the
      // destination and the flight silently becomes a no-op -- the level still
      // changes, the globe still redraws, the tests still pass, and the camera
      // just snaps. Nothing visual would catch it.
      expect(
        flightOriginFor(rendered: null, previous: world, next: bengaluru),
        world,
      );
    });

    test('a later flight starts from what was last rendered', () {
      expect(
        flightOriginFor(
          rendered: hyderabad,
          previous: world,
          next: bengaluru,
        ),
        hyderabad,
        reason: 'the rendered camera outranks the listener previous',
      );
    });

    test('no flight is started when there is nowhere to go', () {
      expect(
        flightOriginFor(rendered: world, previous: null, next: world),
        isNull,
      );
      expect(
        flightOriginFor(rendered: null, previous: null, next: world),
        isNull,
      );
    });

    test('duration scales with ground covered', () {
      final Duration near = flightDuration(bengaluru, hyderabad);
      final Duration far = flightDuration(bengaluru, peru);

      expect(near, greaterThanOrEqualTo(JourneyMotion.flightMin));
      expect(far, lessThanOrEqualTo(JourneyMotion.flightMax));
      expect(far, greaterThan(near));
    });
  });

  group('arc sampling', () {
    test('starts and ends on the surface and bulges between', () {
      final Vec3 from = unitVectorFor(12.97, 77.59);
      final Vec3 to = unitVectorFor(28.61, 77.20);
      final List<Vec3> arc = sampleArc(from, to);

      expect(arc.length, greaterThanOrEqualTo(8));
      expect(arc.first.length, closeTo(1.0, 1e-9));
      expect(arc.last.length, closeTo(1.0, 1e-9));
      expect(arc[arc.length ~/ 2].length, greaterThan(1.0),
          reason: 'the arc should lift off the surface');
    });

    test('a longer route lifts higher', () {
      double peak(Vec3 a, Vec3 b) {
        final List<Vec3> arc = sampleArc(a, b);
        return arc[arc.length ~/ 2].length;
      }

      final double shortHop =
          peak(unitVectorFor(12.97, 77.59), unitVectorFor(13.08, 80.27));
      final double longHaul =
          peak(unitVectorFor(12.97, 77.59), unitVectorFor(-12.0, -77.0));

      expect(longHaul, greaterThan(shortHop));
    });

    test('coincident endpoints do not produce NaN', () {
      final Vec3 v = unitVectorFor(12.97, 77.59);
      final List<Vec3> arc = sampleArc(v, v);
      for (final Vec3 p in arc) {
        expect(p.length.isFinite, isTrue);
      }
    });
  });
}
