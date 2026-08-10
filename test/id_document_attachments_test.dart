import 'package:docket/features/ids/domain/id_attachment.dart';
import 'package:docket/features/ids/domain/id_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IdDocument Attachments Back-Compat & Serialization', () {
    test('a record map written WITHOUT the attachments key decodes to an empty list', () {
      final legacyMap = <String, dynamic>{
        'id': 'doc_legacy_1',
        'type': 'pan',
        'holderName': 'Jane Doe',
        'documentNumber': 'ABCDE1234F',
        'dateOfBirth': '1990-01-01',
        'fatherName': 'John Doe',
      };

      final doc = IdDocument.fromMap(legacyMap);

      expect(doc.id, equals('doc_legacy_1'));
      expect(doc.attachments, isEmpty);
      expect(doc.attachments, isA<List<IdAttachment>>());
    });

    test('a record WITH attachments round-trips cleanly', () {
      final attachment = IdAttachment(
        id: 'att_789',
        kind: IdAttachmentKind.image,
        fileName: 'att_789.enc',
        sizeBytes: 4096,
        source: 'picker',
      );

      final doc = IdDocument(
        id: 'doc_1',
        type: IdDocumentType.aadhaar,
        holderName: 'John Smith',
        documentNumber: '123456789012',
        attachments: [attachment],
      );

      final map = doc.toMap();
      final jsonStr = doc.toJson();
      final decodedFromMap = IdDocument.fromMap(map);
      final decodedFromJson = IdDocument.fromJson(jsonStr);

      expect(decodedFromMap.attachments.length, equals(1));
      expect(decodedFromMap.attachments.first.id, equals('att_789'));
      expect(decodedFromMap.attachments.first.kind, equals(IdAttachmentKind.image));

      expect(decodedFromJson.attachments.length, equals(1));
      expect(decodedFromJson.attachments.first.fileName, equals('att_789.enc'));
    });

    test('a malformed non-list attachments value degrades to empty without throwing', () {
      final malformedMapString = <String, dynamic>{
        'id': 'doc_bad_1',
        'type': 'pan',
        'holderName': 'Alice',
        'documentNumber': 'XYZ123456',
        'attachments': 'not_a_list',
      };

      final malformedMapInt = <String, dynamic>{
        'id': 'doc_bad_2',
        'type': 'pan',
        'holderName': 'Bob',
        'documentNumber': 'XYZ654321',
        'attachments': 12345,
      };

      final malformedMapObject = <String, dynamic>{
        'id': 'doc_bad_3',
        'type': 'pan',
        'holderName': 'Charlie',
        'documentNumber': 'XYZ999999',
        'attachments': {'invalid': 'structure'},
      };

      expect(() => IdDocument.fromMap(malformedMapString), returnsNormally);
      expect(() => IdDocument.fromMap(malformedMapInt), returnsNormally);
      expect(() => IdDocument.fromMap(malformedMapObject), returnsNormally);

      expect(IdDocument.fromMap(malformedMapString).attachments, isEmpty);
      expect(IdDocument.fromMap(malformedMapInt).attachments, isEmpty);
      expect(IdDocument.fromMap(malformedMapObject).attachments, isEmpty);
    });
  });
}
