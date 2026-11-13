import 'package:docket/features/cards/domain/card_issuer.dart';
import 'package:docket/features/cards/domain/card_number.dart';
import 'package:docket/features/cards/domain/card_scan_text.dart';
import 'package:docket/features/cards/domain/card_surface.dart';
import 'package:docket/features/cards/domain/payment_card.dart';
import 'package:flutter_test/flutter_test.dart';

String withLuhn(String body) {
  var sum = 0;
  var doubleIt = true;
  for (var i = body.length - 1; i >= 0; i--) {
    var n = body.codeUnitAt(i) - 48;
    if (doubleIt) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    doubleIt = !doubleIt;
  }
  final int check = (10 - (sum % 10)) % 10;
  return '$body$check';
}

void main() {
  test('Luhn accepts a well formed number and rejects a bad digit', () {
    expect(withLuhn('411111111111111'), '4111111111111111');
    expect(luhnValid('4111111111111111'), isTrue);
    expect(luhnValid('4111 1111 1111 1111'), isTrue);
    expect(luhnValid('4111111111111112'), isFalse);
    expect(luhnValid('411111111111'), isFalse);
    expect(luhnValid(''), isFalse);
  });

  test('Visa is 13, 16, or 19 digits starting with 4', () {
    expect(matchCardNetwork(withLuhn('422222222222')), CardNetwork.visa);
    expect(matchCardNetwork('4111111111111111'), CardNetwork.visa);
    expect(matchCardNetwork(withLuhn('422222222222222222')), CardNetwork.visa);
    expect(matchCardNetwork(withLuhn('4222222222222')), isNull);
  });

  test('Mastercard covers 51-55 and 2221-2720', () {
    expect(
      matchCardNetwork(withLuhn('510000000000000')),
      CardNetwork.mastercard,
    );
    expect(
      matchCardNetwork(withLuhn('550000000000000')),
      CardNetwork.mastercard,
    );
    expect(
      matchCardNetwork(withLuhn('222100000000000')),
      CardNetwork.mastercard,
    );
    expect(
      matchCardNetwork(withLuhn('272000000000000')),
      CardNetwork.mastercard,
    );
    expect(matchCardNetwork(withLuhn('272100000000000')), isNull);
  });

  test('RuPay is only the published slices', () {
    const List<String> inside = <String>[
      '508500',
      '508999',
      '606985',
      '606999',
      '607000',
      '607984',
      '608000',
      '608999',
      '652150',
      '652999',
      '653000',
      '653149',
    ];
    for (final String prefix in inside) {
      final String number = withLuhn(prefix.padRight(15, '0'));
      expect(matchCardNetwork(number), CardNetwork.rupay, reason: prefix);
    }
    const List<String> outside = <String>[
      '508499',
      '601100',
      '606984',
      '607985',
      '652149',
      '653150',
    ];
    for (final String prefix in outside) {
      final String number = withLuhn(prefix.padRight(15, '0'));
      expect(
        matchCardNetwork(number),
        isNot(CardNetwork.rupay),
        reason: prefix,
      );
    }
    expect(matchCardNetwork('6011111111111117'), CardNetwork.discover);
    expect(matchCardNetwork(withLuhn('353000000000000')), CardNetwork.jcb);
  });

  test('a range hit beats a manual network', () {
    expect(
      effectiveCardNetwork('4111111111111111', CardNetwork.mastercard),
      CardNetwork.visa,
    );
    expect(
      effectiveCardNetwork('9999999999999995', CardNetwork.rupay),
      CardNetwork.rupay,
    );
  });

  test('additional networks, lengths, grouping and prefix boundaries', () {
    expect(matchCardNetwork('378282246310005'), CardNetwork.amex);
    expect(matchCardNetwork('371449635398431'), CardNetwork.amex);
    expect(groupedCardNumber('378282246310005'), '3782 822463 10005');
    expect(matchCardNetwork(withLuhn('378282246310000')), isNull);
    expect(matchCardNetwork('6011111111111117'), CardNetwork.discover);
    expect(matchCardNetwork(withLuhn('644000000000000')), CardNetwork.discover);
    expect(matchCardNetwork(withLuhn('649000000000000')), CardNetwork.discover);
    expect(matchCardNetwork(withLuhn('643000000000000')), isNull);
    expect(matchCardNetwork(withLuhn('352800000000000')), CardNetwork.jcb);
    expect(matchCardNetwork(withLuhn('358900000000000')), CardNetwork.jcb);
    expect(matchCardNetwork(withLuhn('359000000000000')), isNull);
    expect(matchCardNetwork('30569309025904'), CardNetwork.diners);
    expect(groupedCardNumber('30569309025904'), '3056 930902 5904');
    expect(matchCardNetwork(withLuhn('620000000000000')), CardNetwork.unionpay);
    expect(detectCardNetwork('37'), CardNetwork.amex);
    expect(detectCardNetwork('6011'), CardNetwork.discover);
    expect(detectCardNetwork('652150'), CardNetwork.rupay);
    expect(matchCardNetwork(withLuhn('652150000000000')), CardNetwork.rupay);
    expect(matchCardNetwork(withLuhn('653150000000000')), CardNetwork.discover);
    expect(cardNumberValid(withLuhn('378282246310000')), isFalse);
  });

  test('Amex OCR reads 4-6-5 numbers and a four-digit CID', () {
    final fields = parseCardOcr(
      'AMERICAN EXPRESS\n3782 822463 10005\nSAMPLE HOLDER\n09/30\nCID 1234',
    );
    expect(fields.number, '378282246310005');
    expect(fields.cvv, '1234');
    expect(fields.holderName, 'SAMPLE HOLDER');
    expect(fields.cvvLabeled, isTrue);
  });

  test('known prefixes name the bank and an unknown Visa does not', () {
    final String hdfc = withLuhn('508506000000000');
    final String icici = withLuhn('405533000000000');
    expect(matchCardNetwork(hdfc), CardNetwork.rupay);
    expect(lookupCardIssuer(hdfc)?.id, 'hdfc');
    expect(matchCardNetwork(icici), CardNetwork.visa);
    expect(lookupCardIssuer(icici)?.name, 'ICICI Bank');
    expect(matchCardNetwork('4111111111111111'), CardNetwork.visa);
    expect(lookupCardIssuer('4111111111111111'), isNull);
  });

  test('a second card from the same bank takes the next shade', () {
    final PaymentCard first = PaymentCard(
      id: 'a',
      issuerId: 'hdfc',
      surfaceIndex: 0,
    );
    expect(
      assignCardSurface(issuerId: 'hdfc', existing: <PaymentCard>[first]),
      1,
    );
    final PaymentCard second = PaymentCard(
      id: 'b',
      issuerId: 'hdfc',
      surfaceIndex: 1,
    );
    expect(
      assignCardSurface(
        issuerId: 'hdfc',
        existing: <PaymentCard>[first, second],
      ),
      0,
    );
    expect(
      assignCardSurface(
        issuerId: 'hdfc',
        existing: <PaymentCard>[first, second],
        exceptId: 'b',
      ),
      1,
    );
  });

  test('a typed bank name selects the family when the digits do not', () {
    expect(issuerFromName('State Bank of India')?.id, 'sbi');
    expect(issuerFromName('Kotak Mahindra')?.id, 'kotak');
    expect(issuerFromName('Neighbourhood bank'), isNull);
    final ({String? issuerId, int surfaceIndex, String bankName}) face =
        resolveCardFace(
          bankName: 'Axis Bank',
          number: '4111111111111111',
          existing: const <PaymentCard>[],
        );
    expect(face.issuerId, 'axis');
    expect(face.bankName, 'Axis Bank');
    expect(face.surfaceIndex, 0);
  });

  test('expiry parses, and a card expires after its month ends', () {
    expect(parseCardExpiry(''), isNull);
    expect(parseCardExpiry('09/28'), (9, 2028));
    expect(parseCardExpiry('09/2028'), (9, 2028));
    expect(parseCardExpiry('13/28'), isNull);
    expect(cardExpiryPassed(11, 2026, DateTime(2026, 11, 13)), isFalse);
    expect(cardExpiryPassed(10, 2026, DateTime(2026, 11, 13)), isTrue);
  });

  test('a card record without an id is refused', () {
    expect(
      () => PaymentCard.fromMap(<String, dynamic>{'holderName': 'A'}),
      throwsFormatException,
    );
  });

  test('ocr keeps a labeled code and lets the front name win', () {
    final CardScanFields front = parseCardOcr(
      'HDFC BANK\n4111 1111 1111 1111\nNAVA DEEP\n09/28',
    );
    expect(front.number, '4111111111111111');
    expect(front.holderName, 'NAVA DEEP');
    expect(front.expiryMonth, 9);
    expect(front.expiryYear, 2028);
    expect(front.cvv, isEmpty);

    final CardScanFields back = parseCardOcr('CVV 123\nAUTHORIZED SIGNATURE');
    expect(back.cvv, '123');
    expect(back.cvvLabeled, isTrue);

    final CardScanFields merged = mergeCardScans(front, back);
    expect(merged.number, '4111111111111111');
    expect(merged.holderName, 'NAVA DEEP');
    expect(merged.cvv, '123');
    expect(merged.expiryMonth, 9);
  });
}
