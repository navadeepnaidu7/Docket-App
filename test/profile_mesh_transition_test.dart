import 'package:docket/features/dashboard/application/profile_avatar_shape_provider.dart';
import 'package:docket/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'saved circle hydration and shape changes interpolate without assertions',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'profile_avatar_shape': 'circle',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: ProfileMeshButton(
                meshSeed: 'test-avatar',
                washes: const [Colors.orange, Colors.blue],
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 220));
      expect(
        container.read(profileAvatarShapeProvider),
        ProfileAvatarShape.circle,
      );
      final decoration =
          tester
                  .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                  .decoration
              as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(ProfileMeshButton.size / 2),
      );
      await container
          .read(profileAvatarShapeProvider.notifier)
          .setShape(ProfileAvatarShape.rounded);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 220));
      expect(tester.takeException(), isNull);
    },
  );
}
