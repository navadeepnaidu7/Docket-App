import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docket/core/dev/dev_flags.dart';
import 'package:docket/features/dashboard/presentation/widgets/membership_mesh.dart';
import 'package:docket/features/ids/domain/id_document.dart';
import 'package:docket/features/passport/domain/passport_profile.dart';

void main() {
  group('meshSeedHash / personalizeWashes', () {
    test('same seed is stable', () {
      expect(meshSeedHash('alex@example.com'), meshSeedHash('alex@example.com'));
      expect(meshPhaseForSeed('alex'), meshPhaseForSeed('alex'));
    });

    test('different seeds personalize washes differently', () {
      final List<Color> base = walletWashColors(
        passports: const <PassportProfile>[],
        idDocs: const <IdDocument>[],
        scheme: CardFluidScheme.auto,
      );
      final List<Color> a = personalizeWashes(base, 'user-a@docket.app');
      final List<Color> b = personalizeWashes(base, 'user-b@docket.app');
      expect(a, isNot(equals(b)));
    });
  });

  group('avatarMeshColors', () {
    test('returns multiple distinct hues for the squircle', () {
      final List<Color> colors = avatarMeshColors(seed: 'alex@docket.app');
      expect(colors.length, greaterThanOrEqualTo(4));
      // Not a flat monochrome — at least two hues should differ by >20°.
      final List<double> hues = colors
          .map((Color c) => HSLColor.fromColor(c).hue)
          .toList();
      double maxSpread = 0;
      for (int i = 0; i < hues.length; i++) {
        for (int j = i + 1; j < hues.length; j++) {
          final double d = (hues[i] - hues[j]).abs();
          final double spread = d > 180 ? 360 - d : d;
          if (spread > maxSpread) maxSpread = spread;
        }
      }
      expect(maxSpread, greaterThan(40));
    });

    test('different seeds yield different palettes', () {
      final List<Color> a = avatarMeshColors(seed: 'user-a');
      final List<Color> b = avatarMeshColors(seed: 'user-b');
      expect(a, isNot(equals(b)));
    });
  });
}
