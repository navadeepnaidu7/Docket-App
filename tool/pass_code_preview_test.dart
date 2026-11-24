// flutter test --no-pub tool/pass_code_preview_test.dart --update-goldens
// Opt-in visual checks; screenshots stay under build/pass-code-preview.
import 'dart:io';

import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/features/tickets/data/mock_flight_fixtures.dart';
import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/domain/pass_code.dart';
import 'package:docket/features/tickets/presentation/bus/bus_ticket_code_screen.dart';
import 'package:docket/features/tickets/presentation/flight/flight_ticket_code_screen.dart';
import 'package:docket/features/tickets/presentation/movie/movie_ticket_code_screen.dart';
import 'package:docket/features/tickets/presentation/pass_code_row.dart';
import 'package:docket/features/tickets/presentation/pass_code_screen.dart';
import 'package:docket/features/tickets/presentation/pass_typography.dart';
import 'package:docket/features/tickets/presentation/train/train_ticket_code_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets('shared code screens and category row variants', (tester) async {
    final cache = Directory('build/pass-code-preview/fonts')
      ..createSync(recursive: true);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => cache.absolute.path,
    );
    await tester.runAsync(() async {
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      GoogleFonts.config.allowRuntimeFetching = false;
      AppTheme.lightTheme;
      PassType.screenTitle(Colors.black);
      PassType.caption(Colors.black);
      PassType.code(Colors.black);
      PassType.sectionTitle(Colors.black);
      await GoogleFonts.pendingFonts();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);

    final screens = <String, Widget>{
      'train': TrainTicketCodeScreen(ticket: mockTrainPasses.first),
      'movie': MovieTicketCodeScreen(pass: mockMoviePasses.first),
      'bus': BusTicketCodeScreen(pass: mockBusPasses.first),
      'flight': FlightTicketCodeScreen(pass: mockFlightPasses.first),
      'missing': const PassCodeScreen(
        code: null,
        title: 'Bengaluru → Chennai',
        reference: 'RB-12345',
      ),
      'rows': Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              PassCodeRow(
                code: PassCode.parse(payload: 'SCAN-1', format: 'qr')!,
                onTap: () {},
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                color: const Color(0xFF311A47),
                child: PassCodeRow.embedded(
                  code: PassCode.parse(payload: 'SCAN-1', format: 'code128')!,
                  onTap: () {},
                  accent: Colors.purple,
                ),
              ),
            ],
          ),
        ),
      ),
    };
    for (final dark in [false, true]) {
      for (final entry in screens.entries) {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            home: entry.value,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../build/pass-code-preview/${entry.key}_${dark ? 'dark' : 'light'}.png',
          ),
        );
      }
    }
  });
}
