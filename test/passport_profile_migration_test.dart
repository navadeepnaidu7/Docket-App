import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:docket/features/passport/domain/passport_profile.dart';

/// Long enough to clear the 100-character floor in isBase64ImagePayload.
final String _chipPortrait = '/9j/4AAQSkZJRgABAQAAAQABAAD${'A' * 200}';
const String _capturedPath =
    '/data/user/0/com.example.docket/cache/CAP1234567890.jpg';

Map<String, dynamic> _legacy({required String imagePath}) => <String, dynamic>{
      'id': 'p1',
      'name': 'Test Holder',
      'passportNumber': 'Z3456789',
      'nationality': 'IND',
      'dateOfBirth': '1994-03-12',
      'expiryDate': '2032-09-04',
      'imagePath': imagePath,
      'mrzRaw': '',
      'placeOfBirth': '',
      'issueDate': '',
      'issuingAuthority': '',
      'gender': '',
      'isEPassport': false,
    };

void main() {
  group('v1 records migrate on read', () {
    test('a base64 chip portrait moves to photoBase64', () {
      final PassportProfile p =
          PassportProfile.fromMap(_legacy(imagePath: _chipPortrait));

      expect(p.photoBase64, _chipPortrait);
      expect(p.imagePath, isEmpty);
    });

    test('a captured file path stays in imagePath', () {
      final PassportProfile p =
          PassportProfile.fromMap(_legacy(imagePath: _capturedPath));

      expect(p.imagePath, _capturedPath);
      expect(p.photoBase64, isEmpty);
    });

    test('an empty image is empty in both fields', () {
      final PassportProfile p = PassportProfile.fromMap(_legacy(imagePath: ''));

      expect(p.imagePath, isEmpty);
      expect(p.photoBase64, isEmpty);
    });

    test('migration never drops the original value', () {
      for (final String stored in <String>[_chipPortrait, _capturedPath, 'x']) {
        final PassportProfile p =
            PassportProfile.fromMap(_legacy(imagePath: stored));
        expect(
          p.imagePath.isNotEmpty ? p.imagePath : p.photoBase64,
          stored,
          reason: 'the stored string must survive in one field or the other',
        );
      }
    });

    test('v1 records are flagged as needing a rewrite', () {
      expect(
        PassportProfile.mapNeedsMigration(_legacy(imagePath: _capturedPath)),
        isTrue,
      );
    });
  });

  group('v2 records', () {
    test('round-trip preserves both fields', () {
      final PassportProfile original = PassportProfile(
        id: 'p2',
        name: 'Test Holder',
        passportNumber: 'Z3456789',
        nationality: 'IND',
        dateOfBirth: '1994-03-12',
        expiryDate: '2032-09-04',
        imagePath: _capturedPath,
        mrzRaw: 'LINE1\nLINE2',
        photoBase64: _chipPortrait,
        isEPassport: true,
      );

      final PassportProfile back =
          PassportProfile.fromJson(original.toJson());

      expect(back.imagePath, _capturedPath);
      expect(back.photoBase64, _chipPortrait);
      expect(back.mrzRaw, 'LINE1\nLINE2');
      expect(back.isEPassport, isTrue);
    });

    test('written records carry the version marker and need no rewrite', () {
      final Map<String, dynamic> map =
          jsonDecode(PassportProfile.empty().toJson()) as Map<String, dynamic>;

      expect(map['v'], kPassportSchemaVersion);
      expect(PassportProfile.mapNeedsMigration(map), isFalse);
    });

    test('a v2 record is not re-migrated even if imagePath looks like base64',
        () {
      final Map<String, dynamic> map = _legacy(imagePath: _chipPortrait)
        ..['v'] = 2
        ..['photoBase64'] = '';

      final PassportProfile p = PassportProfile.fromMap(map);

      expect(p.imagePath, _chipPortrait);
      expect(p.photoBase64, isEmpty);
    });
  });
}
