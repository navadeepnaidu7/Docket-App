import 'package:docket/features/cards/domain/payment_card.dart';
import 'package:docket/features/cards/presentation/card_review_screen.dart';
import 'package:docket/features/cards/presentation/wallet_payment_card.dart';
import 'package:docket/features/cards/presentation/bank_mark.dart';
import 'package:docket/features/cards/presentation/network_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  PaymentCard sample({String cvv = '123'}) {
    return PaymentCard(
      id: 'card-face',
      holderName: 'Nava Deep',
      number: '4111111111111111',
      expiryMonth: 9,
      expiryYear: 2028,
      cvv: cvv,
      kind: CardKind.debit,
      bankName: 'HDFC Bank',
      issuerId: 'hdfc',
    );
  }

  Future<void> pumpCard(WidgetTester tester, PaymentCard card) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              height: 220,
              child: WalletPaymentCard(
                card: card,
                now: () => DateTime(2026, 11, 13),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the face shows the last four until the number is tapped', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpCard(tester, sample());

    expect(find.text('1111'), findsOneWidget);
    expect(find.text('••••'), findsOneWidget);
    expect(find.text('4111 1111 1111 1111'), findsNothing);
    expect(find.text('123'), findsNothing);
    expect(find.text('HDFC Bank'), findsOneWidget);
    expect(find.text('Debit'), findsOneWidget);
    expect(find.bySemanticsLabel('Visa'), findsOneWidget);

    await tester.tap(
      find.bySemanticsLabel('Card number ending 1111. Double tap to reveal.'),
    );
    await tester.pump();
    expect(find.text('4111 1111 1111 1111'), findsOneWidget);

    expect(find.text('Security code'), findsNothing);
    for (final label in ['Card number', 'Ending in', 'Cardholder', 'Expires']) {
      expect(find.text(label), findsNothing);
    }
    expect(
      tester.getCenter(find.byType(BankMark)).dy,
      closeTo(tester.getCenter(find.text('HDFC Bank')).dy, .5),
    );
    expect(
      tester.getTopLeft(find.text('Debit')).dy,
      greaterThan(tester.getBottomRight(find.byType(NetworkMark)).dy),
    );

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('4111 1111 1111 1111'), findsNothing);
    expect(find.text('123'), findsNothing);
    expect(find.text('1111'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('security code stays off the face', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpCard(tester, sample());
    expect(
      find.bySemanticsLabel('Security code hidden. Double tap to reveal.'),
      findsNothing,
    );
    expect(find.text('1111'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('an expired card says Expired', (WidgetTester tester) async {
    await pumpCard(tester, sample().copyWith(expiryMonth: 1, expiryYear: 2020));
    expect(find.text('Expired'), findsOneWidget);
  });

  testWidgets('review refuses a number that fails the check', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CardReviewScreen(number: '4111111111111112')),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Check the card number.'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Check the card number.'), findsOneWidget);
    final FilledButton button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save card'),
    );
    expect(button.onPressed, isNull);
  });
}
