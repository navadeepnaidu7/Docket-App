import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/id_document.dart';

class IdScanResult {
  const IdScanResult({
    required this.type,
    this.holderName = '',
    this.documentNumber = '',
    this.dateOfBirth = '',
    this.fatherName = '',
    this.address = '',
    this.gender = '',
    this.capturedImagePath = '',
    this.qrCodeData = '',
  });

  final IdDocumentType type;
  final String holderName;
  final String documentNumber;
  final String dateOfBirth;
  final String fatherName;
  final String address;
  final String gender;
  final String capturedImagePath;
  final String qrCodeData;
}

class IdScannerService {
  IdScannerService._();

  static final _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  static final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableTracking: false,
    ),
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

      // 1. Run Text Recognition
      final recognized = await _recognizer.processImage(input);
      final text = recognized.text;

      // 2. Run Face Detection & Crop if a face is found
      String faceCropPath = '';
      try {
        final faces = await _faceDetector.processImage(input);
        if (faces.isNotEmpty) {
          final face = faces.first;
          final cropped = await _cropImageRect(imagePath, face.boundingBox);
          if (cropped != null) {
            faceCropPath = cropped;
          }
        }
      } catch (e) {
        debugPrint('[IdScannerService] Face detection/crop error: $e');
      }

      // 3. Run Barcode/QR Scanning
      String qrData = '';
      try {
        final barcodes = await _barcodeScanner.processImage(input);
        if (barcodes.isNotEmpty) {
          qrData = barcodes.first.rawValue ?? '';
        }
      } catch (e) {
        debugPrint('[IdScannerService] Barcode/QR scan error: $e');
      }

      final finalImagePath = faceCropPath.isNotEmpty ? faceCropPath : imagePath;

      return switch (type) {
        IdDocumentType.pan => _extractPan(text, finalImagePath, qrData),
        IdDocumentType.aadhaar => _extractAadhaar(text, finalImagePath, qrData),
      };
    } catch (e) {
      debugPrint('[IdScannerService] Error: $e');
      return null;
    }
  }

  // ── PAN Card extractor ────────────────────────────────────────────────────

  static IdScanResult? _extractPan(String text, String imagePath, String qrCodeData) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final panRegex = RegExp(r'[A-Z]{5}[0-9]{4}[A-Z]');
    final panMatch = panRegex.firstMatch(text.replaceAll(' ', ''));
    final documentNumber = panMatch?.group(0) ?? '';

    final dobRegex = RegExp(r'\b(\d{2}/\d{2}/\d{4})\b');
    final dobMatch = dobRegex.firstMatch(text);
    String dateOfBirth = '';
    if (dobMatch != null) {
      final parts = dobMatch.group(1)!.split('/');
      dateOfBirth = '${parts[2]}-${parts[1]}-${parts[0]}';
    }

    int nameIdx = -1;
    int fatherIdx = -1;
    for (int i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase().trim();
      if (fatherIdx == -1 &&
          nameIdx == -1 &&
          (lower == 'name' || lower == 'नाम')) {
        nameIdx = i;
      }
      if (lower.contains('father') ||
          lower.contains("father's") ||
          lower.contains('पिता')) {
        fatherIdx = i;
      }
    }

    String holderName = '';
    String fatherName = '';

    if (nameIdx != -1 && nameIdx + 1 < lines.length) {
      holderName = _toTitleCase(lines[nameIdx + 1]);
    }
    if (fatherIdx != -1 && fatherIdx + 1 < lines.length) {
      fatherName = _toTitleCase(lines[fatherIdx + 1]);
    }

    if (holderName.isEmpty || holderName == fatherName) {
      final capsLines = <String>[];
      for (final line in lines) {
        if (line == line.toUpperCase() &&
            line.length > 3 &&
            RegExp(r'^[A-Z ]+$').hasMatch(line) &&
            !panRegex.hasMatch(line) &&
            !RegExp(
              r'INCOME|TAX|INDIA|PERMANENT|ACCOUNT|NUMBER|GOVT|DEPARTMENT|PAN',
            ).hasMatch(line)) {
          capsLines.add(line);
        }
      }
      if (capsLines.isNotEmpty) holderName = _toTitleCase(capsLines[0]);
      if (fatherName.isEmpty && capsLines.length > 1) {
        fatherName = _toTitleCase(capsLines[1]);
      }
    }

    if (holderName == fatherName && holderName.isNotEmpty) holderName = '';

    if (documentNumber.isEmpty && holderName.isEmpty) return null;

    return IdScanResult(
      type: IdDocumentType.pan,
      holderName: holderName,
      documentNumber: documentNumber,
      dateOfBirth: dateOfBirth,
      fatherName: fatherName,
      capturedImagePath: imagePath,
      qrCodeData: qrCodeData,
    );
  }

  // ── Aadhaar Card extractor ────────────────────────────────────────────────

  static IdScanResult? _extractAadhaar(String text, String imagePath, String qrCodeData) {
    final aadhaarRegex = RegExp(r'\b(\d{4})\s(\d{4})\s(\d{4})\b');
    final aadhaarMatch = aadhaarRegex.firstMatch(text);
    final documentNumber = aadhaarMatch != null
        ? '${aadhaarMatch.group(1)} ${aadhaarMatch.group(2)} ${aadhaarMatch.group(3)}'
        : '';

    final dobRegex = RegExp(r'\b(\d{2}/\d{2}/\d{4})\b');
    final dobMatch = dobRegex.firstMatch(text);
    String dateOfBirth = '';
    if (dobMatch != null) {
      final parts = dobMatch.group(1)!.split('/');
      dateOfBirth = '${parts[2]}-${parts[1]}-${parts[0]}';
    } else {
      final yobRegex = RegExp(r'\bYOB[:\s]+(\d{4})\b', caseSensitive: false);
      final yobMatch = yobRegex.firstMatch(text);
      if (yobMatch != null) dateOfBirth = yobMatch.group(1)!;
    }

    String gender = '';
    if (RegExp(r'\bMALE\b', caseSensitive: false).hasMatch(text)) {
      gender = 'Male';
    } else if (RegExp(r'\bFEMALE\b', caseSensitive: false).hasMatch(text)) {
      gender = 'Female';
    } else if (RegExp(r'\bOTHER\b', caseSensitive: false).hasMatch(text)) {
      gender = 'Other';
    }

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    String holderName = '';
    for (final line in lines) {
      if (line == line.toUpperCase() &&
          line.length > 3 &&
          RegExp(r'^[A-Z ]+$').hasMatch(line) &&
          !line.contains('AADHAAR') &&
          !line.contains('UIDAI') &&
          !line.contains('GOVT') &&
          !line.contains('INDIA')) {
        holderName = _toTitleCase(line);
        break;
      }
    }

    String address = '';
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].toLowerCase().startsWith('address')) {
        final addrLines = <String>[];
        for (int j = i + 1; j < lines.length && j < i + 5; j++) {
          if (aadhaarRegex.hasMatch(lines[j])) break;
          addrLines.add(lines[j]);
        }
        address = addrLines.join(', ');
        break;
      }
    }

    if (documentNumber.isEmpty && holderName.isEmpty) return null;

    return IdScanResult(
      type: IdDocumentType.aadhaar,
      holderName: holderName,
      documentNumber: documentNumber,
      dateOfBirth: dateOfBirth,
      gender: gender,
      address: address,
      capturedImagePath: imagePath,
      qrCodeData: qrCodeData,
    );
  }

  static Future<String?> _cropImageRect(String imagePath, ui.Rect boundingBox) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final imgWidth = image.width;
      final imgHeight = image.height;

      final left = boundingBox.left.clamp(0.0, imgWidth.toDouble());
      final top = boundingBox.top.clamp(0.0, imgHeight.toDouble());
      final width = boundingBox.width.clamp(0.0, imgWidth.toDouble() - left);
      final height = boundingBox.height.clamp(0.0, imgHeight.toDouble() - top);

      if (width <= 0 || height <= 0) return null;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(left, top, width, height),
        ui.Rect.fromLTWH(0, 0, width, height),
        ui.Paint(),
      );

      final picture = recorder.endRecording();
      final croppedImg = await picture.toImage(width.round(), height.round());
      final byteData = await croppedImg.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) return null;

      final tempDir = Directory.systemTemp;
      final tempPath =
          '${tempDir.path}/face_crop_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(tempPath).writeAsBytes(byteData.buffer.asUint8List());
      return tempPath;
    } catch (e) {
      debugPrint('[IdScannerService] Crop error: $e');
      return null;
    }
  }

  static String _toTitleCase(String s) => s
      .toLowerCase()
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  static Future<void> dispose() async {
    try {
      await _recognizer.close();
      await _faceDetector.close();
      await _barcodeScanner.close();
    } catch (e) {
      debugPrint('[IdScannerService] Error during dispose: $e');
    }
  }
}
