import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/mrz_result.dart';
import 'full_page_extractor.dart';
import 'mrz_parser.dart';

/// Orchestrates the two-pass OCR pipeline for extracting passport data
/// from a captured image.
///
/// Pass 1 — Full document page OCR → [FullPageExtractor]
/// Pass 2 — Bottom 22% crop       → [MrzParser]
/// Merge  — MRZ fields take precedence; full-page fills in name/country
class MrzScannerService {
  MrzScannerService._();

  static final _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Main entry point. Returns null if no passport data could be extracted.
  static Future<MrzResult?> processImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);

      // ── Pass 1: full page ─────────────────────────────────────────────────
      final fullPageText = await _recognizeText(inputImage);
      final fullPageData = FullPageExtractor.extract(fullPageText);

      // Also try to find MRZ in the full page first (handles well-lit, flat shots)
      MrzResult? mrzResult = MrzParser.findInText(fullPageText);

      // ── Pass 2: crop bottom 22% for MRZ ──────────────────────────────────
      if (mrzResult == null) {
        final croppedPath = await _cropMrzRegion(imagePath);
        if (croppedPath != null) {
          final croppedInput = InputImage.fromFilePath(croppedPath);
          final croppedText = await _recognizeText(croppedInput);
          mrzResult = MrzParser.findInText(croppedText);
          // Clean up temp crop
          try {
            await File(croppedPath).delete();
          } catch (_) {}
        }
      }

      if (mrzResult == null) return null;

      // ── Merge: prefer MRZ for machine-readable fields, full-page for display ─
      return mrzResult.copyWith(
        fullName: fullPageData.fullName.isNotEmpty
            ? fullPageData.fullName
            : mrzResult.displayName,
        issuingCountry: fullPageData.issuingCountry,
        capturedImagePath: imagePath,
      );
    } catch (e) {
      debugPrint('[MrzScannerService] Error: $e');
      return null;
    }
  }

  static Future<String> _recognizeText(InputImage inputImage) async {
    try {
      final recognized = await _recognizer.processImage(inputImage);
      return recognized.text;
    } catch (_) {
      return '';
    }
  }

  /// Crops the bottom 22% of the image (MRZ zone) and saves it as a temp file.
  static Future<String?> _cropMrzRegion(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final imgWidth = image.width;
      final imgHeight = image.height;
      final cropTop = (imgHeight * 0.78).round();
      final cropHeight = imgHeight - cropTop;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // Draw only the bottom portion
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(
          0,
          cropTop.toDouble(),
          imgWidth.toDouble(),
          cropHeight.toDouble(),
        ),
        ui.Rect.fromLTWH(0, 0, imgWidth.toDouble(), cropHeight.toDouble()),
        ui.Paint(),
      );

      final picture = recorder.endRecording();
      final croppedImg = await picture.toImage(imgWidth, cropHeight);
      final byteData = await croppedImg.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) return null;

      final tempDir = Directory.systemTemp;
      final tempPath =
          '${tempDir.path}/mrz_crop_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(tempPath).writeAsBytes(byteData.buffer.asUint8List());
      return tempPath;
    } catch (e) {
      debugPrint('[MrzScannerService] Crop error: $e');
      return null;
    }
  }

  /// Call this when the scanner is disposed to release ML Kit resources.
  static Future<void> dispose() async {}
}
