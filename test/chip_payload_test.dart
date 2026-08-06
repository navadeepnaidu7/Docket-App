import 'package:flutter_test/flutter_test.dart';

import 'package:docket/features/nfc/application/chip_payload.dart';
import 'package:docket/features/passport/presentation/flow/passport_prompt_flow.dart';

void main() {
  group('ChipPayload.toFlowValues', () {
    test('maps DG1 identity fields and converts MRZ dates', () {
      final Map<String, String> values = ChipPayload.toFlowValues(
        <String, dynamic>{
          'firstName': 'RAHUL KUMAR',
          'lastName': 'SHARMA',
          'documentNumber': 'Z3456789',
          'nationality': 'ind',
          'gender': 'MALE',
          'dateOfBirth': '940312',
          'dateOfExpiry': '320904',
        },
      );

      expect(values[PassportField.name], 'RAHUL KUMAR SHARMA');
      expect(values[PassportField.passportNumber], 'Z3456789');
      expect(values[PassportField.nationality], 'IND');
      expect(values[PassportField.gender], 'M');
      expect(values[PassportField.dateOfBirth], '1994-03-12');
      expect(values[PassportField.expiryDate], '2032-09-04');
    });

    test('prefers DG11 full name and maps photo, place of birth, DG12', () {
      final Map<String, String> values = ChipPayload.toFlowValues(
        <String, dynamic>{
          'firstName': 'RAHUL',
          'lastName': 'SHARMA',
          'dg11_fullName': 'SHARMA<<RAHUL<KUMAR',
          'documentNumber': 'Z3456789',
          'photoBase64': '/9j/4AAQ',
          'dg11_placeOfBirth': 'HYDERABAD, TELANGANA',
          'dg12_dateOfIssue': '20220904',
          'dg12_issuingAuthority': 'HYDERABAD',
        },
      );

      expect(values[PassportField.name], 'SHARMA RAHUL KUMAR');
      expect(values['photoBase64'], '/9j/4AAQ');
      expect(values['placeOfBirth'], 'HYDERABAD, TELANGANA');
      expect(values['issueDate'], '2022-09-04');
      expect(values['issuingAuthority'], 'HYDERABAD');
    });

    test('joins a list-shaped place of birth', () {
      final Map<String, String> values = ChipPayload.toFlowValues(
        <String, dynamic>{
          'dg11_placeOfBirth': <String>['HYDERABAD', 'TELANGANA'],
        },
      );

      expect(values['placeOfBirth'], 'HYDERABAD, TELANGANA');
    });

    test('omits empty fields so typed values are not wiped', () {
      final Map<String, String> values = ChipPayload.toFlowValues(
        <String, dynamic>{
          'firstName': '',
          'lastName': '',
          'documentNumber': null,
          'photoBase64': null,
          'gender': 'UNKNOWN',
        },
      );

      expect(values.containsKey(PassportField.name), isFalse);
      expect(values.containsKey(PassportField.passportNumber), isFalse);
      expect(values.containsKey('photoBase64'), isFalse);
      expect(values[PassportField.gender], 'X');
    });

    test('strips MRZ filler from the document number', () {
      final Map<String, String> values = ChipPayload.toFlowValues(
        <String, dynamic>{'documentNumber': 'ABC123<<<'},
      );

      expect(values[PassportField.passportNumber], 'ABC123');
    });
  });
}
