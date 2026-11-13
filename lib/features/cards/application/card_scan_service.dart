import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/card_scan_text.dart';

/// On-device text recognition for a card photo.
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
}
