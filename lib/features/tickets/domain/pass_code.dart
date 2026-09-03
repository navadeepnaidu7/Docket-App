/// The scannable code on a pass: what it encodes, and in which symbology.
///
/// Every pass kind carries the same three wire fields — `codeFormat`,
/// `codePayload`, `codePayloadBase64` — populated by decoding the symbol off
/// the uploaded ticket on device. See `docs/features/ticket-code-extraction.md`.
///
/// Deliberately plain Dart with no Flutter import so the parsing and the
/// omit-when-absent rule are unit testable without pumping a widget.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Symbology of a pass code.
///
/// The format has to travel with the payload: re-rendering a Code 128 booking
/// reference as a QR produces a symbol no gate reads. Absent on the wire means
/// [PassCodeFormat.qr], which is what the client already assumed for train and
/// bus passes before any of these fields were populated.
enum PassCodeFormat {
  qr('qr'),
  aztec('aztec'),
  dataMatrix('dataMatrix'),
  pdf417('pdf417'),
  code128('code128'),
  code39('code39'),
  code93('code93'),
  codabar('codabar'),
  ean13('ean13'),
  ean8('ean8'),
  itf('itf'),
  upcA('upcA'),
  upcE('upcE');

  const PassCodeFormat(this.wire);

  /// Value used in pass JSON and in the extract upload.
  final String wire;

  /// True for the two-dimensional symbologies that encode arbitrary bytes.
  ///
  /// Only these can carry a payload that is not valid UTF-8 text; a linear
  /// barcode with unrepresentable bytes is not a code we can reproduce.
  bool get isMatrix =>
      this == PassCodeFormat.qr ||
      this == PassCodeFormat.aztec ||
      this == PassCodeFormat.dataMatrix ||
      this == PassCodeFormat.pdf417;

  /// Parses a wire value, case-insensitively. Unknown or absent gives [qr].
  static PassCodeFormat fromWire(String? raw) {
    final String key = (raw ?? '').trim().toLowerCase();
    if (key.isEmpty) return PassCodeFormat.qr;
    for (final PassCodeFormat f in PassCodeFormat.values) {
      if (f.wire.toLowerCase() == key) return f;
    }
    return PassCodeFormat.qr;
  }
}

/// A code that can actually be presented at a gate.
///
/// One of [text] or [bytes] is always non-null — an instance with neither is
/// not constructible through [PassCode.parse], which is the only way passes
/// build one. That is what lets every surface treat "no `PassCode`" as the
/// single, unambiguous no-code state.
class PassCode {
  const PassCode._({required this.format, this.text, this.bytes});

  final PassCodeFormat format;

  /// The payload as text, when the symbol encoded valid UTF-8.
  final String? text;

  /// The payload as raw bytes, for a matrix symbol whose content is not text.
  final Uint8List? bytes;

  /// Builds a code from the three wire fields, or null when there is nothing
  /// scannable.
  ///
  /// Never falls back to a PNR or booking id: those identify a booking, they
  /// are not what a gate scanner reads, and a code that scans to the wrong
  /// thing is worse at a turnstile than no code at all. Same rule as
  /// `passShareCodePayload` in `pass_share_summary.dart`.
  static PassCode? parse({
    String? payload,
    String? payloadBase64,
    String? format,
  }) {
    final PassCodeFormat fmt = PassCodeFormat.fromWire(format);

    final String text = (payload ?? '').trim();
    if (text.isNotEmpty) {
      return PassCode._(format: fmt, text: text);
    }

    // Bytes are a fallback for matrix symbologies only. A linear barcode
    // encodes characters, so bytes that are not text cannot be reproduced as
    // one and are better treated as no code.
    final String b64 = (payloadBase64 ?? '').trim();
    if (b64.isEmpty || !fmt.isMatrix) return null;
    try {
      final Uint8List raw = base64Decode(b64);
      if (raw.isEmpty) return null;
      return PassCode._(format: fmt, bytes: raw);
    } on FormatException {
      return null;
    }
  }

  /// True when the payload is raw bytes rather than text.
  bool get isBinary => text == null;
}
