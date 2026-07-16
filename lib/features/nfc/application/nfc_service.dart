import 'package:flutter/services.dart';

class NfcException implements Exception {
  const NfcException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

class NfcService {
  static const MethodChannel _channel = MethodChannel(
    'com.docket/nfc_passport',
  );

  Future<Map<String, dynamic>?> startNfcRead({
    required String passportNumber,
    required String dateOfBirth,
    required String expiryDate,
  }) async {
    try {
      final result = await _channel.invokeMethod('startNfcRead', {
        'passportNumber': passportNumber,
        'dateOfBirth': dateOfBirth, // format YYMMDD
        'expiryDate': expiryDate, // format YYMMDD
      });
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw NfcException(
        e.code,
        e.message ?? 'NFC is unavailable on this device.',
      );
    } on MissingPluginException {
      throw const NfcException(
        'UNAVAILABLE',
        'NFC is unavailable on this device.',
      );
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
