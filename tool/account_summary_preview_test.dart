// flutter test --no-pub tool/account_summary_preview_test.dart --update-goldens
// Renders the account summary with real fonts; previews stay under build/.
import 'dart:io';

import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/features/dashboard/presentation/widgets/account_summary.dart';
import 'package:docket/features/dashboard/presentation/widgets/account_greeting.dart';
import 'package:docket/features/dashboard/presentation/widgets/membership_horizon.dart';
import 'package:docket/features/ids/domain/id_document.dart';
import 'package:docket/features/passport/domain/passport_profile.dart';
import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets('Account summary in both themes', (tester) async {
    final fontCache = Directory('build/account-summary-preview/fonts')
      ..createSync(recursive: true);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => fontCache.absolute.path,
    );
    await tester.runAsync(() async {
      HttpOverrides.global = null;
      AppTheme.lightTheme;
      AppTheme.darkTheme;
      await GoogleFonts.pendingFonts();
    });
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 560 * 3);
    addTearDown(tester.view.reset);

    final List<WalletPassItem> passes = <WalletPassItem>[
      ...mockTrainPasses.map(TrainPassItem.new),
      ...mockMoviePasses.map(MoviePassItem.new),
      ...mockBusPasses.map(BusPassItem.new),
    ];
    final List<IdDocument> ids = <IdDocument>[
      IdDocument(
        type: IdDocumentType.aadhaar,
        holderName: 'A',
        documentNumber: '1',
      ),
      IdDocument(
        type: IdDocumentType.pan,
        holderName: 'A',
        documentNumber: '2',
      ),
    ];
    final List<PassportProfile> passports = <PassportProfile>[
      PassportProfile(
        name: 'A',
        passportNumber: 'X',
        nationality: 'IND',
        dateOfBirth: '',
        expiryDate: '',
        imagePath: '',
        mrzRaw: '',
      ),
    ];

    for (final bool dark in <bool>[false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 180,
                  child: MembershipHorizon(key: ValueKey('horizon-$dark')),
                ),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 36, 24, 116),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const AccountGreeting(displayName: 'Navadeep'),
                              const SizedBox(height: 18),
                              AccountSummary(
                                key: ValueKey<bool>(dark),
                                passes: passes,
                                ids: ids,
                                passports: passports,
                                showCaption: false,
                              ),
                              const SizedBox(height: 28),
                              UpNextSummary(passes: passes),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      for (final int ms in <int>[700, 3600]) {
        await tester.pump(Duration(milliseconds: ms == 700 ? 700 : 2900));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../build/account-summary-preview/${dark ? 'dark' : 'light'}_$ms.png',
          ),
        );
      }
      expect(tester.takeException(), isNull);
    }
  });
}
