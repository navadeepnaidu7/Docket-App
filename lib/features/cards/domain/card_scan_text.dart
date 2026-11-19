import '../../../core/scanning/field_votes.dart';
import '../../../core/scanning/ocr_fixes.dart';
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
final RegExp _expiry = RegExp(r'\b(0[1-9]|1[0-2])\s*[/\-]\s*(\d{4}|\d{2})\b');
final RegExp _expiryLabel = RegExp(
  r'(?:THRU|THROUGH|EXP(?:IRY|IRES)?|VALID\s*(?:TO|UPTO|TILL)|UPTO|END)\W{0,12}$',
  caseSensitive: false,
);
final RegExp _sinceLabel = RegExp(
  r'(?:FROM|SINCE|MEMBER|ISSUED?)\W{0,12}$',
  caseSensitive: false,
);
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
  'member',
  'since',
  'from',
  'month',
  'year',
  'expiry',
  'expires',
  'contactless',
  'international',
  'electron',
  'maestro',
  'titanium',
  'select',
  'premier',
  'privilege',
  'rewards',
  'cashback',
  'issued',
  'transferable',
  'property',
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
  found.addAll(_numbersAcrossRuns(text));
  if (found.isEmpty) return '';
  found.sort(
    (String a, String b) => _numberScore(b).compareTo(_numberScore(a)),
  );
  return found.first;
}

/// Embossed groups often come back as separate lines or blocks, so
/// "4111 1111" and "1111 1111" never meet in one regex match. Consecutive
/// digit runs are joined here, and a join counts only when it passes Luhn
/// and its prefix names a network at that length: a random pairing of an
/// expiry and a phone number passes Luhn one time in ten, both checks
/// together far less often.
List<String> _numbersAcrossRuns(String text) {
  final List<String> runs = RegExp(
    r'\d+',
  ).allMatches(text).map((Match match) => match.group(0)!).toList();
  final List<String> found = <String>[];
  for (var i = 0; i < runs.length; i++) {
    if (runs[i].length < 3) continue;
    var joined = runs[i];
    for (var j = i + 1; j < runs.length && j < i + 5; j++) {
      if (runs[j].length < 3) break;
      joined += runs[j];
      if (joined.length > 19) break;
      if (joined.length >= 13 &&
          luhnValid(joined) &&
          matchCardNetwork(joined) != null) {
        found.add(joined);
      }
    }
  }
  return found;
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
    // Embossed and printed holder names are capitals; taglines rarely are.
    final bool capitals = line == line.toUpperCase();
    final int score = words.length * 2 + line.length + (capitals ? 20 : 0);
    if (score > bestScore) {
      best = words.join(' ');
      bestScore = score;
    }
  }
  return best;
}

/// A card can print a "valid from" date beside the expiry. A date behind an
/// expiry label wins, a date behind a from/since label loses, and otherwise
/// the latest plausible date is the expiry.
(int, int)? _bestExpiry(String text, DateTime now) {
  (int, int)? best;
  int? bestScore;
  for (final RegExpMatch match in _expiry.allMatches(text)) {
    final int month = int.parse(match.group(1)!);
    final int yearPart = int.parse(match.group(2)!);
    final int year = yearPart < 100 ? 2000 + yearPart : yearPart;
    if (year < now.year - 12 || year > now.year + 25) continue;
    final String before = text.substring(
      match.start < 24 ? 0 : match.start - 24,
      match.start,
    );
    var score = year * 12 + month;
    if (_expiryLabel.hasMatch(before)) score += 1 << 20;
    if (_sinceLabel.hasMatch(before)) score -= 1 << 20;
    if (bestScore == null || score > bestScore) {
      best = (month, year);
      bestScore = score;
    }
  }
  return best;
}

CardScanFields parseCardOcr(String raw, {DateTime? now}) {
  final String text = fixDigitWords(raw);
  final String number = _bestNumber(text);
  final (int, int)? expiry = _bestExpiry(text, now ?? DateTime.now());

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
      if (digits.length !=
          (matchCardNetwork(number)?.securityCodeLength ?? 3)) {
        continue;
      }
      if (!withoutNumber.contains(digits)) continue;
      cvv = digits;
      break;
    }
  }

  return CardScanFields(
    number: number,
    holderName: _nameFrom(raw, number) ?? '',
    expiryMonth: expiry?.$1,
    expiryYear: expiry?.$2,
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
  final network =
      matchCardNetwork(front.number) ?? matchCardNetwork(back.number);
  if (network == CardNetwork.amex) {
    if (front.cvv.length == 4) return front.cvv;
    if (back.cvv.length == 4) return back.cvv;
  }
  if (back.cvvLabeled && back.cvv.isNotEmpty) return back.cvv;
  if (front.cvvLabeled && front.cvv.isNotEmpty) return front.cvv;
  if (back.cvv.isNotEmpty) return back.cvv;
  return front.cvv;
}

/// Readings of one side of a card across many preview frames.
///
/// A number is a vote only when it passes Luhn, so a misread never outvotes
/// the real number however often it repeats.
class CardScanConsensus {
  final FieldVotes _number = FieldVotes();
  final FieldVotes _expiry = FieldVotes();
  final FieldVotes _name = FieldVotes();
  final FieldVotes _cvv = FieldVotes();
  final Set<String> _labeledCvvs = <String>{};
  int _framesSinceNumber = 0;

  /// Adds one reading. A full-resolution still is worth more than a preview
  /// frame, so callers pass a higher [weight] for it.
  void add(CardScanFields fields, {double weight = 1}) {
    if (fields.number.isNotEmpty && luhnValid(fields.number)) {
      final bool named = matchCardNetwork(fields.number) != null;
      _number.add(fields.number, weight: named ? weight : weight * 0.5);
    }
    if (fields.expiryMonth != null && fields.expiryYear != null) {
      _expiry.add('${fields.expiryMonth}/${fields.expiryYear}', weight: weight);
    }
    _name.add(fields.holderName.toUpperCase(), weight: weight);
    if (fields.cvv.isNotEmpty) {
      _cvv.add(fields.cvv, weight: fields.cvvLabeled ? weight * 2 : weight);
      if (fields.cvvLabeled) _labeledCvvs.add(fields.cvv);
    }
    if (_number.settled()) _framesSinceNumber++;
  }

  /// The front is done once the number is settled and the expiry has caught
  /// up, or a few more frames have passed without one.
  bool get frontReady =>
      _number.settled() &&
      (_expiry.settled(minWeight: 2) || _framesSinceNumber >= 5);

  /// The back is done once a security code or a number is settled.
  bool get backReady => _cvv.settled(minWeight: 4) || _number.settled();

  CardScanFields get fields {
    final List<String> expiry = _expiry.leader.split('/');
    final String cvv = _cvv.leader;
    return CardScanFields(
      number: _number.leader,
      holderName: _name.settled(minWeight: 2, minShare: 0.4)
          ? _name.leader
          : '',
      expiryMonth: expiry.length == 2 ? int.tryParse(expiry[0]) : null,
      expiryYear: expiry.length == 2 ? int.tryParse(expiry[1]) : null,
      cvv: cvv,
      cvvLabeled: _labeledCvvs.contains(cvv),
    );
  }

  void clear() {
    _number.clear();
    _expiry.clear();
    _name.clear();
    _cvv.clear();
    _labeledCvvs.clear();
    _framesSinceNumber = 0;
  }
}

/// [primary] field by field, with [fallback] filling whatever it lacks.
CardScanFields preferCardFields(
  CardScanFields primary,
  CardScanFields fallback,
) {
  final bool hasNumber = primary.number.isNotEmpty && luhnValid(primary.number);
  final bool hasExpiry = primary.expiryMonth != null;
  final bool hasCvv = primary.cvv.isNotEmpty;
  return CardScanFields(
    number: hasNumber ? primary.number : fallback.number,
    holderName: primary.holderName.isNotEmpty
        ? primary.holderName
        : fallback.holderName,
    expiryMonth: hasExpiry ? primary.expiryMonth : fallback.expiryMonth,
    expiryYear: hasExpiry ? primary.expiryYear : fallback.expiryYear,
    cvv: hasCvv ? primary.cvv : fallback.cvv,
    cvvLabeled: hasCvv ? primary.cvvLabeled : fallback.cvvLabeled,
  );
}
