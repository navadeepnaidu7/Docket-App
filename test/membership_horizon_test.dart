import 'dart:ui' as ui;

import 'package:docket/features/dashboard/presentation/widgets/membership_horizon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const surface = ValueKey('horizon-surface');

  Widget scene({bool reduceMotion = false}) => MaterialApp(
    theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: RepaintBoundary(
          key: surface,
          child: const SizedBox(
            width: 390,
            height: 220,
            child: MembershipHorizon(),
          ),
        ),
      ),
    ),
  );

  Future<int> blueLight(WidgetTester tester) async {
    return (await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(surface),
      );
      final image = await boundary.toImage();
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      var light = 0;
      for (var i = 0; i < pixels.lengthInBytes; i += 4) {
        light += pixels.getUint8(i + 2);
      }
      image.dispose();
      return light;
    }))!;
  }

  testWidgets('Light blooms on entry and resets when the screen reopens', (
    tester,
  ) async {
    await tester.pumpWidget(scene());
    final initial = await blueLight(tester);
    await tester.pump(const Duration(milliseconds: 450));
    final opening = await blueLight(tester);
    await tester.pump(const Duration(milliseconds: 1000));
    final settled = await blueLight(tester);
    expect(opening, greaterThan(initial));
    expect(settled, greaterThan(opening));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(scene());
    expect(await blueLight(tester), initial);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced motion shows the settled light without a ticker', (
    tester,
  ) async {
    await tester.pumpWidget(scene(reduceMotion: true));
    final initial = await blueLight(tester);
    expect(initial, greaterThan(0));
    await tester.pump(const Duration(seconds: 2));
    expect(await blueLight(tester), initial);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
