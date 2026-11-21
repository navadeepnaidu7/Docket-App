// flutter test --no-pub tool/flight_pass_preview_test.dart --update-goldens
// Review images live in build/flight-preview rather than committed goldens.
import 'dart:io';

import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/core/wallet/wallet_card_metrics.dart';
import 'package:docket/features/tickets/data/mock_flight_fixtures.dart';
import 'package:docket/features/tickets/domain/flight_pass_models.dart';
import 'package:docket/features/tickets/domain/pass_status.dart';
import 'package:docket/features/tickets/presentation/flight/airline_logo.dart';
import 'package:docket/features/tickets/presentation/flight/flight_pass_detail_screen.dart';
import 'package:docket/features/tickets/presentation/flight/flight_pass_theme.dart';
import 'package:docket/features/tickets/presentation/flight/flight_ticket_face.dart';
import 'package:docket/features/tickets/presentation/flight/flight_updates_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  Future<void> fonts(WidgetTester tester) async {
    final Directory cache = Directory('build/flight-preview/fonts')
      ..createSync(recursive: true);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => cache.absolute.path,
    );
    await tester.runAsync(() async {
      HttpOverrides.global = null;
      const Color c = Colors.white;
      FlightPassType.code(c);
      FlightPassType.time(c);
      FlightPassType.name(c);
      FlightPassType.small(c);
      FlightPassType.stub(c);
      FlightPassType.lead(c);
      AppTheme.lightTheme;
      AppTheme.darkTheme;
      await GoogleFonts.pendingFonts();
      // Icons render as boxes in tests unless the SDK's icon font is loaded.
      // flutter_tester lives in bin/cache/artifacts/engine/<platform>/.
      Directory dir = File(Platform.resolvedExecutable).parent;
      File icons = File('');
      for (int i = 0; i < 5; i++) {
        icons = File('${dir.path}/material_fonts/materialicons-regular.otf');
        if (icons.existsSync()) break;
        dir = dir.parent;
      }
      if (icons.existsSync()) {
        final FontLoader loader = FontLoader('MaterialIcons')
          ..addFont(
            Future<ByteData>.value(
              ByteData.sublistView(icons.readAsBytesSync()),
            ),
          );
        await loader.load();
      }
    });
  }

  testWidgets('flight faces', (WidgetTester tester) async {
    await fonts(tester);
    // Logos from the sibling server checkout: tests have no network.
    final Map<String, Uint8List> logos = <String, Uint8List>{};
    await tester.runAsync(() async {
      for (final String code in <String>['6E', 'AI', 'QP', 'LH', 'EK', 'VY']) {
        logos[code] = File(
          '../docket_server/internal/brands/airlines/$code.svg',
        ).readAsBytesSync();
      }
    });
    AirlineLogos.debugLoader = (String code) async => logos[code];
    addTearDown(() => AirlineLogos.debugLoader = null);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final FlightPass spent = FlightPass.fromJson(<String, dynamic>{
      ...mockFlightPasses[1].toJson(),
      'status': TicketStatus.expired.toJson(),
    });
    final List<(String, FlightPass)> shots = <(String, FlightPass)>[
      ('indigo_delayed', mockFlightPasses[0]),
      ('airindia_timetable', mockFlightPasses[1]),
      ('akasa_in_air', mockFlightPasses[2]),
      ('expired', spent),
      for (final (String code, String airline, String from, String to)
          in <(String, String, String, String)>[
            ('LH', 'Lufthansa', 'FRA', 'BLR'),
            ('EK', 'Emirates', 'DXB', 'BOM'),
            ('VY', 'Vueling', 'BCN', 'FCO'),
            ('ZZ', 'Example Air', 'DEL', 'BOM'),
          ])
        (
          code == 'ZZ' ? 'universal' : code.toLowerCase(),
          FlightPass.fromJson(<String, dynamic>{
            ...mockFlightPasses[1].toJson(),
            'airline': airline,
            'airlineCode': code,
            'flightNumber': '$code 761',
            'origin': <String, dynamic>{'code': from},
            'destination': <String, dynamic>{'code': to},
          }),
        ),
    ];
    for (final (String name, FlightPass pass) in shots) {
      tester.view.physicalSize = const Size(382 + 48, 620);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF121718),
            body: Center(
              child: SizedBox(
                width: 382,
                height: 382 / WalletCardMetrics.trainAspect,
                child: WalletCardCanvas(
                  designSize: FlightPassMetrics.canvas,
                  child: FlightTicketFace(pass: pass),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../build/flight-preview/face_$name.png'),
      );
    }
  });

  testWidgets('updates tab', (WidgetTester tester) async {
    await fonts(tester);
    // Photos from disk: tests have no network and no cache-manager plugin.
    final Map<String, MemoryImage> photos = <String, MemoryImage>{};
    await tester.runAsync(() async {
      for (final String name in <String>['indigo', 'akasa']) {
        photos[name] = MemoryImage(
          File('build/flight-preview/photos/$name.jpg').readAsBytesSync(),
        );
      }
    });
    FlightAircraftCard.debugPhotoBuilder = (String url) => Image(
      image: photos[url.contains('Akasa') ? 'akasa' : 'indigo']!,
      fit: BoxFit.cover,
    );
    addTearDown(() => FlightAircraftCard.debugPhotoBuilder = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 2700);
    addTearDown(tester.view.reset);

    for (final (String name, ThemeData theme, int index)
        in <(String, ThemeData, int)>[
          ('light_delayed', AppTheme.lightTheme, 0),
          ('dark_delayed', AppTheme.darkTheme, 0),
          ('dark_in_air', AppTheme.darkTheme, 2),
          ('light_in_air', AppTheme.lightTheme, 2),
          ('light_timetable', AppTheme.lightTheme, 1),
          ('light_details', AppTheme.lightTheme, -1),
        ]) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: FlightPassDetailScreen(
              key: ValueKey<String>(name),
              pass: mockFlightPasses[index < 0 ? 0 : index],
            ),
          ),
        ),
      );
      await tester.pump();
      if (index >= 0) {
        await tester.tap(find.text('Updates'));
      }
      // The map's pulse repeats, so settle by time rather than by idleness.
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.runAsync(() async {
        for (final Element e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../build/flight-preview/screen_$name.png'),
      );
    }
  });
}
