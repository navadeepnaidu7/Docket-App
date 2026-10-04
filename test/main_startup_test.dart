import 'package:docket/features/dashboard/presentation/dashboard_screen.dart';
import 'package:docket/features/onboarding/presentation/onboarding_screen.dart';
import 'package:docket/main.dart' as entry;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final preference in <Object?>[true, false, null, 'invalid']) {
    testWidgets('main opens the correct route for onboarding=$preference', (
      tester,
    ) async {
      final values = <String, Object>{};
      if (preference != null) values['has_seen_onboarding'] = preference;
      SharedPreferences.setMockInitialValues(values);
      await tester.runAsync(entry.main);
      await tester.pump();
      expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
      expect(
        find.byType(preference == true ? DashboardScreen : OnboardingScreen),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
