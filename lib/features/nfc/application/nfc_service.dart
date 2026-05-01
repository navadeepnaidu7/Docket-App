import 'package:flutter/services.dart';

class NfcService {
  static const MethodChannel _channel = MethodChannel('com.slickport/nfc_passport');

  Future<Map<String, dynamic>?> startNfcRead({
    required String passportNumber,
    required String dateOfBirth,
    required String expiryDate,
  }) async {
    try {
      final result = await _channel.invokeMethod('startNfcRead', {
        'passportNumber': passportNumber,
        'dateOfBirth': dateOfBirth, // format YYMMDD
        'expiryDate': expiryDate,   // format YYMMDD
      });
      return Map<String, dynamic>.from(result);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> stopNfcRead() async {
    try {
      await _channel.invokeMethod('stopNfcRead');
    } catch (e) {
      // ignore
    }
  }
}
