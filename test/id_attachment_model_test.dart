import 'package:docket/features/ids/domain/id_attachment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IdAttachment Model', () {
    test('toMap and fromMap round-trip accurately', () {
      final now = DateTime.now();
      final attachment = IdAttachment(
        id: 'att_123',
        kind: IdAttachmentKind.pdf,
        fileName: 'att_123.enc',
        sizeBytes: 2048,
        addedAt: now,
        source: 'picker',
      );

      final map = attachment.toMap();
      final decoded = IdAttachment.fromMap(map);

      expect(decoded.id, equals('att_123'));
      expect(decoded.kind, equals(IdAttachmentKind.pdf));
      expect(decoded.fileName, equals('att_123.enc'));
      expect(decoded.sizeBytes, equals(2048));
      expect(
        decoded.addedAt.toIso8601String(),
        equals(now.toIso8601String()),
      );
      expect(decoded.source, equals('picker'));
    });

    test('fromMap falls back safely when kind is unknown or missing', () {
      final mapWithUnknownKind = {
        'id': 'att_456',
        'kind': 'video_stream',
        'fileName': 'att_456.enc',
        'sizeBytes': 1024,
        'addedAt': '2026-01-01T00:00:00.000Z',
        'source': 'scan',
      };

      final decoded = IdAttachment.fromMap(mapWithUnknownKind);

      expect(decoded.id, equals('att_456'));
      expect(decoded.kind, equals(IdAttachmentKind.image));
    });

    test('fromMap degrades safely on missing or malformed fields', () {
      final emptyMap = <String, dynamic>{};

      final decoded = IdAttachment.fromMap(emptyMap);

      expect(decoded.id, isNotEmpty);
      expect(decoded.kind, equals(IdAttachmentKind.image));
      expect(decoded.fileName, isEmpty);
      expect(decoded.sizeBytes, equals(0));
      expect(
        decoded.addedAt,
        equals(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
      );
      expect(decoded.source, isEmpty);
    });
  });
}
