import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/features/ids/application/id_list_provider.dart';
import 'package:docket/features/ids/domain/id_document.dart';
import 'package:docket/features/ids/presentation/id_document_screen.dart';
import 'package:docket/shared/widgets/detail_info_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

IdDocument _sample(IdDocumentType type) => IdDocument(
  id: 'detail-sample',
  type: type,
  holderName: 'Asha Rao',
  documentNumber: type == IdDocumentType.pan ? 'ABCDE1234F' : '1234 5678 9012',
  dateOfBirth: '1990-01-01',
  fatherName: 'Ravi Rao',
  gender: 'Female',
  address:
      'Flat 12, Lake View Apartments, MG Road, Bengaluru, Karnataka 560001',
);

class _Documents extends IdListController {
  _Documents(super.ref, IdDocument document) {
    state = [document];
    loaded = Future<void>.value();
  }
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpScreen(
    WidgetTester tester, {
    required IdDocument document,
    bool dark = false,
    double scale = 1,
  }) async {
    await tester.runAsync(() async {
      AppTheme.lightTheme;
      AppTheme.darkTheme;
      await GoogleFonts.pendingFonts();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
            rootBundle.load(
              'packages/cupertino_icons/assets/CupertinoIcons.ttf',
            ),
          ))
          .load();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          idListProvider.overrideWith((ref) => _Documents(ref, document)),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: IdDocumentScreen(documentId: document.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final type in IdDocumentType.values) {
    testWidgets('$type copies from both row and icon, omits empty actions', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final document = _sample(type).copyWith(dateOfBirth: '');
      await pumpScreen(tester, document: document);
      final numberLabel = type == IdDocumentType.pan
          ? 'PAN number'
          : 'Aadhaar number';
      await tester.tap(find.byTooltip('Copy ${numberLabel.toLowerCase()}'));
      await tester.pump();
      expect(copied, document.documentNumber);
      expect(find.byTooltip('$numberLabel copied'), findsOneWidget);
      expect(find.byTooltip('Copy date of birth'), findsNothing);
      final nameRow = find.descendant(
        of: find.byType(DetailInfoCard),
        matching: find.text('Asha Rao'),
      );
      await tester.tap(nameRow);
      await tester.pump();
      expect(copied, document.holderName);
      await tester.pump(const Duration(seconds: 2));
    });
  }

  for (final dark in [false, true]) {
    testWidgets('Aadhaar detail ${dark ? 'dark' : 'light'}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpScreen(
        tester,
        document: _sample(IdDocumentType.aadhaar),
        dark: dark,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/id_detail_${dark ? 'dark' : 'light'}.png'),
      );
    });

    testWidgets(
      'long address fits at 320dp and 2x text ${dark ? 'dark' : 'light'}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await pumpScreen(
          tester,
          document: _sample(IdDocumentType.aadhaar),
          dark: dark,
          scale: 2,
        );
        await tester.scrollUntilVisible(find.byTooltip('Copy address'), 180);
        expect(tester.takeException(), isNull);
        expect(
          find.text(_sample(IdDocumentType.aadhaar).address),
          findsOneWidget,
        );
      },
    );
  }
}
