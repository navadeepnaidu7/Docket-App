import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:docket/features/journey/data/journey_atlas.dart';
import 'package:docket/features/journey/domain/geo_point.dart';
import 'package:flutter_test/flutter_test.dart';

/// Decoder tests for the packed globe atlas.
///
/// A binary reader that is quietly off by one produces a planet that is wrong
/// but entirely plausible, so these assert against the generator's own debug
/// sidecar and against known geography rather than against the decoder itself.
void main() {
  final Uint8List bytes =
      File('assets/journey/atlas_v1.bin').readAsBytesSync();
  final Map<String, dynamic> debug = json.decode(
    File('assets/journey/atlas_v1.debug.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final JourneyAtlas atlas = decodeJourneyAtlas(bytes);

  /// Nearest land dot to a place, as an angular distance in degrees.
  double nearestLandDegrees(double lat, double lng) {
    final Vec3 probe = unitVectorFor(lat, lng);
    double best = math.pi;
    for (int i = 0; i < atlas.dotCount; i++) {
      final double angle = angularDistance(
        probe,
        Vec3(atlas.dotX[i], atlas.dotY[i], atlas.dotZ[i]),
      );
      if (angle < best) best = angle;
    }
    return best * 180.0 / math.pi;
  }

  group('decoding', () {
    test('matches the generator sidecar exactly', () {
      expect(atlas.dotCount, debug['dotCount']);
      expect(atlas.ringCount, debug['ringCount']);
      expect(
        atlas.bandOffsets.toList(),
        (debug['bandOffsets'] as List<dynamic>).cast<int>(),
      );
      expect(
        atlas.ringLengths.fold<int>(0, (int a, int b) => a + b),
        debug['ringVertexTotal'],
      );
    });

    test('every position is a unit vector', () {
      // A quantisation or scaling mistake shows up here before it shows up as
      // a globe that is subtly the wrong shape.
      for (int i = 0; i < atlas.dotCount; i += 37) {
        final double length = math.sqrt(
          atlas.dotX[i] * atlas.dotX[i] +
              atlas.dotY[i] * atlas.dotY[i] +
              atlas.dotZ[i] * atlas.dotZ[i],
        );
        expect(length, closeTo(1.0, 1e-5), reason: 'dot $i is off the sphere');
      }
    });

    test('bands are contiguous prefixes ending at the full field', () {
      expect(atlas.bandOffsets.length, greaterThan(1));
      for (int i = 1; i < atlas.bandOffsets.length; i++) {
        expect(atlas.bandOffsets[i], greaterThan(atlas.bandOffsets[i - 1]));
      }
      expect(atlas.bandOffsets.last, atlas.dotCount);
      expect(atlas.dotsForBand(0), lessThan(atlas.dotCount));
    });

    test('ring starts and lengths stay inside the vertex arrays', () {
      for (int i = 0; i < atlas.ringCount; i++) {
        expect(atlas.ringStarts[i] + atlas.ringLengths[i],
            lessThanOrEqualTo(atlas.ringX.length));
      }
    });

    test('a corrupted byte fails the checksum rather than decoding', () {
      final Uint8List tampered = Uint8List.fromList(bytes);
      // Somewhere in the dot payload, well past the header.
      tampered[tampered.length ~/ 2] ^= 0xFF;
      expect(() => decodeJourneyAtlas(tampered), throwsFormatException);
    });

    test('a truncated file fails rather than decoding a partial planet', () {
      expect(
        () => decodeJourneyAtlas(bytes.sublist(0, bytes.length ~/ 2)),
        throwsFormatException,
      );
    });

    test('a bad magic number is rejected', () {
      final Uint8List tampered = Uint8List.fromList(bytes);
      tampered[0] ^= 0xFF;
      expect(() => decodeJourneyAtlas(tampered), throwsFormatException);
    });
  });

  group('geography probes', () {
    // The decoder can be self-consistent and still be drawing the wrong planet.
    // These check it against the actual Earth.
    test('land coverage is close to the real figure', () {
      expect(debug['landFraction'] as double, closeTo(0.29, 0.03));
    });

    test('major landmasses carry dots', () {
      expect(nearestLandDegrees(20.59, 78.96), lessThan(2.0), reason: 'India');
      expect(nearestLandDegrees(-14.24, -51.93), lessThan(2.0), reason: 'Brazil');
      expect(nearestLandDegrees(9.08, 8.68), lessThan(2.0), reason: 'Nigeria');
      expect(nearestLandDegrees(-25.27, 133.78), lessThan(2.0), reason: 'Australia');
      expect(nearestLandDegrees(61.52, 105.32), lessThan(2.0), reason: 'Siberia');
      expect(nearestLandDegrees(-82.0, 0.0), lessThan(4.0), reason: 'Antarctica');
    });

    test('open ocean carries none', () {
      // The mid-Pacific and the mid-Atlantic are the two places a wrongly
      // wound polygon or an inverted mask shows up immediately.
      expect(nearestLandDegrees(-30.0, -140.0), greaterThan(8.0),
          reason: 'South Pacific');
      expect(nearestLandDegrees(30.0, -40.0), greaterThan(5.0),
          reason: 'North Atlantic');
    });

    test('inland water is not treated as land', () {
      // Holes in the land polygons have to be subtracted, or the Caspian fills
      // in and the mask silently gains a continent.
      expect(nearestLandDegrees(41.8, 50.7), greaterThan(0.8),
          reason: 'Caspian Sea');
    });

    test('state boundary rings sit inside India', () {
      for (int i = 0; i < atlas.ringCount; i++) {
        final int start = atlas.ringStarts[i];
        for (int v = start; v < start + atlas.ringLengths[i]; v++) {
          final GeoPoint point = geoPointFor(
            Vec3(atlas.ringX[v], atlas.ringY[v], atlas.ringZ[v]),
          );
          expect(point.lat, inInclusiveRange(6.0, 37.5));
          expect(point.lng, inInclusiveRange(68.0, 97.5));
        }
      }
    });
  });

  group('wireframe fallback', () {
    test('is empty but safe to draw', () {
      expect(JourneyAtlas.wireframe.isEmpty, isTrue);
      expect(JourneyAtlas.wireframe.dotsForBand(2), 0);
      expect(JourneyAtlas.wireframe.ringCount, 0);
    });
  });
}
