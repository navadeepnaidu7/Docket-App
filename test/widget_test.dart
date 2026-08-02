import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:docket/app.dart';

/// Pumps in bounded steps until [finder] matches.
///
/// Never use `pumpAndSettle` on these screens. The onboarding background and
/// the save celebration drive repeating animations, so the frame queue is
/// never empty and `pumpAndSettle` spins until its own ten-minute timeout —
/// which hangs the whole suite, not just the test that called it.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 100),
  int maxAttempts = 40,
}) async {
  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(step);
  }
  fail(
    'Timed out waiting for $finder after '
    '$maxAttempts pumps of ${step.inMilliseconds}ms',
  );
}

// NOTE: there is deliberately no test that mounts DashboardScreen.
// `tester.pumpWidget` never returns for it — the first frame deadlocks, so the
// test times out without running a single assertion. Reproduce with a two-line
// test that only pumps `MaterialApp(home: DashboardScreen())`. The prime
// suspect is the `SchedulerBinding.scheduleTask(_prewarmPassesTab,
// Priority.idle)` posted from its initState, which has no idle window under
// AutomatedTestWidgetsFlutterBinding. Until that is fixed the dashboard can
// only be exercised on a device.

void main() {
  testWidgets('Onboarding opens and advances past its first step', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const ProviderScope(child: DocketApp(hasSeenOnboarding: false)),
    );

    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 1500));

    // First feature step is expanded and interactive.
    final Finder firstCta = find.byKey(const ValueKey<String>('got-it-0'));
    await pumpUntilFound(tester, firstCta, maxAttempts: 25);
    await tester.tap(firstCta);

    // MultiStepForm._handleSubmit ignores taps while _isAdvancing is set, which
    // only clears 280 + 220 + stepAdvanceDuration(500) = 1000ms after a tap.
    await tester.pump(const Duration(milliseconds: 1200));

    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey<String>('got-it-1')),
      maxAttempts: 25,
    );
  });
}
