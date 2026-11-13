/// Digits of a card number, expiry checks, and the network those digits name.
///
/// The network is the issuer identification number, the first 6 to 8 digits.
/// The Luhn check only says the number is well formed. It never names Visa,
/// Mastercard, or RuPay.
library;

enum CardNetwork {
  visa,
  mastercard,
  rupay,
  amex,
  discover,
  unionpay,
  jcb,
  diners,
}

extension CardNetworkInfo on CardNetwork {
  String get label => switch (this) {
    CardNetwork.visa => 'Visa',
    CardNetwork.mastercard => 'Mastercard',
    CardNetwork.rupay => 'RuPay',
    CardNetwork.amex => 'American Express',
    CardNetwork.discover => 'Discover',
    CardNetwork.unionpay => 'UnionPay',
    CardNetwork.jcb => 'JCB',
    CardNetwork.diners => 'Diners Club',
  };

  int get securityCodeLength => this == CardNetwork.amex ? 4 : 3;

  List<int> get numberLengths => switch (this) {
    CardNetwork.visa => const [13, 16, 18, 19],
    CardNetwork.mastercard || CardNetwork.rupay => const [16],
    CardNetwork.amex => const [15],
    CardNetwork.discover => const [16, 19],
    CardNetwork.unionpay => const [14, 15, 16, 17, 18, 19],
    CardNetwork.jcb => const [16, 17, 18, 19],
    CardNetwork.diners => const [14, 16, 19],
  };
}

/// Digits only, in the order they were printed.
String cardDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

/// Network-specific grouping, including Amex's 4-6-5 pattern.
String groupedCardNumber(String digits) {
  final String clean = cardDigits(digits);
  final StringBuffer out = StringBuffer();
  final CardNetwork? network = detectCardNetwork(clean);
  final List<int> gaps =
      network == CardNetwork.amex ||
          (network == CardNetwork.diners && clean.length <= 14)
      ? const [4, 10]
      : const [4, 8, 12, 16];
  for (int i = 0; i < clean.length; i++) {
    if (gaps.contains(i)) out.write(' ');
    out.write(clean[i]);
  }
  return out.toString();
}

String cardLastFour(String digits) {
  final String clean = cardDigits(digits);
  if (clean.length <= 4) return clean;
  return clean.substring(clean.length - 4);
}

/// Standard Luhn checksum. An empty string is not a card number.
bool luhnValid(String digits) {
  final String clean = cardDigits(digits);
  if (clean.length < 13 || clean.length > 19) return false;
  var sum = 0;
  var doubleIt = false;
  for (var i = clean.length - 1; i >= 0; i--) {
    final int code = clean.codeUnitAt(i);
    if (code < 48 || code > 57) return false;
    var n = code - 48;
    if (doubleIt) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    doubleIt = !doubleIt;
  }
  return sum % 10 == 0;
}

bool _inRange(String digits, int start, int end) {
  final int width = start.toString().length;
  if (digits.length < width || end.toString().length != width) return false;
  final int value = int.parse(digits.substring(0, width));
  return value >= start && value <= end;
}

/// RuPay owns slices inside ranges that also contain other networks.
///
/// `6` covers Discover and UnionPay. A card is RuPay only inside these slices.
bool _isRuPay(String digits) {
  const List<(int, int)> slices = <(int, int)>[
    (508500, 508999),
    (606985, 606999),
    (607000, 607984),
    (608000, 608999),
    (652150, 652999),
    (653000, 653149),
  ];
  for (final (int start, int end) in slices) {
    if (_inRange(digits, start, end)) return true;
  }
  return false;
}

/// The network named by the number, or null when the digits are outside the
/// offline table. A null result is not a guess the caller may overwrite a
/// later range hit with.
CardNetwork? matchCardNetwork(String raw) {
  final String digits = cardDigits(raw);
  final CardNetwork? network = detectCardNetwork(digits);
  return network != null && network.numberLengths.contains(digits.length)
      ? network
      : null;
}

/// Prefix identification while typing. Full length and checksum are separate.
/// Added ranges/lengths follow Braintree's credit-card-type card-types table.
/// RuPay's more specific six-digit slices take precedence over Discover's 65.
CardNetwork? detectCardNetwork(String raw) {
  final String digits = cardDigits(raw);
  if (_isRuPay(digits)) return CardNetwork.rupay;
  if (_inRange(digits, 51, 55) || _inRange(digits, 2221, 2720)) {
    return CardNetwork.mastercard;
  }
  if (digits.startsWith('4')) return CardNetwork.visa;
  if (digits.startsWith('34') || digits.startsWith('37')) {
    return CardNetwork.amex;
  }
  if (digits.startsWith('6011') ||
      _inRange(digits, 644, 649) ||
      digits.startsWith('65')) {
    return CardNetwork.discover;
  }
  if (_inRange(digits, 3528, 3589) ||
      digits.startsWith('2131') ||
      digits.startsWith('1800')) {
    return CardNetwork.jcb;
  }
  if (_inRange(digits, 300, 305) ||
      digits.startsWith('36') ||
      digits.startsWith('38') ||
      digits.startsWith('39')) {
    return CardNetwork.diners;
  }
  const List<(int, int)> unionPay = [
    (620, 620),
    (62100, 62182),
    (62184, 62197),
    (62200, 62205),
    (622010, 622999),
    (62207, 62209),
    (623, 626),
    (6270, 6270),
    (6272, 6272),
    (6276, 6276),
    (627700, 627779),
    (627781, 627799),
    (6282, 6289),
    (6291, 6292),
    (810, 810),
    (8110, 8171),
  ];
  for (final (int start, int end) in unionPay) {
    if (_inRange(digits, start, end)) return CardNetwork.unionpay;
  }
  return null;
}

bool cardNumberValid(String raw) {
  final CardNetwork? detected = detectCardNetwork(raw);
  return luhnValid(raw) && (detected == null || matchCardNetwork(raw) != null);
}

/// The network the face draws. A range hit always wins over a manual pick.
CardNetwork? effectiveCardNetwork(String raw, CardNetwork? manual) {
  return matchCardNetwork(raw) ?? manual;
}

/// Parses `MM/YY` or `MM/YYYY`. Empty is allowed. Anything else is rejected.
(int, int)? parseCardExpiry(String raw) {
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final RegExpMatch? match = RegExp(
    r'^(0[1-9]|1[0-2])\s*/\s*(\d{2}|\d{4})$',
  ).firstMatch(trimmed);
  if (match == null) return null;
  final int month = int.parse(match.group(1)!);
  final int yearPart = int.parse(match.group(2)!);
  final int year = yearPart < 100 ? 2000 + yearPart : yearPart;
  return (month, year);
}

String formatCardExpiry(int month, int year) {
  final String mm = month.toString().padLeft(2, '0');
  final String yy = (year % 100).toString().padLeft(2, '0');
  return '$mm/$yy';
}

/// A card is expired once the calendar month of its expiry has ended.
bool cardExpiryPassed(int month, int year, DateTime now) {
  final DateTime end = DateTime(year, month + 1, 1);
  return !now.isBefore(end);
}
