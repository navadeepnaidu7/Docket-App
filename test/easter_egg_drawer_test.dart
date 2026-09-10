import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docket/features/dashboard/presentation/widgets/easter_egg_drawer.dart';
import 'package:docket/features/dashboard/presentation/widgets/easter_egg_sheet_motion.dart';
import 'package:docket/features/dashboard/presentation/widgets/easter_egg_constants.dart';
import 'package:docket/features/dashboard/presentation/widgets/travel_weather_glance.dart';
import 'package:docket/features/passport/domain/passport_profile.dart';

void main() {
  for (final scene in ['sunlight', 'drizzle', 'sunset', 'night']) {
    testWidgets('$scene renders, animates, and respects reduced motion', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, kEasterEggPanelHeight);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        expect(await TravelWeatherGlance.warmUp(), isNotNull);
      });
      final key = GlobalKey();
      var reduced = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: RepaintBoundary(
                  key: key,
                  child: TravelWeatherGlance(
                    hour: scene == 'night'
                        ? 23
                        : scene == 'sunset'
                        ? 18
                        : 10,
                    weather: scene == 'drizzle'
                        ? SkyWeather.drizzle
                        : SkyWeather.sunlight,
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.runAsync(() async {
        await TravelWeatherGlance.warmUp();
      });
      await tester.pump();
      Future<List<int>> pixels({String? saveAs}) async {
        late List<int> result;
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage();
          result = (await image.toByteData())!.buffer.asUint8List().toList();
          if (const bool.fromEnvironment('DOCKET_SKY_PREVIEW') &&
              saveAs != null) {
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory('build/sky_preview').create(recursive: true);
            await File(
              'build/sky_preview/$saveAs.png',
            ).writeAsBytes(png!.buffer.asUint8List());
          }
          image.dispose();
        });
        return result;
      }

      final first = await pixels(saveAs: '${scene}_0');
      await tester.pump(const Duration(seconds: 2));
      final second = await pixels(saveAs: '${scene}_2');
      expect(
        second,
        isNot(equals(first)),
        reason: 'The sky must evolve, not translate a photo.',
      );
      var totalChange = 0;
      // Measure a cloud region away from the sun, excluding alpha bytes.
      for (var y = 20; y < 90; y++) {
        for (var x = 10; x < 240; x++) {
          final index = (y * 390 + x) * 4;
          for (var channel = 0; channel < 3; channel++) {
            totalChange += (first[index + channel] - second[index + channel])
                .abs();
          }
        }
      }
      expect(
        totalChange / (70 * 230 * 3),
        greaterThan(1.0),
        reason: 'Cloud movement should be perceptible within two seconds.',
      );
      update(() => reduced = true);
      await tester.pump();
      final still = await pixels();
      await tester.pump(const Duration(seconds: 2));
      expect(await pixels(), equals(still));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('scene menu previews every mode and restores Auto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final offset = ValueNotifier(kEasterEggPanelHeight);
    addTearDown(offset.dispose);
    var selected = SkyPreviewMode.automatic;
    await tester.runAsync(() async {
      await TravelWeatherGlance.warmUp();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: SizedBox(
              height: kEasterEggPanelHeight + 150,
              child: EasterEggDrawer(
                dragOffsetNotifier: offset,
                onDragUpdate: (_) {},
                onDragEnd: (_) {},
                onDragCancel: () {},
                passports: const [],
                idDocs: const [],
                now: DateTime(2026, 9, 12, 18),
                onPreviewModeChanged: (mode) => selected = mode,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final mode in [
      SkyPreviewMode.sunlight,
      SkyPreviewMode.drizzle,
      SkyPreviewMode.sunset,
      SkyPreviewMode.night,
      SkyPreviewMode.automatic,
    ]) {
      await tester.tap(find.byTooltip('Change sky scene'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(mode.label));
      await tester.pumpAndSettle();
      expect(selected, mode);
      final sky = tester.widget<TravelWeatherGlance>(
        find.byType(TravelWeatherGlance),
      );
      expect(sky.hour, switch (mode) {
        SkyPreviewMode.automatic || SkyPreviewMode.sunset => 18,
        SkyPreviewMode.night => 23,
        _ => 10,
      });
      expect(
        sky.weather,
        mode == SkyPreviewMode.automatic || mode == SkyPreviewMode.drizzle
            ? SkyWeather.drizzle
            : SkyWeather.sunlight,
      );
      // Testing a night sky should not change the real local-time greeting.
      expect(find.text('Good evening'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    offset.value = 0;
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byType(EasterEggDrawer)).toString(),
      isNot(contains('Change sky scene')),
    );
    await tester.pumpWidget(const SizedBox());
  });

  test('snap respects flick direction and gentle momentum', () {
    expect(
      EasterEggSheetMotion.shouldSnapOpen(offsetY: 30, velocityY: 500),
      isTrue,
    );
    expect(
      EasterEggSheetMotion.shouldSnapOpen(offsetY: 270, velocityY: -500),
      isFalse,
    );
    expect(
      EasterEggSheetMotion.shouldSnapOpen(offsetY: 90, velocityY: 100),
      isTrue,
    );
    expect(
      EasterEggSheetMotion.shouldSnapOpen(offsetY: 20, velocityY: 0),
      isFalse,
    );
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('sky summary fits $width at text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, kEasterEggPanelHeight + 80);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final offset = ValueNotifier(kEasterEggPanelHeight);
        addTearDown(offset.dispose);
        // Optional local render; normal CI does not depend on a system font.
        const render = bool.fromEnvironment('DOCKET_SKY_PREVIEW');
        if (render) {
          await tester.runAsync(() async {
            final font = File('C:/Windows/Fonts/segoeui.ttf');
            final loader = FontLoader('Preview');
            loader.addFont(
              Future.value(ByteData.sublistView(await font.readAsBytes())),
            );
            await loader.load();
          });
        }
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: render ? 'Preview' : null),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, kEasterEggPanelHeight + 80),
                padding: const EdgeInsets.only(top: 59),
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: RepaintBoundary(
                key: key,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: EasterEggDrawer(
                        dragOffsetNotifier: offset,
                        onDragUpdate: (_) {},
                        onDragEnd: (_) {},
                        onDragCancel: () {},
                        passports: [
                          PassportProfile.fromMap({
                            'id': 'preview',
                            'name': 'Alex Morgan',
                            'passportNumber': '',
                            'nationality': '',
                            'dateOfBirth': '',
                            'expiryDate': '',
                          }),
                        ],
                        idDocs: const [],
                        now: DateTime(2026, 9, 10, 9),
                      ),
                    ),
                    Positioned(
                      top: kEasterEggPanelHeight,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFDDD8CE),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          expect(await TravelWeatherGlance.warmUp(), isNotNull);
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Good morning'), findsOneWidget);
        expect(
          find.textContaining('1 document', findRichText: true),
          findsOneWidget,
        );
        if (render && scale == 1) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/sky_preview').create(recursive: true);
            await File(
              'build/sky_preview/sky_$width.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
