import 'package:flutter_test/flutter_test.dart';

import 'package:docket/features/nfc/application/bac_key_format.dart';

void main() {
  group('toBacDate', () {
    test('converts the stored ISO form', () {
      expect(BacKeyFormat.toBacDate('1994-03-12'), '940312');
      expect(BacKeyFormat.toBacDate('2032-09-04'), '320904');
    });

    test('accepts the compact and slash forms', () {
      expect(BacKeyFormat.toBacDate('19940312'), '940312');
      expect(BacKeyFormat.toBacDate('1994/03/12'), '940312');
    });

    test('pads single-digit month and day', () {
      expect(BacKeyFormat.toBacDate('2001-01-05'), '010105');
    });

    test('years 2000-2009 keep their leading zero', () {
      expect(BacKeyFormat.toBacDate('2005-11-30'), '051130');
    });

    // The old inline conversion did `parts[0].substring(2)` after splitting on
    // '-', so anything that was not exactly three hyphen-separated parts was
    // passed through to the chip unchanged and failed opaquely.
    test('returns null rather than passing junk through to the chip', () {
      expect(BacKeyFormat.toBacDate(''), isNull);
      expect(BacKeyFormat.toBacDate('not a date'), isNull);
      expect(BacKeyFormat.toBacDate('1990'), isNull);
      expect(BacKeyFormat.toBacDate('12/03/1990'), isNull);
    });
  });

  group('document number', () {
    test('normalises case and whitespace', () {
      expect(BacKeyFormat.toBacDocumentNumber(' z3 456 789 '), 'Z3456789');
    });

    test('pads short numbers to nine with <', () {
      expect(BacKeyFormat.padDocumentNumber('ABC123'), 'ABC123<<<');
      expect(BacKeyFormat.padDocumentNumber('Z3456789'), 'Z3456789<');
    });

    test('leaves nine-character numbers alone', () {
      expect(BacKeyFormat.padDocumentNumber('Z34567890'), 'Z34567890');
    });
  });
}
