import 'card_number.dart';

/// Fields proposed from one side of a card. Nothing here is saved.
class CardScanFields {
  const CardScanFields({
    this.number = '',
    this.holderName = '',
    this.expiryMonth,
    this.expiryYear,
    this.cvv = '',
    this.cvvLabeled = false,
  });

  final String number;
  final String holderName;
  final int? expiryMonth;
  final int? expiryYear;
  final String cvv;

  /// True when a security code sat next to a CVV, CVC or CID label.
  final bool cvvLabeled;

  static const CardScanFields empty = CardScanFields();
}

final RegExp _groupedNumber = RegExp(
  r'\b(?:\d{4}[ -]){3}\d{1,7}\b|\b\d{4}[ -]\d{6}[ -]\d{4,5}\b',
);
final RegExp _continuousNumber = RegExp(r'\b\d{13,19}\b');
final RegExp _expiry = RegExp(r'\b(0[1-9]|1[0-2])\s*[/\-]\s*(\d{2}|\d{4})\b');
final RegExp _labeledCvv = RegExp(
  r'\b(?:CVV2?|CVC2?|CSC|CID)\b\s*[:\-]?\s*(\d{3,4})\b',
  caseSensitive: false,
);

const Set<String> _nameReject = <String>{
  'bank',
  'debit',
  'credit',
  'visa',
  'rupay',
  'mastercard',
  'master',
  'american',
  'express',
  'discover',
  'unionpay',
  'jcb',
  'diners',
  'club',
  'valid',
  'thru',
  'through',
  'good',
  'signature',
  'electronic',
  'platinum',
  'classic',
  'gold',
  'prepaid',
  'customer',
  'authorized',
  'authorised',
  'card',
  'world',
  'infinite',
  'business',
  'india',
  'indian',
};

int _numberScore(String digits) {
  var score = 0;
  if (luhnValid(digits)) score += 4;
  if (matchCardNetwork(digits) != null) score += 2;
  if (digits.length == 16) score += 1;
  return score;
}

String _bestNumber(String text) {
  final List<String> found = <String>[];
  for (final RegExp pattern in <RegExp>[_groupedNumber, _continuousNumber]) {
    for (final RegExpMatch match in pattern.allMatches(text)) {
      final String digits = cardDigits(match.group(0)!);
      if (digits.length >= 13 && digits.length <= 19) found.add(digits);
    }
  }
  if (found.isEmpty) return '';
  found.sort(
    (String a, String b) => _numberScore(b).compareTo(_numberScore(a)),
  );
  return found.first;
}

String? _nameFrom(String text, String number) {
  final String withoutNumber = number.isEmpty
      ? text
      : text.replaceAll(number, ' ');
  String? best;
  var bestScore = 0;
  for (final String rawLine in withoutNumber.split(RegExp(r'[\r\n]+'))) {
    final String line = rawLine.trim();
    if (line.length < 5 || line.length > 40) continue;
    if (RegExp(r'\d').hasMatch(line)) continue;
    if (!RegExp(r"^[A-Za-z][A-Za-z .'-]+$").hasMatch(line)) continue;
    final List<String> words = line
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList();
    if (words.length < 2 || words.length > 4) continue;
    if (words.any((String word) => _nameReject.contains(word.toLowerCase()))) {
      continue;
    }
    final int score = words.length * 2 + line.length;
    if (score > bestScore) {
      best = words.join(' ');
      bestScore = score;
    }
  }
  return best;
}

CardScanFields parseCardOcr(String text) {
  final String number = _bestNumber(text);
  final RegExpMatch? expiry = _expiry.firstMatch(text);
  int? month;
  int? year;
  if (expiry != null) {
    month = int.parse(expiry.group(1)!);
    final int yearPart = int.parse(expiry.group(2)!);
    year = yearPart < 100 ? 2000 + yearPart : yearPart;
  }

  String cvv = '';
  var labeled = false;
  final RegExpMatch? labeledMatch = _labeledCvv.firstMatch(text);
  if (labeledMatch != null) {
    cvv = labeledMatch.group(1)!;
    labeled = true;
  } else if (number.isNotEmpty) {
    final String stripped = text.replaceAll(RegExp(r'[\s-]'), '');
    final String withoutNumber = stripped.replaceFirst(number, '');
    for (final String line in text.split(RegExp(r'[\r\n]+'))) {
      final String digits = cardDigits(line);
      if (digits.length != (matchCardNetwork(number)?.securityCodeLength ?? 3)) {
        continue;
      }
      if (!withoutNumber.contains(digits)) continue;
      cvv = digits;
      break;
    }
  }

  return CardScanFields(
    number: number,
    holderName: _nameFrom(text, number) ?? '',
    expiryMonth: month,
    expiryYear: year,
    cvv: cvv,
    cvvLabeled: labeled,
  );
}

/// Front first, then the back fills whatever the front did not have.
///
/// A labeled CVV beats an unlabeled one. Otherwise the back wins, because
/// that is the side a CVV is usually printed on.
CardScanFields mergeCardScans(CardScanFields front, CardScanFields back) {
  final String number = _numberScore(back.number) > _numberScore(front.number)
      ? back.number
      : front.number;
  final String cvv = _pickCvv(front, back);
  return CardScanFields(
    number: number,
    holderName: front.holderName.isNotEmpty
        ? front.holderName
        : back.holderName,
    expiryMonth: front.expiryMonth ?? back.expiryMonth,
    expiryYear: front.expiryYear ?? back.expiryYear,
    cvv: cvv,
    cvvLabeled:
        cvv.isNotEmpty &&
        ((front.cvv == cvv && front.cvvLabeled) ||
            (back.cvv == cvv && back.cvvLabeled)),
  );
}

String _pickCvv(CardScanFields front, CardScanFields back) {
  final network = matchCardNetwork(front.number) ?? matchCardNetwork(back.number);
  if (network == CardNetwork.amex) {
    if (front.cvv.length == 4) return front.cvv;
    if (back.cvv.length == 4) return back.cvv;
  }
  if (back.cvvLabeled && back.cvv.isNotEmpty) return back.cvv;
  if (front.cvvLabeled && front.cvv.isNotEmpty) return front.cvv;
  if (back.cvv.isNotEmpty) return back.cvv;
  return front.cvv;
}
