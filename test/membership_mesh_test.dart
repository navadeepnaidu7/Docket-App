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
}
