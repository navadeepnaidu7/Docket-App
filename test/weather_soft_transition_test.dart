import 'dart:ui' as ui;

import 'package:docket/features/dashboard/presentation/widgets/easter_egg_constants.dart';
import 'package:docket/features/dashboard/presentation/widgets/easter_egg_drawer.dart';
import 'package:docket/features/dashboard/presentation/widgets/weather_soft_transition.dart';
import 'package:docket/features/weather/application/weather_provider.dart';
import 'package:docket/features/weather/domain/weather_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (int x = 0; x < size.width; x += 8) {
      canvas.drawRect(
        Rect.fromLTWH(x.toDouble(), 0, 8, size.height),
        Paint()..color = (x ~/ 8).isEven ? Colors.black : Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Stripes oldDelegate) => false;
}

void main() {
  test('the default reveal is compact and still grows for accessible text', () {
    expect(weatherPanelHeight(1), 176);
    expect(weatherPanelHeight(1), lessThan(252 * 0.75));
    // The interaction test below verifies that the actual permission/loading
    // action fits. Keep this assertion about growth, not the old margin that
    // clipped that action at 2x text on narrow screens.
    expect(weatherPanelHeight(2), greaterThan(weatherPanelHeight(1)));
  });

  testWidgets('pull blur resolves smoothly and reverses with the gesture', (
    tester,
  ) async {
    const capture = ValueKey('capture');
    late StateSetter change;
    double progress = 0.3;
    bool reduced = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            return MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Center(
                child: RepaintBoundary(
                  key: capture,
                  child: SizedBox(
                    width: 120,
                    height: 72,
                    child: WeatherRevealBlur(
                      progress: progress,
                      child: CustomPaint(painter: _Stripes()),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    Future<Uint8List> pixels() async => (await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(capture),
      );
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    }))!;
    int contrast(Uint8List image) =>
        (image[(36 * 120 + 44) * 4] - image[(36 * 120 + 36) * 4]).abs();
    final hazy = await pixels();
    change(() => progress = 0.85);
    await tester.pump();
    final resolving = await pixels();
    change(() => progress = 1);
    await tester.pump();
    final clear = await pixels();
    expect(contrast(hazy), lessThan(contrast(resolving)));
    expect(contrast(resolving), lessThan(contrast(clear)));
    expect(
      tester.widget<ImageFiltered>(find.byType(ImageFiltered)).enabled,
      isFalse,
    );
    change(() => progress = 0.3);
    await tester.pump();
    expect(await pixels(), orderedEquals(hazy));
    change(() => reduced = true);
    await tester.pump();
    expect(await pixels(), orderedEquals(clear));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'opening blurs the drawer; cached refresh and updates stay soft',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final offset = ValueNotifier(kEasterEggPanelHeight);
      addTearDown(offset.dispose);
      final cached = WeatherSnapshot(
        temperatureC: 26,
        code: 2,
        isDay: true,
        time: DateTime.utc(2026, 10, 5, 9),
        fetchedAt: DateTime.utc(2026, 10, 5, 9),
        utcOffsetSeconds: 0,
      );
      var state = WeatherState(status: WeatherStatus.ready, snapshot: cached);
      late StateSetter change;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return EasterEggDrawer(
                dragOffsetNotifier: offset,
                onDragUpdate: (_) {},
                onDragEnd: (_) {},
                onDragCancel: () {},
                passports: const [],
                idDocs: const [],
                weatherState: state,
                now: DateTime(2026, 10, 5, 9),
              );
            },
          ),
        ),
      );
      await tester.pump();
      ImageFiltered revealFilter(String key) => tester.widget<ImageFiltered>(
        find
            .descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(ImageFiltered),
            )
            .first,
      );
      offset.value = kEasterEggPanelHeight * 0.85;
      await tester.pump();
      expect(revealFilter('weather_sky_blur').enabled, isTrue);
      expect(revealFilter('weather_text_blur').enabled, isTrue);
      final textOpacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byKey(const ValueKey('weather_text_blur')),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(textOpacity.opacity, inExclusiveRange(0.8, 1.0));
      offset.value = kEasterEggPanelHeight;
      await tester.pump();
      expect(revealFilter('weather_sky_blur').enabled, isFalse);
      expect(revealFilter('weather_text_blur').enabled, isFalse);
      Finder swapFilters() => find.descendant(
        of: find.byType(WeatherSoftSwap),
        matching: find.byType(ImageFiltered),
      );
      expect(tester.widget<ImageFiltered>(swapFilters()).enabled, isFalse);
      change(
        () => state = WeatherState(
          status: WeatherStatus.loading,
          snapshot: cached,
        ),
      );
      await tester.pump();
      expect(swapFilters(), findsOneWidget);
      expect(tester.widget<ImageFiltered>(swapFilters()).enabled, isFalse);
      expect(find.textContaining('26°C'), findsOneWidget);
      expect(find.text('Finding local weather…'), findsNothing);

      change(
        () => state = WeatherState(
          status: WeatherStatus.ready,
          snapshot: WeatherSnapshot(
            temperatureC: 23,
            code: 61,
            isDay: true,
            time: cached.time,
            fetchedAt: cached.fetchedAt,
            utcOffsetSeconds: 0,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(swapFilters(), findsNWidgets(2));
      expect(
        tester
            .widgetList<ImageFiltered>(swapFilters())
            .every((filter) => filter.enabled),
        isTrue,
      );
      final outgoing = find
          .ancestor(
            of: find.textContaining('26°C'),
            matching: find.byType(ExcludeSemantics),
          )
          .first;
      expect(tester.widget<ExcludeSemantics>(outgoing).excluding, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('26°C'), findsNothing);
      expect(find.textContaining('23°C'), findsOneWidget);
      expect(tester.widget<ImageFiltered>(swapFilters()).enabled, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('reduced-motion updates are immediate and never blurred', (
    tester,
  ) async {
    Widget app(String label) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: WeatherSoftSwap(child: Text(label, key: ValueKey(label))),
      ),
    );
    await tester.pumpWidget(app('26°C'));
    await tester.pumpWidget(app('23°C'));
    await tester.pump();
    expect(find.text('26°C'), findsNothing);
    expect(find.text('23°C'), findsOneWidget);
    expect(
      tester.widget<ImageFiltered>(find.byType(ImageFiltered)).enabled,
      isFalse,
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('outgoing weather actions cannot be tapped during an update', (
    tester,
  ) async {
    var oldTaps = 0;
    var newTaps = 0;
    Widget app(bool first) => MaterialApp(
      home: Center(
        child: WeatherSoftSwap(
          child: TextButton(
            key: ValueKey(first),
            onPressed: () => first ? oldTaps++ : newTaps++,
            child: Text(first ? 'Retry' : 'Settings'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(true));
    await tester.pumpWidget(app(false));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('Retry'), warnIfMissed: false);
    expect(oldTaps, 0);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Settings'));
    expect(newTaps, 1);
  });

  testWidgets('compact location and loading states keep actions visible', (
    tester,
  ) async {
    // Use the shipped proportional font: Ahem turns every letter into a square
    // and artificially adds several lines to the large-text prompts.
    await tester.runAsync(() async {
      final font = FontLoader('WeatherTestInter')
        ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'));
      await font.load();
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var taps = 0;
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        final height = weatherPanelHeight(scale);
        tester.view.physicalSize = Size(width, 844);
        final offset = ValueNotifier(height);
        for (final status in [
          WeatherStatus.idle,
          WeatherStatus.loading,
          WeatherStatus.denied,
          WeatherStatus.deniedForever,
          WeatherStatus.locationOff,
          WeatherStatus.unavailable,
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                fontFamily: 'WeatherTestInter',
                textTheme: const TextTheme(
                  labelLarge: TextStyle(
                    fontFamily: 'WeatherTestInter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.16,
                  ),
                ),
              ),
              home: MediaQuery(
                data: MediaQueryData(
                  padding: const EdgeInsets.only(top: 59),
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: EasterEggDrawer(
                  dragOffsetNotifier: offset,
                  panelHeight: height,
                  onDragUpdate: (_) {},
                  onDragEnd: (_) {},
                  onDragCancel: () {},
                  passports: const [],
                  idDocs: const [],
                  weatherState: WeatherState(status: status),
                  onWeatherAction: () => taps++,
                  now: DateTime(2026, 10, 5, 9),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.text('No documents yet'), findsNothing);
          final button = find.byType(TextButton);
          final rect = tester.getRect(button);
          expect(rect.height, greaterThanOrEqualTo(44));
          expect(rect.top, greaterThanOrEqualTo(59));
          expect(
            rect.bottom,
            lessThanOrEqualTo(height),
            reason: '$status at $width with $scale text',
          );
          final before = taps;
          await tester.tap(button);
          expect(taps, before + (status == WeatherStatus.loading ? 0 : 1));
        }
        await tester.pumpWidget(const SizedBox());
        offset.dispose();
      }
    }
  });
}
