import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/features/cards/domain/card_surface.dart';
import 'package:docket/features/cards/domain/payment_card.dart';
import 'package:docket/features/cards/presentation/card_material.dart';
import 'package:docket/features/cards/presentation/living_card_material.dart';
import 'package:docket/features/cards/presentation/payment_card_stack_view.dart';
import 'package:docket/features/cards/presentation/wallet_payment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'helpers/pump_card_transitions.dart';

Finder get materials => find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is CardMaterial,
);
List<CardMaterial> painters(WidgetTester tester) => tester
    .widgetList<CustomPaint>(materials)
    .map((widget) => widget.painter! as CardMaterial)
    .toList();
bool running(CardMaterial painter) =>
    (painter.time as AnimationController).isAnimating;

PaymentCard sample(String bank, {int variant = 0}) => PaymentCard(
  id: '$bank-$variant',
  issuerId: bank,
  surfaceIndex: variant,
  bankName: switch (bank) {
    'canara' => 'Canara Bank',
    'hdfc' => 'HDFC Bank',
    _ => 'State Bank of India',
  },
  holderName: 'Alex Morgan',
  number: '4111111111111111',
  cvv: '123',
  expiryMonth: 9,
  expiryYear: 2030,
  kind: CardKind.debit,
);

class _CountBuilds extends StatelessWidget {
  const _CountBuilds(this.onBuild);
  final VoidCallback onBuild;
  @override
  Widget build(BuildContext context) {
    onBuild();
    return const Text('Retained card information');
  }
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'ambient repaints retain content; active and TickerMode stop the clock',
    (tester) async {
      final active = ValueNotifier(true);
      final tickers = ValueNotifier(true);
      addTearDown(active.dispose);
      addTearDown(tickers.dispose);
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 440,
                height: 277,
                child: ListenableBuilder(
                  listenable: Listenable.merge([active, tickers]),
                  builder: (context, _) => TickerMode(
                    enabled: tickers.value,
                    child: LivingCardMaterial(
                      surface: cardSurfaceStyle('hdfc', 0),
                      active: active.value,
                      child: _CountBuilds(() => builds++),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final initialBuilds = builds;
      final painter = painters(tester).single;
      await tester.pump(const Duration(seconds: 8));
      expect(painter.time.value, greaterThan(0));
      expect(builds, initialBuilds);
      active.value = false;
      await tester.pump();
      expect(running(painter), isFalse);
      final paused = painter.time.value;
      await tester.pump(const Duration(seconds: 10));
      expect(painter.time.value, paused);
      active.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(painter.time.value, closeTo(paused, .001));
      tickers.value = false;
      await tester.pump();
      expect(running(painter), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'background, route coverage and scrolling out of view pause motion',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  SizedBox(
                    width: 440,
                    height: 277,
                    child: WalletPaymentCard(
                      card: sample('canara'),
                      animate: true,
                    ),
                  ),
                  const SizedBox(height: 2400),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final painter = painters(tester).single;
      expect(running(painter), isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(running(painter), isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(running(painter), isTrue);
      scroll.jumpTo(700);
      await tester.pump();
      expect(running(painter), isFalse);
      scroll.jumpTo(0);
      await tester.pump();
      expect(running(painter), isTrue);
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Covered')),
        ),
      );
      await pumpCardTransitions(tester);
      expect(running(painter), isFalse);
      navigator.currentState!.pop();
      await pumpCardTransitions(tester);
      expect(running(painter), isTrue);
    },
  );

  testWidgets(
    'touch light and spring coexist with secure reveal and long press',
    (tester) async {
      var longPresses = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 440,
                height: 277,
                child: WalletPaymentCard(
                  card: sample('hdfc'),
                  animate: true,
                  onLongPress: () => longPresses++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final painter = painters(tester).single;
      final box = tester.getRect(find.byType(LivingCardMaterial));
      final gesture = await tester.startGesture(
        box.topLeft + const Offset(340, 210),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(painter.horizontal.value, greaterThan(.1));
      expect(painter.contact.value, 1);
      await gesture.cancel();
      await pumpCardTransitions(tester);
      expect(painter.contact.value, 0);
      expect(painter.horizontal.value, closeTo(0, .001));
      await tester.tap(find.text('1111'));
      await tester.pump();
      expect(find.text('4111 1111 1111 1111'), findsOneWidget);
      expect(find.text('123'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('4111 1111 1111 1111'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.longPressAt(box.topLeft + const Offset(100, 60));
      expect(longPresses, 1);
      await pumpCardTransitions(tester);
    },
  );

  testWidgets(
    'reduced motion keeps a static face and brief touch color without tilt',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 440,
                  height: 277,
                  child: WalletPaymentCard(card: sample('sbi'), animate: true),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final painter = painters(tester).single;
      expect(running(painter), isFalse);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(LivingCardMaterial)) +
            const Offset(80, 40),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(painter.contact.value, 1);
      expect(painter.horizontal.value, 0);
      expect(painter.vertical.value, 0);
      expect(painter.time.value, 0);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(painter.contact.value, 0);
    },
  );

  for (final count in [5, 10, 15]) {
    testWidgets('$count card deck runs only the selected ambient clock', (
      tester,
    ) async {
      final reveal = ValueNotifier<String?>(null);
      addTearDown(reveal.dispose);
      final cards = List.generate(
        count,
        (i) => sample('hdfc').copyWith(id: 'fixture-$i'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaymentCardStackView(
              cards: cards,
              onOpen: (_) {},
              revealCardId: reveal,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(painters(tester).where(running), isEmpty);
      for (final i in [0, count - 1, 2, 1]) {
        reveal.value = cards[i].id;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(painters(tester).where(running), hasLength(1));
      }
      await pumpCardTransitions(tester);
      await tester.tap(find.byKey(const Key('return-to-card-stack')));
      await tester.pumpAndSettle();
      expect(painters(tester).where(running), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('native material gallery at resting and eight-second phases', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1380, 940));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      for (final weight in [
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
      ]) {
        AppFonts.ui(fontWeight: weight);
        GoogleFonts.robotoMono(fontWeight: weight);
      }
      await GoogleFonts.pendingFonts();
    });
    final active = ValueNotifier(false);
    addTearDown(active.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: RepaintBoundary(
            key: const Key('material-gallery'),
            child: ColoredBox(
              color: const Color(0xFF17191D),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ValueListenableBuilder<bool>(
                  valueListenable: active,
                  builder: (context, enabled, _) => Column(
                    children: [
                      for (final bank in ['canara', 'hdfc', 'sbi'])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              for (final variant in [0, 1, 0])
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: AspectRatio(
                                      aspectRatio: 440 / 277,
                                      child: WalletPaymentCard(
                                        card: sample(bank, variant: variant),
                                        animate: enabled,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('material-gallery')),
      matchesGoldenFile('goldens/living_card_resting.png'),
    );
    active.value = true;
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    await expectLater(
      find.byKey(const Key('material-gallery')),
      matchesGoldenFile('goldens/living_card_phase_8s.png'),
    );
  });
}
