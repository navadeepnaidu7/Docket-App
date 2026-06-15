// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:slickport/app.dart';

void main() {
  testWidgets('App boots through onboarding into the dashboard shell', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: SlickPortApp(hasSeenOnboarding: false)));

    expect(find.text('SlickPort'), findsWidgets);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter SlickPort'));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('MAYA JOHNSON'), findsWidgets);
    expect(find.text('Docs'), findsOneWidget);
    expect(find.text('Tickets'), findsOneWidget);
  });
}
