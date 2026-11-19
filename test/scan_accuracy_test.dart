import 'dart:convert';
import 'dart:io';

import 'package:docket/core/scanning/field_votes.dart';
import 'package:docket/core/scanning/ocr_fixes.dart';
import 'package:docket/features/cards/domain/card_number.dart';
import 'package:docket/features/cards/domain/card_scan_text.dart';
import 'package:docket/features/ids/domain/aadhaar_qr.dart';
import 'package:docket/features/ids/domain/id_document.dart';
import 'package:docket/features/ids/domain/id_scan_text.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _now = DateTime(2026, 11, 19);

String _withVerhoeff(String eleven) {
  for (var d = 0; d < 10; d++) {
    if (verhoeffValid('$eleven$d')) return '$eleven$d';
  }
  throw StateError('no check digit');
}

String _spaced(String twelve) => formatAadhaar(twelve);

String _secureQr(List<String> fields) {
  final List<int> body = <int>[];
  for (final String field in fields) {
    body.addAll(utf8.encode(field));
    body.add(255);
  }
  body.addAll(List<int>.filled(256, 7)); // stands in for photo + signature
  final List<int> packed = gzip.encode(body);
  var value = BigInt.zero;
  for (final int byte in packed) {
    value = (value << 8) | BigInt.from(byte);
  }
  return value.toString();
}

void main() {
  group('OCR digit fixes', () {
    test('rewrite confusables only inside number-shaped words', () {
      expect(fixDigitWords('4l11 1111 IIII'), '4111 1111 IIII');
      expect(fixDigitWords('VALID THRU O9/28'), 'VALID THRU 09/28');
      expect(fixDigitWords('SOBHA S/O RAO'), 'SOBHA S/O RAO');
    });

    test('votes settle only with weight and a clear majority', () {
      final FieldVotes votes = FieldVotes();
      votes.add('a');
      votes.add('a');
      expect(votes.settled(), isFalse);
      votes.add('a');
      expect(votes.settled(), isTrue);
      votes.add('b');
      votes.add('c');
      votes.add('d');
      expect(votes.settled(), isFalse);
    });
  });

  group('payment cards', () {
    test('joins embossed groups that OCR split across lines', () {
      final CardScanFields fields = parseCardOcr(
        'HDFC BANK\n4111 1111\n1111 1111\nNAVA DEEP',
        now: _now,
      );
      expect(fields.number, '4111111111111111');
      expect(fields.holderName, 'NAVA DEEP');
    });

    test('repairs letters read inside the number', () {
      final CardScanFields fields = parseCardOcr(
        '4111 l111 1111 11I1\nVALID THRU O9/28',
        now: _now,
      );
      expect(fields.number, '4111111111111111');
      expect(fields.expiryMonth, 9);
      expect(fields.expiryYear, 2028);
    });

    test('picks the expiry over a valid-from date', () {
      final CardScanFields labeled = parseCardOcr(
        '4111 1111 1111 1111\nVALID FROM 03/30 VALID THRU 01/24',
        now: _now,
      );
      expect(labeled.expiryMonth, 1);
      expect(labeled.expiryYear, 2024);

      final CardScanFields unlabeled = parseCardOcr(
        '4111 1111 1111 1111\n03/22 08/29',
        now: _now,
      );
      expect(unlabeled.expiryMonth, 8);
      expect(unlabeled.expiryYear, 2029);
    });

    test('prefers a capitalised holder name over a tagline', () {
      final CardScanFields fields = parseCardOcr(
        'Rewards Made Simple\n4111 1111 1111 1111\nASHA RAO',
        now: _now,
      );
      expect(fields.holderName, 'ASHA RAO');
    });

    test('consensus ignores a misread number however often it repeats', () {
      final CardScanConsensus votes = CardScanConsensus();
      const CardScanFields misread = CardScanFields(
        number: '4111111111111112',
      );
      for (var i = 0; i < 6; i++) {
        votes.add(misread);
      }
      expect(votes.fields.number, isEmpty);
      expect(votes.frontReady, isFalse);

      for (var i = 0; i < 3; i++) {
        votes.add(
          const CardScanFields(
            number: '4111111111111111',
            expiryMonth: 9,
            expiryYear: 2028,
          ),
        );
      }
      expect(luhnValid(votes.fields.number), isTrue);
      expect(votes.fields.expiryMonth, 9);
      expect(votes.frontReady, isTrue);
    });

    test('a still fills what the frames never agreed on', () {
      final CardScanFields merged = preferCardFields(
        const CardScanFields(number: '4111111111111111'),
        const CardScanFields(
          number: '4111111111111112',
          holderName: 'ASHA RAO',
          cvv: '123',
        ),
      );
      expect(merged.number, '4111111111111111');
      expect(merged.holderName, 'ASHA RAO');
      expect(merged.cvv, '123');
    });
  });

  group('Aadhaar', () {
    final String number = _withVerhoeff('23456789012');

    test('Verhoeff catches a single misread digit', () {
      expect(aadhaarNumberValid(number), isTrue);
      final String misread =
          '${number.substring(0, 5)}${(int.parse(number[5]) + 1) % 10}${number.substring(6)}';
      expect(aadhaarNumberValid(misread), isFalse);
      expect(aadhaarNumberValid('0${number.substring(1)}'), isFalse);
    });

    test('front: name above the birth line, in title case', () {
      final IdScanResult r = parseAadhaarText(
        'भारत सरकार\nGovernment of India\nआशा राव\nAsha Rao\n'
        'जन्म तिथि / DOB: 14/02/1991\nमहिला / FEMALE\n${_spaced(number)}\n'
        'VID : 9134 5678 1234 5678\nMera Aadhaar, Meri Pehchaan',
        now: _now,
      );
      expect(r.holderName, 'Asha Rao');
      expect(r.dateOfBirth, '1991-02-14');
      expect(r.gender, 'Female');
      expect(r.documentNumber, _spaced(number));
    });

    test('e-Aadhaar: skips the issue and download dates', () {
      final IdScanResult r = parseAadhaarText(
        'Issue Date: 01/05/2019\nDownload Date: 03/03/2024\n'
        'RAVI KUMAR\nDOB: 07/08/1985\nMALE\n${_spaced(number)}',
        now: _now,
      );
      expect(r.dateOfBirth, '1985-08-07');
      expect(r.holderName, 'Ravi Kumar');
      expect(r.gender, 'Male');
    });

    test('back: the address runs to the PIN code', () {
      final IdScanResult r = parseAadhaarText(
        'पता: एस/ओ रमेश\nAddress: S/O Ramesh Kumar, 12 MG Road,\n'
        'Indiranagar, Bengaluru,\nKarnataka - 560038\n${_spaced(number)}',
        now: _now,
      );
      expect(
        r.address,
        'S/O Ramesh Kumar, 12 MG Road, Indiranagar, Bengaluru, Karnataka - 560038',
      );
      expect(r.documentNumber, _spaced(number));
    });

    test('decodes a Secure QR', () {
      final String qr = _secureQr(<String>[
        'V2',
        '3',
        '${number.substring(8)}20190501123456789',
        'Asha Rao',
        '14-02-1991',
        'F',
        'S/O Ramesh Kumar',
        'Bengaluru',
        'Near Park',
        '12',
        'Indiranagar',
        '560038',
        'Indiranagar',
        'Karnataka',
        'MG Road',
        'Bengaluru East',
        'Bengaluru',
        '1234',
      ]);
      final AadhaarQrData? data = decodeAadhaarQr(qr);
      expect(data, isNotNull);
      expect(data!.name, 'Asha Rao');
      expect(data.dateOfBirth, '1991-02-14');
      expect(data.gender, 'Female');
      expect(data.lastFour, number.substring(8));
      expect(data.address, contains('560038'));
      expect(data.address, startsWith('12, MG Road, Near Park'));
    });

    test('decodes the old XML QR, full number included', () {
      final AadhaarQrData? data = decodeAadhaarQr(
        '<?xml version="1.0" encoding="UTF-8"?><PrintLetterBarcodeData '
        'uid="$number" name="Ravi Kumar" gender="M" yob="1985" '
        'co="S/O Mohan" house="4" street="Lake Rd" vtc="Pune" '
        'dist="Pune" state="Maharashtra" pc="411001"/>',
      );
      expect(data!.number, number);
      expect(data.dateOfBirth, '1985');
      expect(data.gender, 'Male');
      expect(data.address, '4, Lake Rd, Pune, Maharashtra, 411001');
    });

    test('the QR overrides OCR and vetoes a number with the wrong ending', () {
      final IdScanResult ocr = IdScanResult(
        type: IdDocumentType.aadhaar,
        holderName: 'Asha Ra0',
        documentNumber: _spaced(_withVerhoeff('34567890123')),
      );
      final IdScanResult r = applyAadhaarQr(
        ocr,
        AadhaarQrData(name: 'ASHA RAO', lastFour: number.substring(8)),
      );
      expect(r.holderName, 'Asha Rao');
      expect(r.documentNumber, isEmpty);
    });

    test('consensus counts only checksum-valid numbers', () {
      final IdScanConsensus votes = IdScanConsensus(IdDocumentType.aadhaar);
      for (var i = 0; i < 5; i++) {
        votes.add(
          const IdScanResult(
            type: IdDocumentType.aadhaar,
            documentNumber: '2345 6789 0120',
          ),
        );
      }
      expect(votes.ready, aadhaarNumberValid('234567890120'));
      votes.clear();
      for (var i = 0; i < 3; i++) {
        votes.add(
          IdScanResult(
            type: IdDocumentType.aadhaar,
            documentNumber: _spaced(number),
            holderName: 'Asha Rao',
          ),
        );
      }
      expect(votes.ready, isTrue);
      expect(votes.result.holderName, 'Asha Rao');
    });
  });

  group('PAN', () {
    test('new layout: bilingual labels', () {
      final IdScanResult r = parsePanText(
        'आयकर विभाग\nINCOME TAX DEPARTMENT\nभारत सरकार\nGOVT. OF INDIA\n'
        'स्थायी लेखा संख्या कार्ड\nPermanent Account Number Card\nABCPE1234F\n'
        'नाम / Name\nASHA RAO\nपिता का नाम / Father\'s Name\nRAMESH KUMAR\n'
        'जन्म की तारीख / Date of Birth\n14/02/1991',
        now: _now,
      );
      expect(r.documentNumber, 'ABCPE1234F');
      expect(r.holderName, 'Asha Rao');
      expect(r.fatherName, 'Ramesh Kumar');
      expect(r.dateOfBirth, '1991-02-14');
    });

    test('old layout: holder, father, date, in order', () {
      final IdScanResult r = parsePanText(
        'INCOME TAX DEPARTMENT GOVT. OF INDIA\nASHA RAO\nRAMESH KUMAR\n'
        '14/02/1991\nPermanent Account Number\nABCPE1234F\nSignature',
        now: _now,
      );
      expect(r.holderName, 'Asha Rao');
      expect(r.fatherName, 'Ramesh Kumar');
      expect(r.documentNumber, 'ABCPE1234F');
    });

    test('coerces each position to the class it must be', () {
      final IdScanResult r = parsePanText('A8CPE1Z34F', now: _now);
      expect(r.documentNumber, 'ABCPE1234F');
      expect(panNumberValid('ABCXE1234F'), isFalse);
    });
  });
}
