/// Decodes the real scannable code off an uploaded ticket, on device.
///
/// Runs before the extract upload and costs nothing: ML Kit's barcode models
/// are on-device, so there are no tokens, no server CPU and no extra network.
/// A decoded symbol is also ground truth in a way a vision model's guess never
/// is — re-encoding the same payload in the same symbology gives a code that
/// scans identically at a gate. See `docs/features/ticket-code-extraction.md`.
///
/// Every failure here is silent by design. ML Kit barcode scanning uses the
/// Play Services variant, so on a fresh install the model may still be
/// downloading — the same caveat `id_scanner_service.dart` already carries.
/// A pass that arrives without a code is the state every pass is in today, and
/// far better than an error on a flow whose real job is extraction.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../domain/pass_code.dart';

/// A decoded code, in the shape the extract upload sends it.
@immutable
class ScannedTicketCode {
  const ScannedTicketCode({
    required this.format,
    this.payload,
    this.payloadBase64,
  }) : assert(payload != null || payloadBase64 != null);

  final PassCodeFormat format;

  /// Payload as text, when the symbol encoded valid UTF-8.
  final String? payload;

  /// Payload as base64 bytes, for a matrix symbol whose content is not text.
  final String? payloadBase64;
}

/// One candidate symbol found in a ticket image.
///
/// Split out from the ML Kit type so the selection rule below is a pure
/// function over plain data and can be tested without a device.
@immutable
class TicketCodeCandidate {
  const TicketCodeCandidate({
    required this.format,
    required this.area,
    this.text,
    this.bytes,
  });

  final PassCodeFormat format;

  /// Area of the symbol's bounding box in the source image, in square pixels.
  final double area;

  final String? text;
  final Uint8List? bytes;
}

/// Payload prefixes that are never the code a gate scans.
///
/// A ticket screenshot routinely carries more than one symbol: the boarding
/// code, plus an app-store QR, a "rate us" link, a UPI intent, an operator's
/// marketing code. Presenting one of those at a turnstile is worse than
/// presenting nothing, so they are dropped before the size heuristic runs
/// rather than being allowed to win it on a large logo.
const List<String> _kNonTicketPayloadHints = <String>[
  'play.google.com',
  'apps.apple.com',
  'itunes.apple.com',
  'facebook.com',
  'instagram.com',
  'twitter.com',
  'x.com',
  'youtube.com',
  'youtu.be',
  'wa.me',
  'whatsapp.com',
  'upi://',
];

/// Picks the code most likely to be the one a gate reads, or null.
///
/// Pure and exported for tests. The rule, in order:
///
/// 1. Drop candidates with no usable payload — and, for linear symbologies,
///    ones that carry only bytes. A Code 128 encodes characters, so a payload
///    that is not text cannot be reproduced as one.
/// 2. Drop known marketing and app-install payloads.
/// 3. Prefer the largest symbol. The code meant to be scanned is the one
///    printed big; the store badge in the footer is not.
/// 4. Tie-break on document order, so the choice is deterministic.
ScannedTicketCode? selectTicketCode(List<TicketCodeCandidate> candidates) {
  TicketCodeCandidate? best;
  for (final TicketCodeCandidate c in candidates) {
    final String text = (c.text ?? '').trim();
    final Uint8List? bytes = c.bytes;

    if (text.isEmpty && (bytes == null || bytes.isEmpty)) continue;
    if (text.isEmpty && !c.format.isMatrix) continue;
    if (text.isNotEmpty && _looksNonTicket(text)) continue;

    if (best == null || c.area > best.area) best = c;
  }
  if (best == null) return null;

  final String text = (best.text ?? '').trim();
  if (text.isNotEmpty) {
    return ScannedTicketCode(format: best.format, payload: text);
  }
  return ScannedTicketCode(
    format: best.format,
    payloadBase64: base64.encode(best.bytes!),
  );
}

bool _looksNonTicket(String payload) {
  final String lower = payload.toLowerCase();
  for (final String hint in _kNonTicketPayloadHints) {
    if (lower.contains(hint)) return true;
  }
  return false;
}

/// Maps ML Kit's symbology onto the wire value the pass contract uses.
///
/// Returns null for formats that cannot be reproduced — [BarcodeFormat.unknown]
/// most of all. A code we cannot re-render is not one we should claim to have.
PassCodeFormat? passCodeFormatFor(BarcodeFormat format) => switch (format) {
      BarcodeFormat.qrCode => PassCodeFormat.qr,
      BarcodeFormat.aztec => PassCodeFormat.aztec,
      BarcodeFormat.dataMatrix => PassCodeFormat.dataMatrix,
      BarcodeFormat.pdf417 => PassCodeFormat.pdf417,
      BarcodeFormat.code128 => PassCodeFormat.code128,
      BarcodeFormat.code39 => PassCodeFormat.code39,
      BarcodeFormat.code93 => PassCodeFormat.code93,
      BarcodeFormat.codabar => PassCodeFormat.codabar,
      BarcodeFormat.ean13 => PassCodeFormat.ean13,
      BarcodeFormat.ean8 => PassCodeFormat.ean8,
      BarcodeFormat.itf => PassCodeFormat.itf,
      BarcodeFormat.upca => PassCodeFormat.upcA,
      BarcodeFormat.upce => PassCodeFormat.upcE,
      _ => null,
    };

class TicketCodeScanner {
  TicketCodeScanner();

  /// Pages of a PDF to rasterise looking for a code.
  ///
  /// Tickets are one page; a booking confirmation occasionally puts terms on a
  /// second. Past that it is a document, not a ticket, and every extra page is
  /// a render that delays the upload for nothing.
  static const int _maxPdfPages = 3;

  /// Long edge, in pixels, to rasterise a PDF page to.
  ///
  /// A PDF page is 72 dpi at its own point size, where a dense QR's modules
  /// land inside a single pixel and nothing decodes. Scaling to this puts an A4
  /// page near 220 dpi — comfortably above what ML Kit needs. Expressed as a
  /// target rather than a fixed multiplier, and clamped below, so a poster-size
  /// page cannot allocate a bitmap wildly larger than a ticket's.
  static const double _pdfTargetLongEdge = 2200;
  static const double _pdfMaxScale = 4.0;

  /// Every format, not just QR. Cinemas print Code 128 strips as often as QR
  /// and airlines use PDF417 or Aztec, so restricting this to `qrCode` would
  /// silently skip whole categories of real ticket.
  static final BarcodeScanner _scanner =
      BarcodeScanner(formats: <BarcodeFormat>[BarcodeFormat.all]);

  /// Decodes the code on [file], or returns null when there is none to find.
  ///
  /// Never throws: a caller on the ingest path treats "no code" and "scanning
  /// broke" the same way, because the upload has to proceed either way.
  Future<ScannedTicketCode?> scan({
    required File file,
    required String mimeType,
  }) async {
    try {
      if (mimeType == 'application/pdf') return await _scanPdf(file);
      return await _scanImageFile(file.path);
    } catch (e) {
      // Deliberately no payload in the log line: this repo never logs booking
      // data, and the payload is exactly that.
      debugPrint('[TicketCodeScanner] scan failed: ${e.runtimeType}');
      return null;
    }
  }

  Future<ScannedTicketCode?> _scanImageFile(String path) async {
    final List<Barcode> found =
        await _scanner.processImage(InputImage.fromFilePath(path));
    return selectTicketCode(_candidatesFrom(found));
  }

  /// Rasterises the first few pages and scans each until one yields a code.
  ///
  /// Every page render lands in a temp file that is deleted before the next
  /// one: this is a booking document, and it has no business outliving the
  /// scan on disk.
  Future<ScannedTicketCode?> _scanPdf(File file) async {
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openFile(file.path);
      final int pages = math.min(doc.pagesCount, _maxPdfPages);
      for (int i = 1; i <= pages; i++) {
        final ScannedTicketCode? code = await _scanPdfPage(doc, i);
        if (code != null) return code;
      }
      return null;
    } finally {
      await doc?.close();
    }
  }

  Future<ScannedTicketCode?> _scanPdfPage(PdfDocument doc, int pageNumber) async {
    PdfPage? page;
    File? rendered;
    try {
      page = await doc.getPage(pageNumber);
      final double longEdge = math.max(page.width, page.height);
      final double scale = longEdge <= 0
          ? 1.0
          : (_pdfTargetLongEdge / longEdge).clamp(1.0, _pdfMaxScale);

      // PNG, not JPEG: a dense symbol's modules are one pixel wide at this
      // scale and JPEG's ringing around that much hard black-white edge is
      // exactly what stops a decode.
      final PdfPageImage? image = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: PdfPageImageFormat.png,
      );
      final Uint8List? bytes = image?.bytes;
      if (bytes == null || bytes.isEmpty) return null;

      final Directory dir = await getTemporaryDirectory();
      rendered = File(
        '${dir.path}${Platform.pathSeparator}'
        'docket_code_scan_${DateTime.now().microsecondsSinceEpoch}_$pageNumber.png',
      );
      await rendered.writeAsBytes(bytes, flush: true);
      return await _scanImageFile(rendered.path);
    } finally {
      await page?.close();
      if (rendered != null) {
        try {
          if (rendered.existsSync()) await rendered.delete();
        } catch (_) {
          // A temp file the OS will reap anyway. Not worth failing an upload.
        }
      }
    }
  }

  List<TicketCodeCandidate> _candidatesFrom(List<Barcode> barcodes) {
    final List<TicketCodeCandidate> out = <TicketCodeCandidate>[];
    for (final Barcode b in barcodes) {
      final PassCodeFormat? format = passCodeFormatFor(b.format);
      if (format == null) continue;
      out.add(
        TicketCodeCandidate(
          format: format,
          area: b.boundingBox.width.abs() * b.boundingBox.height.abs(),
          text: b.rawValue,
          bytes: b.rawBytes,
        ),
      );
    }
    return out;
  }
}
