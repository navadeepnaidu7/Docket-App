import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// What an Aadhaar QR code says about its holder.
///
/// UIDAI prints two kinds. The old one is plain XML and carries the full
/// number. The Secure QR (every card and e-Aadhaar since 2019) is a signed,
/// gzipped record written as one long decimal number. It carries only the
/// last four digits of the number, inside the reference id.
class AadhaarQrData {
  const AadhaarQrData({
    this.name = '',
    this.dateOfBirth = '',
    this.gender = '',
    this.address = '',
    this.careOf = '',
    this.number = '',
    this.lastFour = '',
  });

  final String name;

  /// `yyyy-MM-dd`, or a bare year when only the year of birth is printed.
  final String dateOfBirth;
  final String gender;
  final String address;
  final String careOf;

  /// The full 12-digit number. Only the old XML QR carries it.
  final String number;

  /// The last four digits of the number. Every format carries these.
  final String lastFour;
}

/// Decodes either QR format, or returns null for anything else.
AadhaarQrData? decodeAadhaarQr(String raw) {
  final String value = raw.trim();
  if (value.isEmpty) return null;
  if (value.contains('<')) return _fromXml(value);
  if (RegExp(r'^\d{200,}$').hasMatch(value)) return _fromSecure(value);
  return null;
}

String _gender(String raw) => switch (raw.trim().toUpperCase()) {
  'M' || 'MALE' => 'Male',
  'F' || 'FEMALE' => 'Female',
  'T' || 'O' || 'TRANSGENDER' || 'OTHER' => 'Other',
  _ => '',
};

/// `dd-MM-yyyy`, `dd/MM/yyyy` or `yyyy-MM-dd` to `yyyy-MM-dd`.
String _date(String raw) {
  final String value = raw.trim();
  final RegExpMatch? dmy = RegExp(
    r'^(\d{2})[-/.](\d{2})[-/.](\d{4})$',
  ).firstMatch(value);
  if (dmy != null) return '${dmy.group(3)}-${dmy.group(2)}-${dmy.group(1)}';
  final RegExpMatch? ymd = RegExp(
    r'^(\d{4})[-/.](\d{2})[-/.](\d{2})$',
  ).firstMatch(value);
  if (ymd != null) return '${ymd.group(1)}-${ymd.group(2)}-${ymd.group(3)}';
  return '';
}

String _joinAddress(List<String> parts) {
  final List<String> out = <String>[];
  for (final String part in parts) {
    final String clean = part.trim();
    if (clean.isEmpty) continue;
    if (out.any((String seen) => seen.toLowerCase() == clean.toLowerCase())) {
      continue;
    }
    out.add(clean);
  }
  return out.join(', ');
}

AadhaarQrData? _fromXml(String xml) {
  final Map<String, String> a = <String, String>{};
  for (final RegExpMatch m in RegExp(
    r'''(\w+)\s*=\s*["']([^"']*)["']''',
  ).allMatches(xml)) {
    a[m.group(1)!.toLowerCase()] = m.group(2)!;
  }
  String at(List<String> keys) {
    for (final String key in keys) {
      final String? value = a[key];
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  final String name = at(<String>['name', 'n']);
  if (name.isEmpty) return null;
  final String uid = at(<String>['uid', 'u']).replaceAll(RegExp(r'\D'), '');
  final String dob = _date(at(<String>['dob', 'd']));
  final String yob = at(<String>['yob', 'y']);
  final String address = a.containsKey('a')
      ? at(<String>['a'])
      : _joinAddress(<String>[
          at(<String>['house']),
          at(<String>['street']),
          at(<String>['lm']),
          at(<String>['loc']),
          at(<String>['vtc']),
          at(<String>['po']),
          at(<String>['subdist']),
          at(<String>['dist']),
          at(<String>['state']),
          at(<String>['pc']),
        ]);
  return AadhaarQrData(
    name: name,
    dateOfBirth: dob.isNotEmpty ? dob : yob,
    gender: _gender(at(<String>['gender', 'g'])),
    address: address,
    careOf: at(<String>['co']),
    number: uid.length == 12 ? uid : '',
    lastFour: uid.length >= 4 ? uid.substring(uid.length - 4) : '',
  );
}

Uint8List _bigEndianBytes(BigInt value) {
  final List<int> bytes = <int>[];
  var rest = value;
  final BigInt mask = BigInt.from(0xff);
  while (rest > BigInt.zero) {
    bytes.add((rest & mask).toInt());
    rest = rest >> 8;
  }
  return Uint8List.fromList(bytes.reversed.toList());
}

/// Fields in order, split on byte 255. Version 2 and later lead with a
/// `V2`-style marker; the original layout starts at the email/mobile flag.
AadhaarQrData? _fromSecure(String digits) {
  final List<int> data;
  try {
    data = gzip.decode(_bigEndianBytes(BigInt.parse(digits)));
  } catch (_) {
    return null;
  }
  final List<String> fields = <String>[];
  var start = 0;
  for (var i = 0; i < data.length && fields.length < 18; i++) {
    if (data[i] == 255) {
      fields.add(utf8.decode(data.sublist(start, i), allowMalformed: true));
      start = i + 1;
    }
  }
  final int o = fields.isNotEmpty && RegExp(r'^V\d+$').hasMatch(fields[0])
      ? 1
      : 0;
  if (fields.length < o + 16) return null;
  String f(int i) => fields[o + i].trim();

  final String reference = f(1).replaceAll(RegExp(r'\D'), '');
  final String name = f(2);
  if (name.isEmpty) return null;
  final String dob = _date(f(3));
  return AadhaarQrData(
    name: name,
    dateOfBirth: dob.isNotEmpty ? dob : f(3),
    gender: _gender(f(4)),
    careOf: f(5),
    address: _joinAddress(<String>[
      f(8), // house
      f(13), // street
      f(7), // landmark
      f(9), // location
      f(15), // village/town/city
      f(11), // post office
      f(14), // sub-district
      f(6), // district
      f(12), // state
      f(10), // pin code
    ]),
    lastFour: reference.length >= 4 ? reference.substring(0, 4) : '',
  );
}
