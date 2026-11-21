import 'dart:io';

import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/core/motion/studio_page_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  test(
    'Android opts out of predictive back in the manifest and both themes',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:enableOnBackInvokedCallback="false"'));
      expect(
        manifest,
        isNot(contains('android:enableOnBackInvokedCallback="true"')),
      );
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        expect(
          theme.pageTransitionsTheme.builders[TargetPlatform.android],
          isA<FadeForwardsPageTransitionsBuilder>(),
        );
        expect(
          theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
          isA<CupertinoPageTransitionsBuilder>(),
        );
      }
    },
  );

  testWidgets('normal platform back still pops the detail route', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: AppTheme.lightTheme.copyWith(platform: TargetPlatform.android),
        home: const Scaffold(body: Text('Wallet')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Details')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Details'), findsNothing);
  });

  for (final studio in [false, true]) {
    testWidgets(
      '${studio ? 'studio' : 'ordinary'} screens move sideways on push and back',
      (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        const target = Key('transition-target');
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            theme: AppTheme.lightTheme.copyWith(
              platform: TargetPlatform.android,
            ),
            home: const Scaffold(body: Text('Wallet')),
          ),
        );
        Widget destination(BuildContext context) => const Scaffold(
          body: SizedBox.expand(key: target, child: Text('Details')),
        );
        navigator.currentState!.push(
          studio
              ? studioPageRoute<void>(builder: destination)
              : MaterialPageRoute<void>(builder: destination),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final entering = tester.getTopLeft(find.byKey(target));
        await tester.pumpAndSettle();
        final settled = tester.getTopLeft(find.byKey(target));
        expect(entering.dx, greaterThan(settled.dx));
        expect(entering.dy, closeTo(settled.dy, .01));
        navigator.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final leaving = tester.getTopLeft(find.byKey(target));
        expect(leaving.dx, greaterThan(settled.dx));
        expect(leaving.dy, closeTo(settled.dy, .01));
        await tester.pumpAndSettle();
        expect(find.text('Wallet'), findsOneWidget);
      },
    );
  }

  testWidgets('a push can be reversed before its transition completes', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: AppTheme.lightTheme.copyWith(platform: TargetPlatform.android),
        home: const Scaffold(body: Text('Wallet')),
      ),
    );
    navigator.currentState!.push(
      studioPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Details')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Details'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
