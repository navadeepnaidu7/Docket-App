/// Reading Aadhaar and PAN cards from OCR text.
///
/// Every number is checked before it is proposed: Aadhaar numbers carry a
/// Verhoeff check digit and PANs a fixed letter/digit shape, so most misreads
/// are caught here instead of in the wallet.
library;

import '../../../core/scanning/field_votes.dart';
import '../../../core/scanning/ocr_fixes.dart';
import 'aadhaar_qr.dart';
import 'id_document.dart';

class IdScanResult {
  const IdScanResult({
    required this.type,
    this.holderName = '',
    this.documentNumber = '',
    this.dateOfBirth = '',
    this.fatherName = '',
    this.address = '',
    this.gender = '',
    this.capturedImagePath = '',
    this.qrCodeData = '',
  });

  final IdDocumentType type;
  final String holderName;
  final String documentNumber;
  final String dateOfBirth;
  final String fatherName;
  final String address;
  final String gender;
  final String capturedImagePath;
  final String qrCodeData;

  bool get isEmpty => documentNumber.isEmpty && holderName.isEmpty;

  IdScanResult copyWith({
    String? holderName,
    String? documentNumber,
    String? dateOfBirth,
    String? fatherName,
    String? address,
    String? gender,
    String? capturedImagePath,
    String? qrCodeData,
  }) {
    return IdScanResult(
      type: type,
      holderName: holderName ?? this.holderName,
      documentNumber: documentNumber ?? this.documentNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      fatherName: fatherName ?? this.fatherName,
      address: address ?? this.address,
      gender: gender ?? this.gender,
      capturedImagePath: capturedImagePath ?? this.capturedImagePath,
      qrCodeData: qrCodeData ?? this.qrCodeData,
    );
  }
}

// ── Checksums ───────────────────────────────────────────────────────────────

const List<List<int>> _verhoeffD = <List<int>>[
  <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
  <int>[1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
  <int>[2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
  <int>[3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
  <int>[4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
  <int>[5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
  <int>[6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
  <int>[7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
  <int>[8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
  <int>[9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
];

const List<List<int>> _verhoeffP = <List<int>>[
  <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
  <int>[1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
  <int>[5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
  <int>[8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
  <int>[9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
  <int>[4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
  <int>[2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
  <int>[7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
];

/// The Verhoeff check UIDAI uses for the twelfth digit. It catches every
/// single-digit misread and every swap of neighbouring digits.
bool verhoeffValid(String digits) {
  if (digits.isEmpty || !RegExp(r'^\d+$').hasMatch(digits)) return false;
  var c = 0;
  for (var i = 0; i < digits.length; i++) {
    final int n = digits.codeUnitAt(digits.length - 1 - i) - 48;
    c = _verhoeffD[c][_verhoeffP[i % 8][n]];
  }
  return c == 0;
}

/// Twelve digits, not starting with 0 or 1, with a valid check digit.
bool aadhaarNumberValid(String raw) {
  final String digits = raw.replaceAll(RegExp(r'\s'), '');
  return RegExp(r'^[2-9]\d{11}$').hasMatch(digits) && verhoeffValid(digits);
}

String formatAadhaar(String digits) =>
    '${digits.substring(0, 4)} ${digits.substring(4, 8)} ${digits.substring(8)}';

/// The fourth PAN character names the holder type: P for a person, C for a
/// company, and so on.
const String _panHolderTypes = 'ABCFGHLJPT';

bool panNumberValid(String raw) {
  final RegExpMatch? m = RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').firstMatch(raw);
  return m != null && _panHolderTypes.contains(raw[3]);
}

// ── Shared helpers ──────────────────────────────────────────────────────────

List<String> _lines(String text) => text
    .split(RegExp(r'[\r\n]+'))
    .map((String l) => l.trim())
    .where((String l) => l.isNotEmpty)
    .toList();

String _titleCase(String s) => s
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((String w) => w.isNotEmpty)
    .map((String w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

/// A line of Latin script with no digits: the shape of a printed name.
bool _looksLikeName(String line, Set<String> reject) {
  final String clean = line.replaceAll(RegExp(r'[.,]'), ' ').trim();
  if (clean.length < 3 || clean.length > 48) return false;
  if (!RegExp(r"^[A-Za-z][A-Za-z '\-]*$").hasMatch(clean)) return false;
  final List<String> words = clean
      .split(RegExp(r'\s+'))
      .where((String w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty || words.length > 5) return false;
  if (words.length == 1 && clean.length < 4) return false;
  return !words.any((String w) => reject.contains(w.toLowerCase()));
}

String _cleanName(String line) =>
    _titleCase(line.replaceAll(RegExp(r'[.,]'), ' ').trim());

final RegExp _dateRe = RegExp(
  r'\b(\d{2})\s?[/\-.]\s?(\d{2})\s?[/\-.]\s?(\d{4})\b',
);

/// A real calendar date between 1900 and [now], as `yyyy-MM-dd`.
String? _birthDate(String d, String m, String y, DateTime now) {
  final int? day = int.tryParse(d);
  final int? month = int.tryParse(m);
  final int? year = int.tryParse(y);
  if (day == null || month == null || year == null) return null;
  if (year < 1900 || month < 1 || month > 12 || day < 1) return null;
  final DateTime date = DateTime(year, month, day);
  if (date.month != month || date.isAfter(now)) return null;
  return '$y-$m-$d';
}

/// The date of birth, preferring one behind a birth label and skipping
/// issue, download and print dates that e-Aadhaar and new PANs carry.
String _dateOfBirth(String text, DateTime now) {
  String? labeled;
  String? plain;
  for (final RegExpMatch match in _dateRe.allMatches(text)) {
    final String? date = _birthDate(
      match.group(1)!,
      match.group(2)!,
      match.group(3)!,
      now,
    );
    if (date == null) continue;
    final String before = text
        .substring(match.start < 40 ? 0 : match.start - 40, match.start)
        .toLowerCase();
    final String lastLine = before.split('\n').last;
    final String context = lastLine.trim().isEmpty ? before : lastLine;
    if (RegExp(r'issue|download|generat|print|valid|जारी').hasMatch(context)) {
      continue;
    }
    if (RegExp(r'dob|birth|जन्म').hasMatch(context)) {
      labeled ??= date;
    } else {
      plain ??= date;
    }
  }
  return labeled ?? plain ?? '';
}

// ── Aadhaar ─────────────────────────────────────────────────────────────────

const Set<String> _aadhaarReject = <String>{
  'government',
  'govt',
  'india',
  'of',
  'aadhaar',
  'aadhar',
  'unique',
  'identification',
  'authority',
  'uidai',
  'male',
  'female',
  'transgender',
  'dob',
  'yob',
  'birth',
  'date',
  'year',
  'address',
  'enrolment',
  'enrollment',
  'help',
  'download',
  'issue',
  'vid',
  'mera',
  'pehchaan',
  'identity',
  'citizenship',
  'proof',
  'information',
  'details',
  'to',
};

final RegExp _aadhaarGrouped = RegExp(
  r'(?<!\d)(\d{4})\s?(\d{4})\s?(\d{4})(?![ \t]?\d)',
);
final RegExp _vid = RegExp(r'\b\d{4}[ \t]?\d{4}[ \t]?\d{4}[ \t]?\d{4}\b');

/// The Aadhaar number, valid ones first. A VID (16 digits) is never one.
String _aadhaarNumber(String text) {
  final String withoutVid = text.replaceAll(_vid, ' ');
  String? unchecked;
  for (final RegExpMatch m in _aadhaarGrouped.allMatches(withoutVid)) {
    final String digits = '${m.group(1)}${m.group(2)}${m.group(3)}';
    if (aadhaarNumberValid(digits)) return formatAadhaar(digits);
    if (RegExp(r'^[2-9]').hasMatch(digits)) unchecked ??= digits;
  }
  // Groups that OCR split across lines.
  final List<String> runs = RegExp(
    r'\d+',
  ).allMatches(withoutVid).map((Match m) => m.group(0)!).toList();
  for (var i = 0; i + 2 < runs.length; i++) {
    if (runs[i].length != 4 || runs[i + 1].length != 4) continue;
    if (runs[i + 2].length != 4) continue;
    final String digits = '${runs[i]}${runs[i + 1]}${runs[i + 2]}';
    if (aadhaarNumberValid(digits)) return formatAadhaar(digits);
  }
  return unchecked == null ? '' : formatAadhaar(unchecked);
}

String _aadhaarGender(String text) {
  if (RegExp(r'\bFEMALE\b|महिला', caseSensitive: false).hasMatch(text)) {
    return 'Female';
  }
  if (RegExp(r'\bMALE\b|पुरुष', caseSensitive: false).hasMatch(text)) {
    return 'Male';
  }
  if (RegExp(
    r'\bTRANSGENDER\b|\bOTHER\b|ट्रांसजेंडर',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'Other';
  }
  return '';
}

/// On the front the name sits directly above the date-of-birth line, with
/// the Hindi name sometimes in between. That anchor beats "first line in
/// capitals", which picked up headers and missed names printed in title case.
String _aadhaarName(List<String> lines) {
  final int anchor = lines.indexWhere(
    (String l) => RegExp(
      r'\b(?:DOB|YOB|Year of Birth|Date of Birth)\b|जन्म',
      caseSensitive: false,
    ).hasMatch(l),
  );
  if (anchor > 0) {
    for (var i = anchor - 1; i >= 0 && i >= anchor - 3; i--) {
      if (_looksLikeName(lines[i], _aadhaarReject)) return _cleanName(lines[i]);
    }
  }
  final int gender = lines.indexWhere(
    (String l) =>
        RegExp(r'\b(?:MALE|FEMALE)\b', caseSensitive: false).hasMatch(l),
  );
  if (gender > 1) {
    for (var i = gender - 2; i >= 0 && i >= gender - 4; i--) {
      if (_looksLikeName(lines[i], _aadhaarReject)) return _cleanName(lines[i]);
    }
  }
  // Letters and e-Aadhaar print "To" then the name above the address.
  final int to = lines.indexWhere((String l) => l.toLowerCase() == 'to');
  if (to != -1 && to + 1 < lines.length) {
    for (var i = to + 1; i < lines.length && i <= to + 3; i++) {
      if (_looksLikeName(lines[i], _aadhaarReject)) return _cleanName(lines[i]);
    }
  }
  return '';
}

/// The back: from the "Address" label to the line with the six-digit PIN.
String _aadhaarAddress(List<String> lines) {
  final int start = lines.indexWhere(
    (String l) => RegExp(r'^address\b', caseSensitive: false).hasMatch(l),
  );
  if (start == -1) return '';
  final List<String> parts = <String>[];
  final String first = lines[start]
      .replaceFirst(RegExp(r'^address\s*[:\-]?\s*', caseSensitive: false), '')
      .trim();
  if (first.isNotEmpty) parts.add(first);
  for (var i = start + 1; i < lines.length && i <= start + 7; i++) {
    final String line = lines[i];
    if (_aadhaarGrouped.hasMatch(line) || _vid.hasMatch(line)) break;
    // Skip the Hindi copy of the address; keep the Latin one.
    if (!RegExp(r'[A-Za-z]').hasMatch(line)) continue;
    parts.add(line);
    if (RegExp(r'(?<!\d)\d{6}(?!\d)').hasMatch(line)) break;
  }
  return parts
      .join(' ')
      .replaceAll(RegExp(r'\s*,\s*'), ', ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .replaceAll(RegExp(r',\s*$'), '')
      .trim();
}

IdScanResult parseAadhaarText(String raw, {DateTime? now}) {
  final DateTime today = now ?? DateTime.now();
  final String fixed = fixDigitWords(raw);
  final List<String> lines = _lines(raw);
  String dob = _dateOfBirth(fixed, today);
  if (dob.isEmpty) {
    final RegExpMatch? yob = RegExp(
      r'\b(?:YOB|Year of Birth)\s*[:\-]?\s*((?:19|20)\d{2})\b',
      caseSensitive: false,
    ).firstMatch(fixed);
    if (yob != null) dob = yob.group(1)!;
  }
  return IdScanResult(
    type: IdDocumentType.aadhaar,
    holderName: _aadhaarName(lines),
    documentNumber: _aadhaarNumber(fixed),
    dateOfBirth: dob,
    gender: _aadhaarGender(raw),
    address: _aadhaarAddress(lines),
  );
}

// ── PAN ─────────────────────────────────────────────────────────────────────

const Set<String> _panReject = <String>{
  'income',
  'tax',
  'department',
  'govt',
  'government',
  'india',
  'of',
  'permanent',
  'account',
  'number',
  'card',
  'signature',
  'name',
  'father',
  "father's",
  'fathers',
  'date',
  'birth',
  'pan',
  'e-pan',
  'epan',
};

/// Reads a PAN even when OCR has swapped letters and digits: positions 1-5
/// and 10 are letters, 6-9 digits, so each character is coerced to the class
/// its position needs before the shape is checked.
String _panNumber(String text) {
  final String direct = RegExp(r'[A-Z]{5}\d{4}[A-Z]')
      .allMatches(text.replaceAll(' ', ''))
      .map((Match m) => m.group(0)!)
      .firstWhere(panNumberValid, orElse: () => '');
  if (direct.isNotEmpty) return direct;
  for (final String line in _lines(text)) {
    final String squeezed = line.replaceAll(RegExp(r'[\s\-]'), '');
    for (var i = 0; i + 10 <= squeezed.length; i++) {
      final String window = squeezed.substring(i, i + 10);
      final StringBuffer out = StringBuffer();
      var ok = true;
      for (var j = 0; j < 10 && ok; j++) {
        final String? c = (j >= 5 && j <= 8)
            ? digitFor(window[j])
            : letterFor(window[j]);
        if (c == null) {
          ok = false;
        } else {
          out.write(c);
        }
      }
      if (ok && panNumberValid(out.toString())) return out.toString();
    }
  }
  return '';
}

/// The value under [label], or on the same line after it. New PANs print
/// "नाम / Name" as one line, so a label is matched anywhere in the line.
String _panLabeled(List<String> lines, RegExp label, {int from = 0}) {
  for (var i = from; i < lines.length; i++) {
    final RegExpMatch? m = label.firstMatch(lines[i]);
    if (m == null) continue;
    final String rest = lines[i]
        .substring(m.end)
        .replaceFirst(RegExp(r'^[\s:/\-]+'), '');
    if (_looksLikeName(rest, _panReject)) return _cleanName(rest);
    for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
      if (_looksLikeName(lines[j], _panReject)) return _cleanName(lines[j]);
    }
  }
  return '';
}

final RegExp _fatherLabel = RegExp(
  r"father'?s?\s*name|पिता",
  caseSensitive: false,
);
final RegExp _nameLabel = RegExp(
  r"(?<![a-z'])name\b|नाम",
  caseSensitive: false,
);

IdScanResult parsePanText(String raw, {DateTime? now}) {
  final DateTime today = now ?? DateTime.now();
  final String fixed = fixDigitWords(raw);
  final List<String> lines = _lines(raw);

  String father = _panLabeled(lines, _fatherLabel);
  String holder = '';
  for (var i = 0; i < lines.length; i++) {
    // The holder's label is the first "Name" line that is not the father's.
    if (_fatherLabel.hasMatch(lines[i])) continue;
    if (!_nameLabel.hasMatch(lines[i])) continue;
    holder = _panLabeled(lines, _nameLabel, from: i);
    break;
  }

  // The old layout has no labels: holder, father, date of birth, in that
  // order, under the department header.
  if (holder.isEmpty || holder == father) {
    final List<String> names = lines
        .where((String l) => _looksLikeName(l, _panReject))
        .where((String l) => l == l.toUpperCase())
        .map(_cleanName)
        .toList();
    if (names.isNotEmpty) holder = names.first;
    if (father.isEmpty && names.length > 1) father = names[1];
  }
  if (holder == father) holder = '';

  return IdScanResult(
    type: IdDocumentType.pan,
    holderName: holder,
    documentNumber: _panNumber(raw.toUpperCase()),
    dateOfBirth: _dateOfBirth(fixed, today),
    fatherName: father,
  );
}

IdScanResult parseIdText(String text, IdDocumentType type, {DateTime? now}) =>
    switch (type) {
      IdDocumentType.pan => parsePanText(text, now: now),
      IdDocumentType.aadhaar => parseAadhaarText(text, now: now),
    };

/// Lays a decoded Aadhaar QR over the OCR reading. The QR is signed and
/// machine-printed, so its name, birth date, gender and address win. Its
/// last four digits pick between OCR number candidates and veto a number
/// that does not end in them.
IdScanResult applyAadhaarQr(IdScanResult ocr, AadhaarQrData qr) {
  var number = ocr.documentNumber;
  if (qr.number.isNotEmpty && aadhaarNumberValid(qr.number)) {
    number = formatAadhaar(qr.number);
  } else if (qr.lastFour.isNotEmpty &&
      number.isNotEmpty &&
      !number.replaceAll(' ', '').endsWith(qr.lastFour)) {
    number = '';
  }
  return ocr.copyWith(
    holderName: qr.name.isNotEmpty ? _titleCase(qr.name) : null,
    documentNumber: number,
    dateOfBirth: qr.dateOfBirth.isNotEmpty ? qr.dateOfBirth : null,
    gender: qr.gender.isNotEmpty ? qr.gender : null,
    address: qr.address.isNotEmpty ? qr.address : null,
  );
}

bool _numberValid(IdDocumentType type, String number) => switch (type) {
  IdDocumentType.pan => panNumberValid(number),
  IdDocumentType.aadhaar => aadhaarNumberValid(number),
};

/// Readings of one card across many preview frames.
class IdScanConsensus {
  IdScanConsensus(this.type);

  final IdDocumentType type;
  final FieldVotes _number = FieldVotes();
  final FieldVotes _name = FieldVotes();
  final FieldVotes _dob = FieldVotes();
  final FieldVotes _father = FieldVotes();
  final FieldVotes _gender = FieldVotes();
  final FieldVotes _address = FieldVotes();
  String _qr = '';
  AadhaarQrData? _qrData;

  /// Adds one reading. A checksum-failing number is not a vote.
  void add(IdScanResult r, {double weight = 1}) {
    if (_numberValid(type, r.documentNumber)) {
      _number.add(r.documentNumber, weight: weight);
    }
    _name.add(r.holderName, weight: weight);
    _dob.add(r.dateOfBirth, weight: weight);
    _father.add(r.fatherName, weight: weight);
    _gender.add(r.gender, weight: weight);
    _address.add(r.address, weight: weight);
  }

  /// Records a QR payload. Aadhaar QRs are decoded once and kept.
  void addQr(String raw) {
    if (raw.isEmpty || raw == _qr) return;
    final AadhaarQrData? data = type == IdDocumentType.aadhaar
        ? decodeAadhaarQr(raw)
        : null;
    if (type == IdDocumentType.aadhaar && data == null && _qrData != null) {
      return;
    }
    _qr = raw;
    _qrData = data;
  }

  bool get hasQrData => _qrData != null;

  /// The number has agreed across frames, or a signed QR has been read.
  bool get ready =>
      _number.settled() ||
      (_qrData != null &&
          (_qrData!.number.isNotEmpty || _number.settled(minWeight: 2)));

  IdScanResult get result {
    String pick(FieldVotes v) =>
        v.settled(minWeight: 2, minShare: 0.4) ? v.leader : '';
    final IdScanResult votes = IdScanResult(
      type: type,
      documentNumber: _number.leader,
      holderName: pick(_name),
      dateOfBirth: pick(_dob),
      fatherName: pick(_father),
      gender: pick(_gender),
      address: pick(_address),
      qrCodeData: _qr,
    );
    final AadhaarQrData? qr = _qrData;
    return qr == null ? votes : applyAadhaarQr(votes, qr);
  }

  void clear() {
    for (final FieldVotes v in <FieldVotes>[
      _number,
      _name,
      _dob,
      _father,
      _gender,
      _address,
    ]) {
      v.clear();
    }
    _qr = '';
    _qrData = null;
  }
}

/// [primary] field by field, with [fallback] filling whatever it lacks. A
/// number is taken from [primary] only when it passes its check.
IdScanResult preferIdFields(IdScanResult primary, IdScanResult fallback) {
  String pick(String a, String b) => a.isNotEmpty ? a : b;
  final bool primaryNumber = _numberValid(primary.type, primary.documentNumber);
  final bool fallbackNumber = _numberValid(
    fallback.type,
    fallback.documentNumber,
  );
  return primary.copyWith(
    holderName: pick(primary.holderName, fallback.holderName),
    documentNumber: primaryNumber || !fallbackNumber
        ? pick(primary.documentNumber, fallback.documentNumber)
        : fallback.documentNumber,
    dateOfBirth: pick(primary.dateOfBirth, fallback.dateOfBirth),
    fatherName: pick(primary.fatherName, fallback.fatherName),
    address: pick(primary.address, fallback.address),
    gender: pick(primary.gender, fallback.gender),
    capturedImagePath: pick(
      primary.capturedImagePath,
      fallback.capturedImagePath,
    ),
    qrCodeData: pick(primary.qrCodeData, fallback.qrCodeData),
  );
}
