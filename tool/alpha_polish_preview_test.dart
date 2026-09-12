// flutter test --no-pub tool/alpha_polish_preview_test.dart --update-goldens
// Review images are generated under build/alpha-preview, not committed goldens.
import 'dart:io';
import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/features/dashboard/domain/wallet_search.dart';
import 'package:docket/features/dashboard/presentation/wallet_search_screen.dart';
import 'package:docket/features/tickets/application/pass_ingest_controller.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_ingest.dart';
import 'package:docket/features/tickets/presentation/add/pass_ingest_outcome.dart';
import 'package:docket/features/ids/domain/id_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets('alpha screens in both themes and accessible sizes', (
    tester,
  ) async {
    final fontCache = Directory('build/alpha-preview/fonts')
      ..createSync(recursive: true);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => fontCache.absolute.path,
    );
    // Allow the actual app font warmup for this manual visual inspection tool.
    await tester.runAsync(() async {
      HttpOverrides.global = null;
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      AppTheme.lightTheme;
      AppTheme.darkTheme;
      await GoogleFonts.pendingFonts();
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final entries = [
      WalletSearchEntry.document(
        IdDocument(
          id: 'id',
          type: IdDocumentType.aadhaar,
          holderName: 'Asha Rao',
          documentNumber: '1234 5678 9012',
        ),
      ),
      WalletSearchEntry.pass(
        TrainPassItem.fromJson({
          'id': 'train',
          'trainName': 'Coastal Express',
          'trainNumber': '12609',
          'fromName': 'Chennai Central',
          'toName': 'Bengaluru',
          'date': '12 Sep 2026',
          'departTime': '17:30',
        }),
      ),
      WalletSearchEntry.pass(
        MoviePassItem.fromJson({
          'id': 'movie',
          'movieTitle': 'Interstellar',
          'cinemaName': 'PVR Orion',
          'showDate': '10 Sep 2026',
          'showTime': '7:30 PM',
          'status': 'expired',
        }),
      ),
    ];
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        final size = scale == 1 ? const Size(390, 844) : const Size(320, 640);
        tester.view.physicalSize = size;
        Future<void> render(String name, Widget screen) async {
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: screen,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../build/alpha-preview/${name}_${dark ? 'dark' : 'light'}_${scale.toInt()}x.png',
            ),
          );
        }

        await render(
          'wallet',
          WalletSearchView(
            entries: entries,
            onOpen: (_) {},
            onAdd: () {},
            onRetry: () {},
          ),
        );
        await render(
          'recovery',
          Scaffold(
            body: PassIngestOutcome(
              state: const PassIngestFailed(
                request: FilePassIngestRequest(
                  path: 'ticket.pdf',
                  category: PassInputCategory.train,
                ),
                error: PassIngestException(
                  PassIngestCode.failed,
                  'Check your connection and try again.',
                ),
              ),
              onRetry: () {},
              onReplace: () {},
              onDismiss: () {},
              onView: (_) {},
            ),
          ),
        );
      }
    }
  });
}
