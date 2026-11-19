import 'helpers/pump_card_transitions.dart';
import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/features/cards/application/card_list_provider.dart';
import 'package:docket/features/cards/domain/payment_card.dart';
import 'package:docket/features/cards/presentation/card_copy_details.dart';
import 'package:docket/features/cards/presentation/card_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

PaymentCard sample() => PaymentCard(
  id: 'copy-sample',
  number: '378282246310005',
  cvv: '1234',
  holderName: 'Alex Morgan',
  bankName: 'HDFC Bank',
  issuerId: 'hdfc',
  expiryMonth: 9,
  expiryYear: 2030,
  kind: CardKind.credit,
);

class _PreviewCards extends CardListController {
  _PreviewCards(super.ref) {
    state = [sample()];
    loaded = Future<void>.value();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? clipboard;
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  Future<void> pumpDetails(
    WidgetTester tester, {
    PaymentCard? card,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: CardCopyDetails(card: card ?? sample()),
            ),
          ),
        ),
      ),
    );
    await pumpCardTransitions(tester);
  }

  testWidgets('copy exact values without revealing number or security code', (
    tester,
  ) async {
    await pumpDetails(tester);
    for (final field in <String, String>{
      'card number': '378282246310005',
      'security code': '1234',
      'name on card': 'Alex Morgan',
      'expiry date': '09/30',
    }.entries) {
      await tester.tap(find.byTooltip('Copy ${field.key}'));
      await tester.pump();
      expect(clipboard, field.value);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('3782 822463 10005'), findsNothing);
      expect(find.text('1234'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    }
  });

  testWidgets('reveals expire independently and hide on background', (
    tester,
  ) async {
    await pumpDetails(tester);
    await tester.tap(find.byTooltip('Reveal card number'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byTooltip('Reveal security code'));
    await tester.pump();
    expect(find.text('3782 822463 10005'), findsOneWidget);
    expect(find.text('1234'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('3782 822463 10005'), findsNothing);
    expect(find.text('1234'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('1234'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('absent values have no copy or reveal action', (tester) async {
    await pumpDetails(tester, card: PaymentCard(id: 'empty'));
    expect(find.text('Not added'), findsNWidgets(4));
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('long number and large text fit a narrow screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpDetails(
      tester,
      card: sample().copyWith(number: '4111111111111111111'),
      scale: 1.6,
    );
    await tester.tap(find.byTooltip('Reveal card number'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final dark in [false, true]) {
    testWidgets('copy detail screen ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(432, 1020));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() async {
        AppTheme.lightTheme;
        AppTheme.darkTheme;
        for (final weight in [FontWeight.w400, FontWeight.w500]) {
          GoogleFonts.robotoMono(fontWeight: weight);
        }
        await GoogleFonts.pendingFonts();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cardListProvider.overrideWith((ref) => _PreviewCards(ref)),
          ],
          child: RepaintBoundary(
            key: const Key('details'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              home: const CardDetailScreen(cardId: 'copy-sample'),
            ),
          ),
        ),
      );
      await pumpCardTransitions(tester);
      await expectLater(
        find.byKey(const Key('details')),
        matchesGoldenFile(
          'goldens/card_copy_details_${dark ? 'dark' : 'light'}.png',
        ),
      );
    });
  }
}
