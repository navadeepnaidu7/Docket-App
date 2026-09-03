import 'dart:convert';
import 'dart:typed_data';

import 'package:docket/features/tickets/application/ticket_code_scanner.dart';
import 'package:docket/features/tickets/domain/pass_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

Uint8List _bytes(List<int> v) => Uint8List.fromList(v);

TicketCodeCandidate _c({
  PassCodeFormat format = PassCodeFormat.qr,
  double area = 100,
  String? text,
  Uint8List? bytes,
}) =>
    TicketCodeCandidate(format: format, area: area, text: text, bytes: bytes);

void main() {
  group('PassCodeFormat.fromWire', () {
    test('parses every wire value it emits', () {
      for (final PassCodeFormat f in PassCodeFormat.values) {
        expect(PassCodeFormat.fromWire(f.wire), f);
      }
    });

    test('is case and whitespace insensitive', () {
      expect(PassCodeFormat.fromWire('  CODE128 '), PassCodeFormat.code128);
      expect(PassCodeFormat.fromWire('Pdf417'), PassCodeFormat.pdf417);
    });

    // Absent means QR because that is what the client assumed for train and bus
    // passes before any of these fields existed. An unknown value falls the
    // same way rather than dropping the code.
    test('absent, blank and unknown all mean qr', () {
      expect(PassCodeFormat.fromWire(null), PassCodeFormat.qr);
      expect(PassCodeFormat.fromWire('   '), PassCodeFormat.qr);
      expect(PassCodeFormat.fromWire('maxicode'), PassCodeFormat.qr);
    });
  });

  group('PassCode.parse', () {
    test('a text payload gives a code in its own format', () {
      final PassCode? c =
          PassCode.parse(payload: 'BMS-99213', format: 'code128');
      expect(c, isNotNull);
      expect(c!.text, 'BMS-99213');
      expect(c.format, PassCodeFormat.code128);
      expect(c.isBinary, isFalse);
    });

    test('trims, and treats a blank payload as no code at all', () {
      expect(PassCode.parse(payload: '  A1  ')!.text, 'A1');
      expect(PassCode.parse(payload: '   '), isNull);
      expect(PassCode.parse(payload: ''), isNull);
      expect(PassCode.parse(), isNull);
    });

    test('falls back to base64 bytes for a matrix symbol', () {
      final PassCode? c = PassCode.parse(
        payloadBase64: base64.encode(<int>[0x00, 0xFF, 0x10]),
        format: 'qr',
      );
      expect(c, isNotNull);
      expect(c!.isBinary, isTrue);
      expect(c.bytes, _bytes(<int>[0x00, 0xFF, 0x10]));
      expect(c.text, isNull);
    });

    // A Code 128 encodes characters. Bytes that are not text cannot be
    // reproduced as one, so claiming a code there would produce a symbol that
    // does not match the ticket.
    test('refuses bytes-only payloads on a linear symbology', () {
      expect(
        PassCode.parse(
          payloadBase64: base64.encode(<int>[1, 2, 3]),
          format: 'code128',
        ),
        isNull,
      );
    });

    test('prefers text when both are present', () {
      final PassCode? c = PassCode.parse(
        payload: 'READABLE',
        payloadBase64: base64.encode(<int>[1, 2, 3]),
        format: 'qr',
      );
      expect(c!.text, 'READABLE');
      expect(c.bytes, isNull);
    });

    test('malformed or empty base64 is no code, not a crash', () {
      expect(PassCode.parse(payloadBase64: 'not base64!!', format: 'qr'),
          isNull);
      expect(PassCode.parse(payloadBase64: '', format: 'qr'), isNull);
    });
  });

  group('selectTicketCode', () {
    test('finds nothing in an empty or unusable set', () {
      expect(selectTicketCode(<TicketCodeCandidate>[]), isNull);
      expect(
        selectTicketCode(<TicketCodeCandidate>[_c(text: '   ')]),
        isNull,
      );
    });

    // The code a gate scans is the one printed big. A store badge or an
    // operator's logo code is small and in a corner.
    test('prefers the largest symbol', () {
      final ScannedTicketCode? picked = selectTicketCode(<TicketCodeCandidate>[
        _c(text: 'SMALL', area: 900),
        _c(text: 'BIGGEST', area: 40000),
        _c(text: 'MIDDLE', area: 12000),
      ]);
      expect(picked!.payload, 'BIGGEST');
    });

    // Dropped before the size rule runs, so a large marketing QR cannot win on
    // area alone. Presenting an app-store link at a turnstile is worse than
    // presenting nothing.
    test('drops marketing and app-install payloads even when they are biggest',
        () {
      for (final String junk in <String>[
        'https://play.google.com/store/apps/details?id=com.bms',
        'https://apps.apple.com/in/app/bookmyshow/id1234',
        'https://www.instagram.com/pvrcinemas',
        'https://wa.me/919000000000',
        'upi://pay?pa=cinema@ybl&am=450',
      ]) {
        final ScannedTicketCode? picked =
            selectTicketCode(<TicketCodeCandidate>[
          _c(text: junk, area: 90000),
          _c(text: 'GATE-CODE', area: 100),
        ]);
        expect(picked!.payload, 'GATE-CODE', reason: junk);
      }
    });

    test('returns null when every candidate is junk', () {
      expect(
        selectTicketCode(<TicketCodeCandidate>[
          _c(text: 'https://youtu.be/abcd', area: 5000),
        ]),
        isNull,
      );
    });

    test('a bytes-only linear candidate is skipped, a matrix one is kept', () {
      expect(
        selectTicketCode(<TicketCodeCandidate>[
          _c(format: PassCodeFormat.code128, bytes: _bytes(<int>[1, 2])),
        ]),
        isNull,
      );

      final ScannedTicketCode? picked = selectTicketCode(<TicketCodeCandidate>[
        _c(format: PassCodeFormat.aztec, bytes: _bytes(<int>[1, 2])),
      ]);
      expect(picked!.payloadBase64, base64.encode(<int>[1, 2]));
      expect(picked.payload, isNull);
      expect(picked.format, PassCodeFormat.aztec);
    });

    test('carries the symbology through unchanged', () {
      final ScannedTicketCode? picked = selectTicketCode(<TicketCodeCandidate>[
        _c(format: PassCodeFormat.pdf417, text: 'M1DOE/JOHN', area: 2000),
      ]);
      expect(picked!.format, PassCodeFormat.pdf417);
    });

    // Equal areas must not depend on iteration luck: the same screenshot has to
    // give the same pass every time it is uploaded.
    test('ties go to document order', () {
      final ScannedTicketCode? picked = selectTicketCode(<TicketCodeCandidate>[
        _c(text: 'FIRST', area: 500),
        _c(text: 'SECOND', area: 500),
      ]);
      expect(picked!.payload, 'FIRST');
    });
  });

  group('passCodeFormatFor', () {
    test('maps every ML Kit symbology the renderer can reproduce', () {
      expect(passCodeFormatFor(BarcodeFormat.qrCode), PassCodeFormat.qr);
      expect(passCodeFormatFor(BarcodeFormat.aztec), PassCodeFormat.aztec);
      expect(passCodeFormatFor(BarcodeFormat.pdf417), PassCodeFormat.pdf417);
      expect(
        passCodeFormatFor(BarcodeFormat.dataMatrix),
        PassCodeFormat.dataMatrix,
      );
      expect(passCodeFormatFor(BarcodeFormat.code128), PassCodeFormat.code128);
      expect(passCodeFormatFor(BarcodeFormat.upca), PassCodeFormat.upcA);
      expect(passCodeFormatFor(BarcodeFormat.upce), PassCodeFormat.upcE);
    });

    // A format we cannot re-render is not one to claim we found. Silence beats
    // a symbol that does not match the ticket.
    test('refuses formats it cannot reproduce', () {
      expect(passCodeFormatFor(BarcodeFormat.unknown), isNull);
      expect(passCodeFormatFor(BarcodeFormat.all), isNull);
    });
  });
}
