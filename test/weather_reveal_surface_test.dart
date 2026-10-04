import 'package:docket/features/dashboard/presentation/widgets/weather_reveal_surface.dart';
import 'package:docket/features/dashboard/presentation/widgets/easter_egg_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wallet and navigation translate together without relayout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final offset = ValueNotifier(0.0);
    addTearDown(offset.dispose);
    var builds = 0;
    const headerKey = ValueKey('header');
    const navKey = ValueKey('nav');
    const walletKey = ValueKey('wallet');
    await tester.pumpWidget(
      MaterialApp(
        home: WeatherRevealSurface(
          offset: offset,
          panelHeight: kEasterEggPanelHeight,
          drawer: const ColoredBox(color: Colors.blue),
          child: Builder(
            builder: (context) {
              builds++;
              return Stack(
                key: walletKey,
                children: [
                  const Positioned(
                    top: 70,
                    left: 20,
                    child: SizedBox(key: headerKey, width: 200, height: 44),
                  ),
                  const Positioned(
                    bottom: 20,
                    left: 20,
                    child: SizedBox(key: navKey, width: 280, height: 82),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    final headerStart = tester.getTopLeft(find.byKey(headerKey));
    final navStart = tester.getTopLeft(find.byKey(navKey));
    final size = tester.getSize(find.byKey(walletKey));
    for (final distance in [
      24.0,
      80.0,
      kEasterEggPanelHeight,
      kEasterEggPanelHeight + 32,
      80.0,
      0.0,
    ]) {
      offset.value = distance;
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(headerKey)),
        headerStart + Offset(0, distance),
      );
      expect(
        tester.getTopLeft(find.byKey(navKey)),
        navStart + Offset(0, distance),
      );
      expect(tester.getSize(find.byKey(walletKey)), size);
      expect(
        TickerMode.valuesOf(tester.element(find.byKey(headerKey))).enabled,
        isTrue,
        reason:
            'The revealed wallet must keep scroll and button feedback active.',
      );
    }
    expect(
      builds,
      1,
      reason: 'The wallet must not rebuild for every drag frame.',
    );
    expect(tester.takeException(), isNull);
  });
}
