import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docket/features/dashboard/presentation/widgets/easter_egg_drawer.dart';
import 'package:docket/features/dashboard/presentation/widgets/easter_egg_sheet_motion.dart';
import 'package:docket/features/passport/domain/passport_profile.dart';

void main() {
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
        tester.view.physicalSize = Size(width, 442);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final offset = ValueNotifier(292.0);
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
                size: Size(width, 442),
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
                      top: 292,
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
                        child: const Center(
                          child: Text('Docket', style: TextStyle(fontSize: 24)),
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
          await precacheImage(
            const AssetImage('assets/weather/docket_sky.png'),
            tester.element(find.byType(EasterEggDrawer)),
          );
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Good morning, Alex.'), findsOneWidget);
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
