import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../core/scanning/live_frame_reader.dart';
import '../domain/card_scan_text.dart';

/// On-device text recognition for a card photo or a preview frame.
///
/// The recognised text is returned to the caller and is never logged.
class CardScanService {
  CardScanService._();

  static final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  static Future<CardScanFields> readFile(String path) async {
    try {
      final RecognizedText recognized = await _recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      return parseCardOcr(recognized.text);
    } catch (_) {
      return CardScanFields.empty;
    }
  }

  /// Reads only the text inside [region], the guide frame as fractions of
  /// the preview, so a receipt or a second card beside it is not read.
  static Future<CardScanFields> readFrame(LiveFrame frame, Rect region) async {
    try {
      final RecognizedText recognized = await _recognizer.processImage(
        frame.image,
      );
      return parseCardOcr(textInRegion(recognized, frame.uprightSize, region));
    } catch (_) {
      return CardScanFields.empty;
    }
  }
}
