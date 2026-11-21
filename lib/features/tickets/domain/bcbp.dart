/// IATA Bar Coded Boarding Pass (Resolution 792) parsing.
///
/// Every airline boarding pass barcode, whatever the symbology (PDF417, Aztec,
/// QR), carries this string. The scanner already decodes it on device, so this
/// gives the flight's identity with no model and no network. Times are not in
/// the standard, so they still come from the document.
///
/// Only the mandatory items are read. The conditional section varies by
/// version and carrier, and nothing on the pass face needs it.
///
/// Layout of the first leg (0-based offsets):
///
/// ```
/// 0      format code 'M'
/// 1      number of legs encoded, '1'-'4'
/// 2-21   passenger name, SURNAME/GIVEN, space padded
/// 22     electronic ticket indicator, 'E'
/// 23-29  operating carrier PNR
/// 30-32  from airport          33-35  to airport
/// 36-38  operating carrier     39-43  flight number
/// 44-46  date of flight, day of year
/// 47     compartment code      48-51  seat
/// 52-56  check-in sequence     57     passenger status
/// 58-59  size of the leg's conditional section, hex
/// ```
///
/// Each further leg repeats offsets 23-59 (37 characters), starting after the
/// previous leg's conditional section.
library;

import 'package:flutter/foundation.dart';

@immutable
class BcbpLeg {
  const BcbpLeg({
    required this.pnr,
    required this.from,
    required this.to,
    required this.carrier,
    required this.flightNumber,
    required this.dayOfYear,
    required this.compartment,
    required this.seat,
    required this.sequence,
  });

  final String pnr;
  final String from;
  final String to;

  /// Operating carrier designator, "6E".
  final String carrier;

  /// Number without padding or leading zeros, "2134" or "123A".
  final String flightNumber;

  /// Day of the year the flight leaves, 1-366. Null when the field is blank,
  /// which some carriers do on passes issued before the date is fixed.
  final int? dayOfYear;

  /// Raw compartment code, "Y". See [cabin].
  final String compartment;

  /// "12A", leading zeros removed. Empty when unassigned.
  final String seat;

  /// Check-in sequence, "42". Empty when blank.
  final String sequence;

  /// "6E 2134", the way the pass face prints it.
  String get displayFlightNumber => '$carrier $flightNumber';

  /// Cabin name for the compartment code. The code is carrier-defined, so this
  /// covers the near-universal letters and returns empty otherwise rather than
  /// guessing.
  String get cabin => switch (compartment) {
    'F' || 'A' => 'First',
    'J' || 'C' || 'D' || 'I' || 'Z' => 'Business',
    'W' || 'P' => 'Premium Economy',
    'Y' ||
    'B' ||
    'H' ||
    'K' ||
    'M' ||
    'L' ||
    'Q' ||
    'T' ||
    'V' ||
    'X' ||
    'S' ||
    'N' ||
    'O' ||
    'G' ||
    'E' ||
    'R' ||
    'U' => 'Economy',
    _ => '',
  };

  /// The calendar date of the flight, nearest to [reference].
  ///
  /// The standard carries a day of year and no year, so the year is the one
  /// that puts the flight closest to when the pass is being read. A pass for
  /// 2 Jan scanned on 30 Dec is next year's.
  DateTime? dateNear(DateTime reference) {
    final int? doy = dayOfYear;
    if (doy == null) return null;
    DateTime? best;
    int? bestGap;
    for (final int year in <int>[
      reference.year - 1,
      reference.year,
      reference.year + 1,
    ]) {
      final bool leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
      if (doy > (leap ? 366 : 365)) continue;
      final DateTime d = DateTime(year).add(Duration(days: doy - 1));
      final int gap = d
          .difference(DateTime(reference.year, reference.month, reference.day))
          .inDays
          .abs();
      if (bestGap == null || gap < bestGap) {
        best = d;
        bestGap = gap;
      }
    }
    return best;
  }
}

@immutable
class BcbpPass {
  const BcbpPass({
    required this.passengerName,
    required this.electronicTicket,
    required this.legs,
  });

  /// As encoded, "NAGELLA/NAVADEEP". See [displayName].
  final String passengerName;
  final bool electronicTicket;

  /// At least one.
  final List<BcbpLeg> legs;

  /// "Navadeep Nagella": given names first, title dropped, title-cased.
  String get displayName {
    final List<String> parts = passengerName.split('/');
    final String surname = parts.first.trim();
    String given = parts.length > 1 ? parts.sublist(1).join(' ').trim() : '';
    given = given.replaceFirst(
      RegExp(r'\s+(MR|MRS|MS|MISS|MSTR|DR|PROF|CHD|INF)$'),
      '',
    );
    return <String>[
      given,
      surname,
    ].where((String s) => s.isNotEmpty).map(_titleCase).join(' ');
  }
}

/// Parses [raw] as a BCBP string, or returns null when it is not one.
///
/// Strict on purpose: this feeds ground truth to the extractor, so a string
/// that merely starts with "M1" but has the wrong shape must come back null
/// rather than half-parsed.
BcbpPass? parseBcbp(String raw) {
  // Scanners hand back the symbol's text verbatim; only a trailing newline is
  // ever added. Interior spaces are significant padding.
  final String s = raw.replaceAll(RegExp(r'[\r\n]+$'), '');
  if (s.length < 60 || s[0] != 'M') return null;
  final int? legCount = int.tryParse(s[1]);
  if (legCount == null || legCount < 1 || legCount > 4) return null;

  final String name = s.substring(2, 22).trim();
  if (name.isEmpty) return null;

  final List<BcbpLeg> legs = <BcbpLeg>[];
  int at = 23;
  for (int i = 0; i < legCount; i++) {
    if (s.length < at + 37) return null;
    final BcbpLeg? leg = _leg(s.substring(at, at + 35));
    final int? conditional = int.tryParse(
      s.substring(at + 35, at + 37),
      radix: 16,
    );
    if (leg == null || conditional == null) return null;
    legs.add(leg);
    // A last leg whose conditional section runs short is tolerated (carriers
    // miscount the security block); an earlier one fails the length check at
    // the top of the next pass, since the next leg cannot be found.
    at += 37 + conditional;
  }

  return BcbpPass(
    passengerName: name,
    electronicTicket: s[22] == 'E',
    legs: List<BcbpLeg>.unmodifiable(legs),
  );
}

final RegExp _airport = RegExp(r'^[A-Z]{3}$');
final RegExp _carrier = RegExp(r'^[A-Z0-9]{2,3}$');
final RegExp _flight = RegExp(r'^\d{1,4}[A-Z]?$');

/// 35 characters: PNR through passenger status.
BcbpLeg? _leg(String f) {
  final String pnr = f.substring(0, 7).trim();
  final String from = f.substring(7, 10);
  final String to = f.substring(10, 13);
  final String carrier = f.substring(13, 16).trim();
  final String flightRaw = f.substring(16, 21).trim();
  final String doyRaw = f.substring(21, 24).trim();
  final String compartment = f.substring(24, 25).trim();
  final String seatRaw = f.substring(25, 29).trim();
  final String seqRaw = f.substring(29, 34).trim();

  if (pnr.isEmpty || !_airport.hasMatch(from) || !_airport.hasMatch(to)) {
    return null;
  }
  if (!_carrier.hasMatch(carrier) || !_flight.hasMatch(flightRaw)) return null;

  final int? doy = doyRaw.isEmpty ? null : int.tryParse(doyRaw);
  if (doyRaw.isNotEmpty && (doy == null || doy < 1 || doy > 366)) return null;

  return BcbpLeg(
    pnr: pnr,
    from: from,
    to: to,
    carrier: carrier,
    flightNumber: _stripZeros(flightRaw),
    dayOfYear: doy,
    compartment: compartment,
    seat: _stripZeros(seatRaw),
    sequence: _stripZeros(seqRaw),
  );
}

/// "0123A" -> "123A", "0042" -> "42", "0000" -> "".
String _stripZeros(String v) => v.replaceFirst(RegExp(r'^0+'), '');

String _titleCase(String word) => word
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((String w) => w.isNotEmpty)
    .map((String w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');
