// flutter test --no-pub tool/airline_logo_sheet_test.dart --update-goldens
//
// Draws every airline in the table as its pass header (surface, logo in ink,
// date beside it) into build/flight-preview/airline_logos.png, reading the
// logos from the sibling docket_server checkout. Review it after adding or
// replacing a logo: a mark that turns into a solid block when drawn in one
// colour, or sits too small in its box, shows up here.
import 'dart:io';

import 'package:docket/features/tickets/domain/airline_brands.dart';
import 'package:docket/features/tickets/presentation/flight/airline_logo.dart';
import 'package:docket/features/tickets/presentation/flight/flight_brand_style.dart';
import 'package:docket/features/tickets/presentation/flight/flight_pass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const String _logos = '../docket_server/internal/brands/airlines';

void main() {
  testWidgets('airline logo sheet', (WidgetTester tester) async {
    final Directory cache = Directory('build/flight-preview/fonts')
      ..createSync(recursive: true);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => cache.absolute.path,
    );
    final Map<String, Uint8List> bytes = <String, Uint8List>{};
    await tester.runAsync(() async {
      HttpOverrides.global = null;
      FlightPassType.name(Colors.white);
      FlightPassType.date(Colors.white);
      FlightPassType.small(Colors.white);
      await GoogleFonts.pendingFonts();
      for (final AirlineBrand b in airlineBrands) {
        final File f = File('$_logos/${b.code}.svg');
        if (f.existsSync()) bytes[b.code] = f.readAsBytesSync();
      }
    });
    AirlineLogos.debugLoader = (String code) async => bytes[code];
    addTearDown(() => AirlineLogos.debugLoader = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 2380);
    addTearDown(tester.view.reset);

    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: const Color(0xFF111314),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    for (final AirlineBrand b in airlineBrands) _Header(b),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // The logos load on first build; let them land and cross-fade in.
    await tester.pump();
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('../build/flight-preview/airline_logos.png'),
    );
  });
}

class _Header extends StatelessWidget {
  const _Header(this.brand);

  final AirlineBrand brand;

  @override
  Widget build(BuildContext context) {
    final FlightBrandStyle c = FlightBrandStyle.of(brand, active: true);
    return Container(
      width: 280,
      height: 96,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Baseline(
              baseline: 48,
              baselineType: TextBaseline.alphabetic,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Expanded(
                    child: AirlineLogo(
                      code: brand.code,
                      color: c.ink,
                      maxWidth: 150,
                      fallback: Text(
                        brand.name,
                        style: FlightPassType.name(c.ink),
                      ),
                    ),
                  ),
                  Text('Sat, 21 Nov', style: FlightPassType.date(c.ink)),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 14,
            child: Text(
              '${brand.code}  ${brand.name}',
              style: FlightPassType.small(c.muted),
            ),
          ),
        ],
      ),
    );
  }
}
