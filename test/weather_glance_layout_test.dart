import 'dart:io';
import 'dart:ui' as ui;

import 'package:docket/features/dashboard/presentation/widgets/easter_egg_constants.dart';
import 'package:docket/features/dashboard/presentation/widgets/easter_egg_drawer.dart';
import 'package:docket/features/dashboard/presentation/widgets/travel_weather_glance.dart';
import 'package:docket/features/dashboard/presentation/widgets/weather_reveal_surface.dart';
import 'package:docket/features/weather/application/weather_provider.dart';
import 'package:docket/features/weather/domain/weather_glance_event.dart';
import 'package:docket/features/weather/domain/weather_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final scene in ['refresh', 'movie', 'train']) {
        testWidgets(
          '$scene fits $width at $scale text with a tall status bar',
          (tester) async {
            final height = weatherPanelHeight(scale);
            tester.view.physicalSize = Size(width, height + 80);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.runAsync(() async {
              final fonts = FontLoader('WeatherLayout')
                ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
                ..addFont(rootBundle.load('assets/fonts/Inter-Medium.ttf'));
              await fonts.load();
              await TravelWeatherGlance.warmUp();
            });
            final offset = ValueNotifier(height);
            final capture = GlobalKey();
            final event = scene == 'refresh'
                ? null
                : WeatherGlanceEvent(
                    id: scene,
                    title: scene == 'movie'
                        ? 'Movie in 4 hours'
                        : 'Train in 2 days',
                    detail: scene == 'movie'
                        ? 'An evening at the movies'
                        : 'Your next journey is getting closer',
                    kind: scene == 'movie' ? 'Movie' : 'Train',
                  );
            var shownEvent = event;
            late StateSetter changeScene;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(fontFamily: 'WeatherLayout'),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, height + 80),
                    padding: const EdgeInsets.only(top: 59),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      fontFamily: 'WeatherLayout',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    child: RepaintBoundary(
                      key: capture,
                      child: WeatherRevealSurface(
                        offset: offset,
                        panelHeight: height,
                        drawer: StatefulBuilder(
                          builder: (context, setState) {
                            changeScene = setState;
                            return EasterEggDrawer(
                              dragOffsetNotifier: offset,
                              panelHeight: height,
                              onDragUpdate: (_) {},
                              onDragEnd: (_) {},
                              onDragCancel: () {},
                              passports: const [],
                              idDocs: const [],
                              now: DateTime(2026, 10, 15, 10),
                              refreshing: scene == 'refresh',
                              event: shownEvent,
                              weatherState: WeatherState(
                                status: WeatherStatus.ready,
                                snapshot: WeatherSnapshot(
                                  temperatureC: 24,
                                  code: 2,
                                  isDay: true,
                                  time: DateTime.utc(2026, 10, 15, 10),
                                  fetchedAt: DateTime.utc(2026, 10, 15, 10),
                                  utcOffsetSeconds: 0,
                                ),
                              ),
                            );
                          },
                        ),
                        child: const ColoredBox(color: Color(0xFFDDD8CE)),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 800));
            final label = scene == 'refresh' ? 'Good morning' : event!.title;
            expect(find.text('Updating weather…'), findsNothing);
            expect(find.text('Finding local weather…'), findsNothing);
            final rect = tester.getRect(find.text(label));
            expect(rect.top, greaterThanOrEqualTo(59));
            expect(rect.bottom, lessThan(height));
            if (event != null) {
              expect(
                tester.getRect(find.text(event.detail)).bottom,
                lessThan(height),
              );
            }
            expect(tester.takeException(), isNull);
            if (const bool.fromEnvironment('DOCKET_WEATHER_FLOW_PREVIEW')) {
              Future<void> save(String name) async {
                await tester.runAsync(() async {
                  final boundary =
                      capture.currentContext!.findRenderObject()
                          as RenderRepaintBoundary;
                  final image = await boundary.toImage(pixelRatio: 2);
                  final png = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await Directory(
                    'build/weather_flow_preview',
                  ).create(recursive: true);
                  await File(
                    'build/weather_flow_preview/$name.png',
                  ).writeAsBytes(png!.buffer.asUint8List());
                  image.dispose();
                });
              }

              await save('${scene}_${width}_$scale');
              if (scene == 'movie' && width == 390 && scale == 1) {
                changeScene(() => shownEvent = null);
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 800));
                await save('focus_weather');
                changeScene(() => shownEvent = event);
                await tester.pump();
                var previous = 0;
                for (final elapsed in [0, 140, 220, 360, 520, 800]) {
                  await tester.pump(Duration(milliseconds: elapsed - previous));
                  previous = elapsed;
                  await save('focus_$elapsed');
                }
              }
            }
            await tester.pumpWidget(const SizedBox());
            offset.dispose();
          },
        );
      }
    }
  }
}
