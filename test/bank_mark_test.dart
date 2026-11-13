import 'package:docket/features/cards/domain/card_issuer.dart';
import 'package:docket/features/cards/domain/payment_card.dart';
import 'package:docket/features/cards/presentation/wallet_payment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  test(
    'bank aliases stay distinct and confirmed names override prefix hints',
    () {
      expect(issuerFromName('  IDFC FIRST Bank ')?.id, 'idfc');
      expect(issuerFromName('Kotak Mahindra')?.id, 'kotak');
      expect(issuerFromName('SBI Card')?.id, 'sbi');
      expect(issuerFromName('J.P. Morgan Chase')?.id, 'chase');
      expect(issuerFromName('Bank of India'), isNull);
      expect(issuerFromName('Punjab & Sind Bank'), isNull);
      expect(issuerFromName('City Union Bank'), isNull);
      expect(issuerFromName('Not HDFC Bank'), isNull);
      expect(
        issuerForCard(bankName: 'My local bank', number: '5085060000000000'),
        isNull,
      );
      for (final CardIssuer issuer in cardIssuers) {
        expect(issuerFromName(issuer.name)?.id, issuer.id);
      }
    },
  );

  testWidgets('all bundled bank marks decode at wallet and thumbnail sizes', (
    tester,
  ) async {
    for (final CardIssuer issuer in cardIssuers) {
      for (final double width in <double>[340, 150]) {
        for (final int surface in <int>[0, 1]) {
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey('${issuer.id}-$width-$surface'),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    height: width / 1.586,
                    child: WalletPaymentCard(
                      card: PaymentCard(
                        id: issuer.id,
                        bankName: issuer.name,
                        issuerId: issuer.id,
                        surfaceIndex: surface,
                        number: '4111111111111111',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(SvgPicture), findsWidgets);
          expect(tester.takeException(), isNull, reason: issuer.name);
        }
      }
    }
  });

  testWidgets(
    'unknown confirmed bank has no mark even with a stale issuer id',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 340,
              height: 215,
              child: WalletPaymentCard(
                card: PaymentCard(
                  bankName: 'City Union Bank',
                  issuerId: 'hdfc',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SvgPicture), findsNothing);
      expect(find.text('City Union Bank'), findsOneWidget);
    },
  );

  testWidgets('bank marks on dark and light card faces', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1470));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final List<CardIssuer> examples = <CardIssuer>[
      hdfcIssuer,
      axisIssuer,
      sbiIssuer,
      citiIssuer,
      standardIssuer,
      federalIssuer,
      wellsIssuer,
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFEEEEEE),
          body: RepaintBoundary(
            key: const Key('bank-faces'),
            child: Column(
              children: <Widget>[
                for (final CardIssuer issuer in examples)
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        for (final int surface in <int>[0, 1])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: WalletPaymentCard(
                                card: PaymentCard(
                                  bankName: issuer.name,
                                  issuerId: issuer.id,
                                  surfaceIndex: surface,
                                  kind: CardKind.debit,
                                  number: '4111111111111111',
                                  holderName: 'Sample Holder',
                                  expiryMonth: 9,
                                  expiryYear: 2030,
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
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('bank-faces')),
      matchesGoldenFile('goldens/payment_card_bank_marks.png'),
    );
  });

  testWidgets('bank artwork and same-bank shade variants', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1380, 1490));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final examples = <(String, String, int)>[
      ('hdfc', 'HDFC Bank', 0),
      ('hdfc', 'HDFC Bank', 1),
      ('canara', 'Canara Bank', 0),
      ('icici', 'ICICI Bank', 0),
      ('sbi', 'State Bank of India', 0),
      ('axis', 'Axis Bank', 0),
      ('kotak', 'Kotak', 0),
      ('idfc', 'IDFC FIRST Bank', 0),
      ('citi', 'Citibank', 0),
      ('hsbc', 'HSBC', 0),
      ('chase', 'Chase', 0),
      ('standard', 'Standard Chartered', 0),
      ('federal', 'Federal Bank', 0),
      ('wells', 'Wells Fargo', 0),
      ('bob', 'Bank of Baroda', 0),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFECECEA),
          body: RepaintBoundary(
            key: const Key('bank-artwork'),
            child: Column(
              children: [
                for (var row = 0; row < 5; row++)
                  Expanded(
                    child: Row(
                      children: [
                        for (final (id, name, shade)
                            in examples.skip(row * 3).take(3))
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: AspectRatio(
                                aspectRatio: 1.586,
                                child: WalletPaymentCard(
                                  card: PaymentCard(
                                    id: '$id-$shade',
                                    issuerId: id,
                                    bankName: name,
                                    surfaceIndex: shade,
                                    holderName: 'Alex Morgan',
                                    number: shade == 1
                                        ? '4000000000002291'
                                        : '4111111111111019',
                                    cvv: '123',
                                    kind: CardKind.credit,
                                    expiryMonth: 9,
                                    expiryYear: 2030,
                                  ),
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
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('bank-artwork')),
      matchesGoldenFile('goldens/card_bank_artwork.png'),
    );
  });
}
