import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:docket/app.dart';

void main() {
  testWidgets('App boots through onboarding into the dashboard shell', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: DocketApp(hasSeenOnboarding: false)));

    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 1500));

    for (int i = 0; i < 4; i++) {
      for (int attempt = 0; attempt < 25; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byKey(ValueKey<String>('got-it-$i')).evaluate().isNotEmpty) break;
      }
      await tester.tap(find.byKey(ValueKey<String>('got-it-$i')));
      await tester.pump(const Duration(milliseconds: 900));
    }

    // New onboarding step: Skip authorization
    final Finder skipFinder = find.text('Skip, I will login later');
    expect(skipFinder, findsOneWidget);
    await tester.ensureVisible(skipFinder);
    await tester.tap(skipFinder);
    await tester.pump(const Duration(milliseconds: 900));

    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('Enter Docket'), findsOneWidget);
    await tester.tap(find.text('Enter Docket'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('No Documents Yet'), findsOneWidget);
    expect(find.text('IDs'), findsOneWidget);
    expect(find.text('Passes'), findsOneWidget);
  });
}