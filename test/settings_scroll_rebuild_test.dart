import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:docket/features/dashboard/presentation/settings_screen.dart';

/// Settings pauses its two continuous effects — the membership card's wash and
/// the "Tap to open" shimmer — while the list is moving. That pause used to be
/// `setState` on the screen, so starting and settling a scroll rebuilt all
/// fifteen list children, the Developer block and two dozen GoogleFonts
/// lookups among them, at the two moments the list could least afford it.
///
/// The pause now travels on a ValueNotifier that only those two widgets watch.
/// Nothing else in the tree should see a scroll at all, so the section titles
/// must survive a drag as the very same widget instances.
void main() {
  testWidgets('scrolling Settings does not rebuild the sections', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(520, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    final Widget appearanceBefore = tester.widget(find.text('Appearance'));
    final Widget navigationBefore = tester.widget(find.text('Navigation'));

    await tester.drag(find.byType(ListView), const Offset(0, -160));
    await tester.pump();

    expect(
      identical(tester.widget(find.text('Appearance')), appearanceBefore),
      isTrue,
      reason: 'A scroll rebuilt the Appearance section.',
    );
    expect(
      identical(tester.widget(find.text('Navigation')), navigationBefore),
      isTrue,
      reason: 'A scroll rebuilt the Navigation section.',
    );
  });
}
