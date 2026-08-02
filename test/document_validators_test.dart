import 'package:flutter_test/flutter_test.dart';

import 'package:docket/core/validation/document_validators.dart';

String _isoDaysFromNow(int days) {
  final DateTime d = DateTime.now().add(Duration(days: days));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

void main() {
  group('required flag', () {
    test('empty stays valid when optional (existing ID-flow behaviour)', () {
      expect(DocumentValidators.validateDateOfBirth(''), isNull);
      expect(DocumentValidators.validateExpiryDate(''), isNull);
      expect(
        DocumentValidators.validatePassportDates(
          dateOfBirth: '',
          expiryDate: '',
        ),
        isNull,
      );
    });

    test('empty is rejected when required', () {
      expect(
        DocumentValidators.validateDateOfBirth('', required: true),
        isNotNull,
      );
      expect(
        DocumentValidators.validateExpiryDate('', required: true),
        isNotNull,
      );
      expect(
        DocumentValidators.validatePassportDates(
          dateOfBirth: '',
          expiryDate: '',
          required: true,
        ),
        isNotNull,
      );
    });
  });

  group('validatePassportNumber', () {
    test('accepts 6-9 alphanumerics and normalises first', () {
      expect(DocumentValidators.validatePassportNumber('Z3456789'), isNull);
      expect(DocumentValidators.validatePassportNumber('z3 456 789'), isNull);
      expect(DocumentValidators.validatePassportNumber('ABC123'), isNull);
    });

    test('rejects wrong length and punctuation', () {
      expect(DocumentValidators.validatePassportNumber('AB12'), isNotNull);
      expect(DocumentValidators.validatePassportNumber('ABCDEFGHIJ'), isNotNull);
      expect(DocumentValidators.validatePassportNumber('Z34-56789'), isNotNull);
    });

    test('empty depends on required', () {
      expect(DocumentValidators.validatePassportNumber(''), isNull);
      expect(
        DocumentValidators.validatePassportNumber('', required: true),
        isNotNull,
      );
    });

    test('normalisePassportNumber upper-cases and strips whitespace', () {
      expect(
        DocumentValidators.normalisePassportNumber('  z3 456 789 '),
        'Z3456789',
      );
    });
  });

  group('validateBacTriple', () {
    test('all three empty yields one error per field', () {
      final Map<String, String> errors = DocumentValidators.validateBacTriple(
        passportNumber: '',
        dateOfBirth: '',
        expiryDate: '',
      );
      expect(errors.keys, containsAll(<String>[
        'passportNumber',
        'dateOfBirth',
        'expiryDate',
      ]));
    });

    test('a complete valid triple passes', () {
      expect(
        DocumentValidators.validateBacTriple(
          passportNumber: 'Z3456789',
          dateOfBirth: '1994-03-12',
          expiryDate: _isoDaysFromNow(400),
        ),
        isEmpty,
      );
    });

    test('errors are per-field, not collapsed to the first', () {
      final Map<String, String> errors = DocumentValidators.validateBacTriple(
        passportNumber: 'nope!',
        dateOfBirth: '',
        expiryDate: _isoDaysFromNow(400),
      );
      expect(errors.containsKey('passportNumber'), isTrue);
      expect(errors.containsKey('dateOfBirth'), isTrue);
      expect(errors.containsKey('expiryDate'), isFalse);
    });

    test('an expired passport is rejected before the chip is touched', () {
      final Map<String, String> errors = DocumentValidators.validateBacTriple(
        passportNumber: 'Z3456789',
        dateOfBirth: '1994-03-12',
        expiryDate: _isoDaysFromNow(-1),
      );
      expect(errors.containsKey('expiryDate'), isTrue);
    });
  });
}
