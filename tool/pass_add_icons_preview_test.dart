// flutter test --no-pub tool/pass_add_icons_preview_test.dart --update-goldens
// Render the actual add flow with real fonts; previews stay under build/.
import 'dart:io';

import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/features/tickets/presentation/add/add_pass_flow.dart';
import 'package:docket/features/tickets/presentation/add/pass_add_art.dart';
import 'package:docket/shared/widgets/morph_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets('Passes artwork in both themes at phone widths', (tester) async {
    final fontCache = Directory('build/pass-add-preview/fonts')
      ..createSync(recursive: true);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => fontCache.absolute.path,
    );
    await tester.runAsync(() async {
      HttpOverrides.global = null;
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final cupertino = FontLoader('packages/cupertino_icons/CupertinoIcons')
        ..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        );
      await cupertino.load();
      AppTheme.lightTheme;
      AppTheme.darkTheme;
      await GoogleFonts.pendingFonts();
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final dark in <bool>[false, true]) {
      for (final width in <double>[390, 320]) {
        final height = width == 320 ? 568.0 : 844.0;
        tester.view.physicalSize = Size(width, height);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => Center(
                    child: IconButton(
                      onPressed: () => showAddPassFlow(context, ref),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(PassAddArt), findsNWidgets(6));
        for (final label in <String>['Flights', 'Events', 'More']) {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(find.text('Passes'), findsOneWidget);
        }
        Future<void> capture(String step) async {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../build/pass-add-preview/${step}_${dark ? 'dark' : 'light'}_${width.toInt()}.png',
            ),
          );
        }

        await capture('categories');
        await tester.tap(find.text('Trains'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(PassAddArt), findsNWidgets(3));
        expect(find.text('Enter PNR'), findsOneWidget);
        expect(find.text('Photo'), findsOneWidget);
        expect(find.text('PDF'), findsOneWidget);
        await capture('methods');

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(MorphSheet), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
}
