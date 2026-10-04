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
import 'package:docket/features/dashboard/presentation/widgets/weather_reveal_surface.dart';
import 'package:docket/features/passport/domain/passport_profile.dart';
import 'package:docket/features/weather/application/weather_provider.dart';
import 'package:docket/features/weather/domain/weather_snapshot.dart';

void main() {
  testWidgets(
    'lightning is occasional, localized, and disabled with reduced motion',
    (tester) async {
      await tester.runAsync(() async {
        final program = (await TravelWeatherGlance.warmUp())!;
        final shader = program.fragmentShader();
        Future<ui.Image> frame(double time, bool motion) async {
          final values = [
            390.0,
            kEasterEggPanelHeight,
            time,
            0.0,
            0.0,
            0.82,
            1.0,
            kEasterEggPanelHeight,
            1.0,
            1.0,
            motion ? 1.0 : 0.0,
          ];
          for (var i = 0; i < values.length; i++) {
            shader.setFloat(i, values[i]);
          }
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawRect(
            const Rect.fromLTWH(0, 0, 390, kEasterEggPanelHeight),
            Paint()..shader = shader,
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(
            390,
            kEasterEggPanelHeight.ceil(),
          );
          picture.dispose();
          return image;
        }

        var maximumLitPixels = 0;
        for (var step = 0; step <= 30; step++) {
          final time = step * 0.2;
          final animated = await frame(time, true);
          final reduced = await frame(time, false);
          final a = (await animated.toByteData())!.buffer.asUint8List();
          final b = (await reduced.toByteData())!.buffer.asUint8List();
          var lit = 0;
          for (var pixel = 0; pixel < a.length; pixel += 4) {
            if (a[pixel + 2] - b[pixel + 2] > 10) lit++;
          }
          if (step < 15) {
            expect(lit, 0, reason: 'The storm should have quiet intervals.');
          }
          if (lit > maximumLitPixels) {
            maximumLitPixels = lit;
            if (const bool.fromEnvironment('DOCKET_SKY_PREVIEW')) {
              final png = await animated.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory('build/sky_preview').create(recursive: true);
              await File(
                'build/sky_preview/lightning.png',
              ).writeAsBytes(png!.buffer.asUint8List());
            }
          }
          animated.dispose();
          reduced.dispose();
        }
        expect(maximumLitPixels, greaterThan(100));
        expect(maximumLitPixels, lessThan(390 * kEasterEggPanelHeight * 0.65));
        shader.dispose();
      });
    },
  );

  testWidgets('weather transitions can be redirected without a visual jump', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, kEasterEggPanelHeight);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await TravelWeatherGlance.warmUp();
    });
    var weather = SkyWeather.sunlight;
    late StateSetter change;
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            return RepaintBoundary(
              key: key,
              child: TravelWeatherGlance(hour: 10, weather: weather),
            );
          },
        ),
      ),
    );
    await tester.runAsync(() async {
      await TravelWeatherGlance.warmUp();
    });
    await tester.pump();
    Future<List<int>> pixels() async {
      late List<int> result;
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage();
        result = (await image.toByteData())!.buffer.asUint8List().toList();
        image.dispose();
      });
      return result;
    }

    await tester.pump(const Duration(seconds: 2));
    final before = await pixels();
    change(() => weather = SkyWeather.heavyRain);
    await tester.pump();
    expect(await pixels(), equals(before));
    await tester.pump(const Duration(milliseconds: 400));
    final midway = await pixels();
    expect(midway, isNot(equals(before)));
    change(() => weather = SkyWeather.clear);
    await tester.pump();
    expect(await pixels(), equals(midway));
    await tester.pump(const Duration(milliseconds: 800));
    expect(await pixels(), isNot(equals(midway)));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final scene in [
    'sunlight',
    'clear',
    'partlyCloudy',
    'mostlyCloudy',
    'cloudy',
    'fog',
    'snow',
    'drizzle',
    'rain',
    'heavyRain',
    'thunderstorm',
    'sunset',
    'night',
  ]) {
    testWidgets('$scene renders, animates, and respects reduced motion', (
      tester,
    ) async {
      // Keep illustration motion sampling independent of drawer geometry.
      const referenceSkyHeight = 252.0;
      tester.view.physicalSize = const Size(390, referenceSkyHeight);
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
                    panelHeight: referenceSkyHeight,
                    hour: scene == 'night'
                        ? 23
                        : scene == 'sunset'
                        ? 18
                        : 10,
                    weather:
                        SkyWeather.values
                            .where((value) => value.name == scene)
                            .firstOrNull ??
                        SkyWeather.sunlight,
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
      if (scene != 'clear') {
        expect(
          totalChange / (70 * 230 * 3),
          // Soft night wisps are deliberately quieter than daylight clouds.
          greaterThan(scene == 'night' ? 0.15 : 1.0),
          reason: 'Cloud movement should be perceptible within two seconds.',
        );
      }
      update(() => reduced = true);
      await tester.pump();
      final still = await pixels();
      await tester.pump(const Duration(seconds: 2));
      expect(await pixels(), equals(still));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'weather previews are controlled externally and no scene menu is exposed',
    (tester) async {
      final offset = ValueNotifier(kEasterEggPanelHeight);
      addTearDown(offset.dispose);
      for (final mode in SkyPreviewMode.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
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
                  weather: SkyWeather.drizzle,
                  initialPreviewMode: mode,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PopupMenuButton<SkyPreviewMode>), findsNothing);
        expect(find.byTooltip('Change sky scene'), findsNothing);
        expect(find.text('Good evening'), findsOneWidget);
        final sky = tester.widget<TravelWeatherGlance>(
          find.byType(TravelWeatherGlance),
        );
        expect(sky.weather, switch (mode) {
          SkyPreviewMode.automatic ||
          SkyPreviewMode.drizzle => SkyWeather.drizzle,
          SkyPreviewMode.clear => SkyWeather.clear,
          SkyPreviewMode.night => SkyWeather.clear,
          SkyPreviewMode.partlyCloudy => SkyWeather.partlyCloudy,
          SkyPreviewMode.mostlyCloudy => SkyWeather.mostlyCloudy,
          SkyPreviewMode.rain => SkyWeather.rain,
          SkyPreviewMode.cloudy => SkyWeather.cloudy,
          SkyPreviewMode.fog => SkyWeather.fog,
          SkyPreviewMode.snow => SkyWeather.snow,
          SkyPreviewMode.heavyRain => SkyWeather.heavyRain,
          SkyPreviewMode.thunderstorm => SkyWeather.thunderstorm,
          _ => SkyWeather.sunlight,
        });
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('snap requires intentional travel and preserves an open glance', () {
    expect(
      EasterEggSheetMotion.shouldSnapOpen(offsetY: 30, velocityY: 500),
      isFalse,
    );
    expect(
      EasterEggSheetMotion.shouldSnapOpen(offsetY: 270, velocityY: -700),
      isFalse,
    );
    expect(
      EasterEggSheetMotion.shouldSnapOpen(offsetY: 150, velocityY: 100),
      isTrue,
    );
    for (final velocity in [0.0, 500.0, 2400.0]) {
      expect(
        EasterEggSheetMotion.shouldSnapOpen(offsetY: 24, velocityY: velocity),
        isFalse,
        reason: 'A tiny tug cannot launch the drawer, even at high velocity.',
      );
    }
    expect(
      EasterEggSheetMotion.shouldSnapOpen(offsetY: 90, velocityY: 750),
      isTrue,
    );
    expect(
      EasterEggSheetMotion.shouldSnapOpen(
        offsetY: 130,
        velocityY: 0,
        wasOpen: true,
      ),
      isTrue,
    );
    expect(
      EasterEggSheetMotion.shouldSnapOpen(
        offsetY: kEasterEggPanelHeight * 0.35,
        velocityY: 0,
        wasOpen: true,
      ),
      isFalse,
    );
    expect(
      EasterEggSheetMotion.shouldSnapOpen(offsetY: 20, velocityY: 0),
      isFalse,
    );
  });

  test(
    'release inherits visible velocity at resistant and closed boundaries',
    () {
      expect(
        EasterEggSheetMotion.releaseVelocity(rawOffset: 80, velocityY: 600),
        600,
      );
      expect(
        EasterEggSheetMotion.releaseVelocity(rawOffset: 0, velocityY: -600),
        0,
      );
      final overpull = EasterEggSheetMotion.releaseVelocity(
        rawOffset: kEasterEggPanelHeight * 1.20,
        velocityY: 600,
      );
      expect(overpull, inInclusiveRange(190, 220));
      expect(
        EasterEggSheetMotion.releaseVelocity(
          rawOffset: kEasterEggPanelHeight * 1.20,
          velocityY: -600,
        ),
        -overpull,
      );
    },
  );

  test('overpull has no speed discontinuity and can be grabbed in place', () {
    const height = kEasterEggPanelHeight;
    const epsilon = height * 0.00004;
    final justBeyond = EasterEggSheetMotion.rubberBandOffset(height + epsilon);
    expect((justBeyond - height) / epsilon, closeTo(1, 0.001));
    expect(
      EasterEggSheetMotion.releaseVelocity(
        rawOffset: height + epsilon,
        velocityY: 600,
      ),
      closeTo(600, 0.2),
    );
    for (final raw in [0.0, 24.0, height, height + 50, height + 300]) {
      final visible = EasterEggSheetMotion.rubberBandOffset(raw);
      expect(
        EasterEggSheetMotion.rawOffsetForVisible(visible),
        closeTo(raw, 0.00001),
      );
    }
    expect(
      EasterEggSheetMotion.rubberBandOffset(10000),
      lessThan(height * 1.28),
    );
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('sky summary fits $width at text scale $scale', (
        tester,
      ) async {
        final panelHeight = weatherPanelHeight(scale);
        tester.view.physicalSize = Size(width, panelHeight + 80);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final offset = ValueNotifier(panelHeight);
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
                size: Size(width, panelHeight + 80),
                padding: const EdgeInsets.only(top: 59),
                textScaler: TextScaler.linear(scale),
                disableAnimations: !render,
              ),
              child: RepaintBoundary(
                key: key,
                child: WeatherRevealSurface(
                  offset: offset,
                  panelHeight: panelHeight,
                  drawer: EasterEggDrawer(
                    dragOffsetNotifier: offset,
                    panelHeight: panelHeight,
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
                    weatherState: WeatherState(
                      status: WeatherStatus.ready,
                      stale: scale == 2,
                      snapshot: WeatherSnapshot(
                        temperatureC: 26,
                        code: 95,
                        isDay: true,
                        time: DateTime.utc(2026, 9, 10, 9),
                        fetchedAt: DateTime.now().toUtc(),
                        utcOffsetSeconds: 0,
                      ),
                    ),
                  ),
                  child: const ColoredBox(color: Color(0xFFDDD8CE)),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          expect(await TravelWeatherGlance.warmUp(), isNotNull);
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);
        expect(find.text('Good morning'), findsOneWidget);
        expect(find.textContaining('26°C'), findsOneWidget);
        expect(find.text('Near you'), findsNothing);
        expect(find.text('Open-Meteo'), findsNothing);
        expect(
          find.text('Updated earlier'),
          scale == 2 ? findsOneWidget : findsNothing,
        );
        if (render) {
          for (final fraction in [1.0, 0.55, 0.85]) {
            offset.value = panelHeight * fraction;
            await tester.pump();
            await tester.runAsync(() async {
              final boundary =
                  key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory('build/sky_preview').create(recursive: true);
              await File(
                'build/sky_preview/compact_${width}_${scale}_pull_${(fraction * 100).round()}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
