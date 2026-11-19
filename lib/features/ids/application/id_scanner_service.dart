import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../core/scanning/live_frame_reader.dart';
import '../domain/aadhaar_qr.dart';
import '../domain/id_document.dart';
import '../domain/id_scan_text.dart';

export '../domain/id_scan_text.dart' show IdScanResult;

/// One preview frame's reading: the parsed fields and any QR payload.
class IdFrameReading {
  const IdFrameReading(this.result, this.qrCodeData);

  final IdScanResult result;
  final String qrCodeData;
}

/// ML Kit OCR for the ID cards.
///
/// **Ownership contract:** the two detectors below are `static final` — one
/// instance per app run, shared by every scan. They are therefore owned by the
/// app, not by whichever screen happened to open first, and **must not be
/// closed** when a scanner screen is disposed. Closing them left the static
/// fields pointing at dead native handles, so the second scan of any app run
/// failed and stayed failed until a restart. `MrzScannerService.dispose` is a
/// no-op for exactly this reason.
///
/// If per-screen lifetimes are ever wanted, make the detectors instance fields
/// of a scanner-scoped object first; do not reinstate `close()` on statics.
class IdScannerService {
  IdScannerService._();

  static final _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  static final _barcodeScanner = BarcodeScanner(
    formats: [BarcodeFormat.qrCode],
  );

  static Future<IdScanResult?> processImage(
    String imagePath,
    IdDocumentType type,
  ) async {
    try {
      final input = InputImage.fromFilePath(imagePath);
      final recognized = await _recognizer.processImage(input);
      final qrData = await _readQr(input);
      final result = finish(
        parseIdText(recognized.text, type),
        qrData,
      ).copyWith(capturedImagePath: imagePath);
      return result.isEmpty ? null : result;
    } catch (e) {
      debugPrint('[IdScannerService] Text recognition unavailable.');
      return null;
    }
  }

  /// Reads one preview frame, keeping only the text inside [region].
  static Future<IdFrameReading?> readFrame(
    LiveFrame frame,
    IdDocumentType type,
    Rect region, {
    bool readQr = false,
  }) async {
    try {
      final recognized = await _recognizer.processImage(frame.image);
      final qrData = readQr ? await _readQr(frame.image) : '';
      return IdFrameReading(
        parseIdText(textInRegion(recognized, frame.uprightSize, region), type),
        qrData,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String> _readQr(InputImage input) async {
    try {
      final barcodes = await _barcodeScanner.processImage(input);
      for (final barcode in barcodes) {
        final value = barcode.rawValue ?? '';
        if (value.isNotEmpty) return value;
      }
    } catch (e) {
      debugPrint('[IdScannerService] QR recognition unavailable.');
    }
    return '';
  }

  /// Attaches [qrData] and, for an Aadhaar QR that decodes, lets its signed
  /// fields override the OCR.
  static IdScanResult finish(IdScanResult result, String qrData) {
    if (qrData.isEmpty) return result;
    final withQr = result.copyWith(qrCodeData: qrData);
    if (result.type != IdDocumentType.aadhaar) return withQr;
    final AadhaarQrData? decoded = decodeAadhaarQr(qrData);
    return decoded == null ? withQr : applyAadhaarQr(withQr, decoded);
  }

  static IdScanResult? extractText(String text, IdDocumentType type) {
    final result = parseIdText(text, type);
    return result.isEmpty ? null : result;
  }

  /// Deliberately does nothing. See the ownership note on [IdScannerService].
  ///
  /// Kept so callers that already invoke it keep compiling; new code should
  /// not call it at all.
  static Future<void> dispose() async {}
}
