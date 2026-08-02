import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:docket/core/storage/image_payload.dart';

void main() {
  // Base64 of the JPEG magic bytes FF D8 FF is "/9j/", so an encoded photo
  // always starts with a slash. The rule this replaced rejected anything
  // starting with '/', which misfiled every JPEG portrait as a file path.
  test('a base64 JPEG is recognised despite its leading slash', () {
    final String jpeg = base64Encode(<int>[
      0xFF, 0xD8, 0xFF, 0xE0,
      ...List<int>.filled(300, 0x41),
    ]);

    expect(jpeg.startsWith('/9j/'), isTrue);
    expect(isBase64ImagePayload(jpeg), isTrue);
  });

  test('a base64 PNG is recognised', () {
    final String png = base64Encode(<int>[
      0x89, 0x50, 0x4E, 0x47,
      ...List<int>.filled(300, 0x42),
    ]);

    expect(isBase64ImagePayload(png), isTrue);
  });

  test('padded base64 is recognised', () {
    final String padded = '${'A' * 200}==';
    expect(isBase64ImagePayload(padded), isTrue);
  });

  group('paths are never treated as base64', () {
    test('a long android cache path', () {
      final String p =
          '/data/user/0/com.example.docket/cache/CAP${'9' * 80}.jpg';
      expect(p.length > 100, isTrue);
      expect(isBase64ImagePayload(p), isFalse);
    });

    test('a long windows path', () {
      final String p = '${r'C:\Users\someone\AppData\Local\Temp\cap'}'
          '${'x' * 90}.png';
      expect(isBase64ImagePayload(p), isFalse);
    });

    test('a short path', () {
      expect(isBase64ImagePayload('/tmp/a.jpg'), isFalse);
    });
  });

  test('empty and short values are not base64', () {
    expect(isBase64ImagePayload(''), isFalse);
    expect(isBase64ImagePayload('AAAA'), isFalse);
  });
}
