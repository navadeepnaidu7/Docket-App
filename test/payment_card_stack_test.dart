import 'helpers/pump_card_transitions.dart';
import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/core/wallet/wallet_items.dart';
import 'package:docket/core/wallet/wallet_palette.dart';
import 'package:docket/features/cards/application/payment_card_stack_provider.dart';
import 'package:docket/features/cards/application/card_list_provider.dart';
import 'package:docket/features/cards/domain/payment_card.dart';
import 'package:docket/features/cards/domain/card_issuer.dart';
import 'package:docket/features/cards/presentation/payment_card_stack_view.dart';
import 'package:docket/features/cards/presentation/card_detail_screen.dart';
import 'package:docket/core/wallet/wallet_loading_provider.dart';
import 'package:docket/features/dashboard/presentation/widgets/ids_tab.dart';
import 'package:docket/features/ids/domain/id_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<PaymentCard> samples() => [
  PaymentCard(
    id: 'hdfc',
    bankName: 'HDFC Bank',
    issuerId: 'hdfc',
    number: '4111111111111111',
    holderName: 'Alex Morgan',
    expiryMonth: 9,
    expiryYear: 2030,
    kind: CardKind.credit,
  ),
  PaymentCard(
    id: 'icici',
    bankName: 'ICICI Bank',
    issuerId: 'icici',
    number: '5555555555554444',
    holderName: 'Alex Morgan',
    expiryMonth: 3,
    expiryYear: 2031,
    kind: CardKind.debit,
  ),
  PaymentCard(
    id: 'canara',
    bankName: 'Canara Bank',
    issuerId: 'canara',
    number: '6073840000000001',
    holderName: 'Alex Morgan',
    expiryMonth: 6,
    expiryYear: 2032,
    kind: CardKind.debit,
  ),
  PaymentCard(
    id: 'amex',
    bankName: 'American Express',
    issuerId: 'amex',
    number: '378282246310005',
    holderName: 'Alex Morgan',
    expiryMonth: 12,
    expiryYear: 2030,
    kind: CardKind.credit,
  ),
];

Finder face(String id) => find.byKey(ValueKey('stack-face-$id'));

List<PaymentCard> stressCards(int count) => List.generate(count, (i) {
  final issuer = cardIssuers[i % cardIssuers.length];
  return samples()[i % 4].copyWith(
    id: 'many-$i',
    bankName: issuer.name,
    issuerId: issuer.id,
  );
});

Future<void> warmStackFonts(WidgetTester tester) => tester.runAsync(() async {
  AppTheme.lightTheme;
  AppTheme.darkTheme;
  GoogleFonts.robotoMono();
  await GoogleFonts.pendingFonts();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
});

class _FixtureCards extends CardListController {
  _FixtureCards(super.ref) {
    state = samples();
    loaded = Future<void>.value();
  }
}

Future<void> tapFace(WidgetTester tester, String id) =>
    tester.tapAt(tester.getTopLeft(face(id)) + const Offset(100, 24));

Future<void> pumpStack(
  WidgetTester tester, {
  List<PaymentCard>? cards,
  ValueChanged<PaymentCard>? onOpen,
  ValueNotifier<String?>? reveal,
  bool dark = true,
  bool reduced = false,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('stack-preview'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 28, 100),
                child: PaymentCardStackView(
                  cards: cards ?? samples(),
                  revealCardId: reveal,
                  onOpen: onOpen ?? (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await pumpCardTransitions(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'groups only payment cards at their first position without changing order',
    () {
      final cards = samples();
      final a = IdDocument(
        id: 'a',
        type: IdDocumentType.pan,
        holderName: 'Alex',
        documentNumber: 'ABCDE1234F',
      );
      final b = IdDocument(
        id: 'b',
        type: IdDocumentType.aadhaar,
        holderName: 'Alex',
        documentNumber: 'ABCDE1234F',
      );
      final raw = <Object>[a, cards[0], b, ...cards.skip(1)];
      final grouped = groupWalletPaymentCards(raw);
      expect(grouped, hasLength(3));
      expect(grouped.first, same(a));
      expect(grouped.last, same(b));
      final group = grouped[1] as PaymentCardStackGroup;
      expect(group.cards, cards);
      expect(walletItemId(group), PaymentCardStackGroup.walletId);
      expect(
        WalletPalette.forItem(group).primary,
        WalletPalette.forItem(cards[0]).primary,
      );
      expect(raw, hasLength(6));
      expect(groupWalletPaymentCards([a, b]), [a, b]);
      expect(
        (groupWalletPaymentCards([cards[0]]).single as PaymentCardStackGroup)
            .cards,
        [cards[0]],
      );
    },
  );

  test(
    'preference defaults off, persists and survives a fresh provider',
    () async {
      final first = ProviderContainer();
      expect(first.read(paymentCardStackProvider), isFalse);
      await first.read(paymentCardStackProvider.notifier).setEnabled(true);
      first.dispose();
      final second = ProviderContainer();
      addTearDown(second.dispose);
      second.read(paymentCardStackProvider);
      await Future<void>.delayed(Duration.zero);
      expect(second.read(paymentCardStackProvider), isTrue);
      await second.read(paymentCardStackProvider.notifier).setEnabled(false);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          paymentCardStackPreferenceKey,
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'first tap selects; second opens that exact card, with no PAN reveal',
    (tester) async {
      PaymentCard? opened;
      await pumpStack(tester, onOpen: (card) => opened = card);
      final start = tester.getTopLeft(face('icici')).dy;
      await tapFace(tester, 'icici');
      await pumpCardTransitions(tester);
      expect(opened, isNull);
      expect(tester.getTopLeft(face('icici')).dy, lessThan(start));
      expect(find.byKey(const Key('return-to-card-stack')), findsOneWidget);
      expect(find.text('5555 5555 5555 4444'), findsNothing);
      await tapFace(tester, 'icici');
      expect(opened?.id, 'icici');
      await tester.tap(find.byKey(const Key('return-to-card-stack')));
      await pumpCardTransitions(tester);
      expect(tester.getTopLeft(face('icici')).dy, closeTo(start, .1));
    },
  );

  testWidgets('back returns selection to the stack; removed selection resets', (
    tester,
  ) async {
    await pumpStack(tester);
    await tapFace(tester, 'hdfc');
    await pumpCardTransitions(tester);
    await Navigator.of(
      tester.element(find.byType(PaymentCardStackView)),
    ).maybePop();
    await pumpCardTransitions(tester);
    expect(find.byKey(const Key('return-to-card-stack')), findsNothing);
    await tapFace(tester, 'icici');
    await pumpCardTransitions(tester);
    await pumpStack(
      tester,
      cards: samples().where((card) => card.id != 'icici').toList(),
    );
    expect(find.byKey(const Key('return-to-card-stack')), findsNothing);
    expect(face('icici'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'no heading, count, instructions or All cards text in either state',
    (tester) async {
      await pumpStack(tester);
      expect(find.text('Cards'), findsNothing);
      expect(find.text('4'), findsNothing);
      expect(find.textContaining('Tap a card'), findsNothing);
      await tapFace(tester, 'icici');
      await pumpCardTransitions(tester);
      expect(find.text('All cards'), findsNothing);
      expect(find.textContaining('Tap the card'), findsNothing);
    },
  );

  testWidgets(
    'swipe switches both ways, tracks the finger, and pull down returns',
    (tester) async {
      final reveal = ValueNotifier<String?>('icici');
      addTearDown(reveal.dispose);
      PaymentCard? opened;
      await pumpStack(tester, reveal: reveal, onOpen: (card) => opened = card);
      final start = tester.getCenter(find.text('ICICI Bank'));
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(-24, 0));
      await tester.pump();
      final before = tester.getCenter(find.text('ICICI Bank')).dx;
      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump();
      expect(
        tester.getCenter(find.text('ICICI Bank')).dx,
        closeTo(before - 50, 1),
      );
      await gesture.moveBy(const Offset(-100, 0));
      await gesture.up();
      await pumpCardTransitions(tester);
      await tapFace(tester, 'canara');
      expect(opened?.id, 'canara');
      await tester.drag(face('canara'), const Offset(240, 0));
      await pumpCardTransitions(tester);
      await tapFace(tester, 'icici');
      expect(opened?.id, 'icici');
      await tester.drag(face('icici'), const Offset(0, 110));
      await pumpCardTransitions(tester);
      expect(find.byKey(const Key('return-to-card-stack')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('swipe boundaries and a cancelled drag keep the selected card', (
    tester,
  ) async {
    final reveal = ValueNotifier<String?>('hdfc');
    addTearDown(reveal.dispose);
    PaymentCard? opened;
    await pumpStack(tester, reveal: reveal, onOpen: (card) => opened = card);
    await tester.drag(face('hdfc'), const Offset(220, 0));
    await pumpCardTransitions(tester);
    await tapFace(tester, 'hdfc');
    expect(opened?.id, 'hdfc');
    reveal.value = 'amex';
    await pumpCardTransitions(tester);
    await tester.drag(face('amex'), const Offset(-220, 0));
    await pumpCardTransitions(tester);
    final drag = await tester.startGesture(tester.getCenter(face('amex')));
    await drag.moveBy(const Offset(45, 0));
    await tester.pump();
    await drag.cancel();
    await pumpCardTransitions(tester);
    await tapFace(tester, 'amex');
    expect(opened?.id, 'amex');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a moving card can be grabbed without continuing its lift under the finger',
    (tester) async {
      final reveal = ValueNotifier<String?>(null);
      addTearDown(reveal.dispose);
      await pumpStack(tester, reveal: reveal);
      reveal.value = 'icici';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      final drag = await tester.startGesture(
        tester.getCenter(find.text('ICICI Bank')),
      );
      await drag.moveBy(const Offset(-25, 0));
      await tester.pump();
      final held = tester.getTopLeft(face('icici')).dy;
      await drag.moveBy(const Offset(-35, 0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(face('icici')).dy, closeTo(held, .1));
      await drag.cancel();
      await pumpCardTransitions(tester);
      expect(tester.getTopLeft(face('icici')).dy, closeTo(28, .1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final count in [5, 10, 15]) {
    testWidgets(
      '$count cards: every card is reachable, selectable and opens correctly',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final cards = stressCards(count);
        PaymentCard? opened;
        await pumpStack(tester, cards: cards, onOpen: (card) => opened = card);
        for (int i = 0; i < count; i++) {
          await tester.ensureVisible(face('many-$i'));
          await pumpCardTransitions(tester);
          await tapFace(tester, 'many-$i');
          await pumpCardTransitions(tester);
          expect(
            find.byKey(const Key('return-to-card-stack')),
            findsOneWidget,
            reason: 'Card $i of $count must select',
          );
          await tapFace(tester, 'many-$i');
          expect(opened?.id, 'many-$i');
          await tester.tap(find.byKey(const Key('return-to-card-stack')));
          await pumpCardTransitions(tester);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$count cards: selection stays pinned while deck scrolls; last card lifts without jumping',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final cards = stressCards(count);
        final reveal = ValueNotifier<String?>('many-0');
        addTearDown(reveal.dispose);
        PaymentCard? opened;
        await pumpStack(
          tester,
          cards: cards,
          reveal: reveal,
          onOpen: (card) => opened = card,
        );
        final pinned = tester.getTopLeft(face('many-0')).dy;
        final scroll = tester
            .widget<SingleChildScrollView>(
              find.byKey(const Key('payment-card-stack-scroll')),
            )
            .controller!;
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pump();
        expect(tester.getTopLeft(face('many-0')).dy, closeTo(pinned, .1));
        final last = 'many-${count - 1}';
        final before = tester.getTopLeft(face(last)).dy;
        await tapFace(tester, last);
        await tester.pump();
        expect(
          tester.getTopLeft(face(last)).dy,
          closeTo(before, .1),
          reason:
              'Converting a scrolled face to pinned coordinates must not jump',
        );
        await pumpCardTransitions(tester);
        expect(tester.getTopLeft(face(last)).dy, closeTo(pinned, .1));
        await tapFace(tester, last);
        expect(opened?.id, last);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$count cards rendered at top, bottom and after lifting', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await warmStackFonts(tester);
      await pumpStack(tester, cards: stressCards(count));
      Future<void> capture(String state) => expectLater(
        find.byKey(const Key('stack-preview')),
        matchesGoldenFile('goldens/payment_card_stack_${count}_$state.png'),
      );
      await capture('top');
      final scroll = tester
          .widget<SingleChildScrollView>(
            find.byKey(const Key('payment-card-stack-scroll')),
          )
          .controller!;
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await pumpCardTransitions(tester);
      await capture('bottom');
      await tapFace(tester, 'many-${count - 1}');
      await tester.pump();
      if (count == 15) {
        await tester.pump(const Duration(milliseconds: 80));
        await capture('lift_80ms');
        await tester.pump(const Duration(milliseconds: 100));
        await capture('lift_180ms');
      }
      await pumpCardTransitions(tester);
      await capture('selected');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('rapid selection changes retain rendered positions mid-spring', (
    tester,
  ) async {
    final reveal = ValueNotifier<String?>(null);
    addTearDown(reveal.dispose);
    await pumpStack(tester, reveal: reveal);
    reveal.value = 'canara';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final before = tester.getTopLeft(face('icici')).dy;
    reveal.value = 'icici';
    await tester.pump();
    expect(tester.getTopLeft(face('icici')).dy, closeTo(before, .1));
    await pumpCardTransitions(tester);
    expect(
      tester.getTopLeft(face('icici')).dy,
      lessThan(tester.getTopLeft(face('canara')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manage reveal lands on group and selects requested card', (
    tester,
  ) async {
    final cards = samples();
    final id = IdDocument(
      id: 'pan',
      type: IdDocumentType.pan,
      holderName: 'Alex',
      documentNumber: 'ABCDE1234F',
    );
    final raw = <Object>[id, ...cards];
    final reveal = ValueNotifier<String?>('canara');
    final page = ValueNotifier<double>(0);
    addTearDown(reveal.dispose);
    addTearDown(page.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          passportLoadingProvider.overrideWith((ref) => false),
          idLoadingProvider.overrideWith((ref) => false),
          cardLoadingProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: IdsTab(
              items: groupWalletPaymentCards(raw),
              allItems: raw,
              pageNotifier: page,
              revealItemId: reveal,
              onDeletePassport: (_) {},
              onDeleteId: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await pumpCardTransitions(tester);
    expect(page.value, 1);
    expect(reveal.value, isNull);
    expect(find.byKey(const Key('return-to-card-stack')), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Canara Bank, RuPay, debit, ending in 0001'),
      ),
      matchesSemantics(
        label: 'Canara Bank, RuPay, debit, ending in 0001',
        hint: 'Open card details',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'long stacks scroll; narrow large text and reduced motion remain usable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cards = List.generate(
        12,
        (i) => samples()[i % 4].copyWith(id: 'card$i'),
      );
      await pumpStack(tester, cards: cards, reduced: true, scale: 1.8);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -900),
      );
      await pumpCardTransitions(tester);
      await tester.ensureVisible(face('card11'));
      await tapFace(tester, 'card11');
      await tester.pump();
      expect(find.byKey(const Key('return-to-card-stack')), findsOneWidget);
      expect(tester.getTopLeft(face('card11')).dy, closeTo(28, .1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected face opens existing details and keeps selection on return',
    (tester) async {
      final raw = samples();
      final page = ValueNotifier<double>(0);
      addTearDown(page.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            passportLoadingProvider.overrideWith((ref) => false),
            idLoadingProvider.overrideWith((ref) => false),
            cardLoadingProvider.overrideWith((ref) => false),
            cardListProvider.overrideWith((ref) => _FixtureCards(ref)),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: IdsTab(
                items: groupWalletPaymentCards(raw),
                allItems: raw,
                pageNotifier: page,
                onDeletePassport: (_) {},
                onDeleteId: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tapFace(tester, 'icici');
      await pumpCardTransitions(tester);
      expect(find.byKey(const Key('return-to-card-stack')), findsOneWidget);
      expect(find.byType(CardDetailScreen), findsNothing);
      await tapFace(tester, 'icici');
      await pumpCardTransitions(tester);
      expect(
        tester.widget<CardDetailScreen>(find.byType(CardDetailScreen)).cardId,
        'icici',
      );
      await tester.pageBack();
      await pumpCardTransitions(tester);
      expect(find.byType(CardDetailScreen), findsNothing);
      expect(find.byKey(const Key('return-to-card-stack')), findsOneWidget);
      expect(
        tester.getTopLeft(face('icici')).dy,
        lessThan(tester.getTopLeft(face('hdfc')).dy),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final dark in [false, true]) {
    testWidgets('stack ${dark ? 'dark' : 'light'} overview and selection', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(432, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() async {
        AppTheme.lightTheme;
        AppTheme.darkTheme;
        GoogleFonts.robotoMono();
        await GoogleFonts.pendingFonts();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      await pumpStack(tester, dark: dark);
      await expectLater(
        find.byKey(const Key('stack-preview')),
        matchesGoldenFile(
          'goldens/payment_card_stack_${dark ? 'dark' : 'light'}.png',
        ),
      );
      await tapFace(tester, 'icici');
      await pumpCardTransitions(tester);
      await expectLater(
        find.byKey(const Key('stack-preview')),
        matchesGoldenFile(
          'goldens/payment_card_stack_selected_${dark ? 'dark' : 'light'}.png',
        ),
      );
    });
  }
}
