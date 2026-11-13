import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/features/cards/domain/payment_card.dart';
import 'package:docket/features/cards/presentation/card_review_screen.dart';
import 'package:docket/features/cards/presentation/wallet_payment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> entry(
    WidgetTester tester, {
    bool dark = false,
    CardReviewScreen screen = const CardReviewScreen(),
    double scale = 1,
  }) async {
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
      await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
            rootBundle.load(
              'packages/cupertino_icons/assets/CupertinoIcons.ttf',
            ),
          ))
          .load();
    });
    await tester.pumpWidget(
      ProviderScope(
        child: RepaintBoundary(
          key: const Key('screen'),
          child: MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(432, 894),
                textScaler: TextScaler.linear(scale),
              ),
              child: screen,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets('crafted entry ${dark ? 'dark' : 'light'}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(432, 894));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await entry(
        tester,
        dark: dark,
        screen: const CardReviewScreen(
          number: '378282246310005',
          holderName: 'Alex Morgan',
          expiryMonth: 9,
          expiryYear: 2030,
        ),
      );
      expect(find.text('No mark'), findsNothing);
      expect(find.text('Network'), findsNothing);
      await expectLater(
        find.byKey(const Key('screen')),
        matchesGoldenFile('goldens/card_entry_${dark ? 'dark' : 'light'}.png'),
      );
    });
  }

  testWidgets('empty entry and early network detection', (tester) async {
    await tester.binding.setSurfaceSize(const Size(432, 894));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await entry(tester);
    await expectLater(
      find.byKey(const Key('screen')),
      matchesGoldenFile('goldens/card_entry_empty.png'),
    );
    await tester.enterText(field('Card number'), '37');
    await tester.pumpAndSettle();
    expect(field('Security code · 4 digits'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save card'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('No mark'), findsNothing);
  });

  testWidgets('Amex refuses a three-digit security code', (tester) async {
    await tester.binding.setSurfaceSize(const Size(432, 894));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await entry(
      tester,
      screen: const CardReviewScreen(number: '378282246310005', cvv: '123'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save card'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the 4-digit security code.'), findsOneWidget);
  });

  testWidgets('bank choice uses logos and updates the live preview', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(432, 894));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await entry(tester);
    await tester.tap(find.text('Choose or enter a bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HDFC Bank'));
    await tester.pumpAndSettle();
    expect(find.text('HDFC Bank'), findsNWidgets(2));
  });

  testWidgets('small screen and large text remain scrollable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await entry(tester, scale: 1.5);
    await tester.ensureVisible(field('Card number'));
    await tester.enterText(field('Card number'), '6011111111111117');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Choose or enter a bank'));
    expect(find.text('Choose or enter a bank').hitTestable(), findsOneWidget);
  });

  testWidgets('card material and all network marks', (tester) async {
    await tester.binding.setSurfaceSize(const Size(920, 1220));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final numbers = [
      '4111111111111111',
      '5555555555554444',
      '6521500000000000',
      '378282246310005',
      '6011111111111117',
      '6200000000000005',
      '3530111333300000',
      '30569309025904',
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: const Key('faces'),
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.586,
              padding: const EdgeInsets.all(24),
              mainAxisSpacing: 24,
              crossAxisSpacing: 24,
              children: [
                for (var i = 0; i < numbers.length; i++)
                  WalletPaymentCard(
                    card: PaymentCard(
                      bankName: i == 0
                          ? 'HDFC Bank'
                          : i == 1
                          ? 'Axis Bank'
                          : '',
                      issuerId: i == 0
                          ? 'hdfc'
                          : i == 1
                          ? 'axis'
                          : null,
                      surfaceIndex: i % 3,
                      number: numbers[i],
                      holderName: 'Alex Morgan',
                      expiryMonth: 9,
                      expiryYear: 2030,
                      cvv: i == 3 ? '1234' : '123',
                      kind: CardKind.credit,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('faces')),
      matchesGoldenFile('goldens/card_craft_networks.png'),
    );
  });
}
