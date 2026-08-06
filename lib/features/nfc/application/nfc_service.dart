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
      final result = await _channel.invokeMethod<dynamic>('startNfcRead', {
        'passportNumber': passportNumber,
        'dateOfBirth': dateOfBirth, // format YYMMDD
        'expiryDate': expiryDate, // format YYMMDD
      });
      // A cancelled/abandoned scan used to hang; it now errors CANCELLED. A
      // success with a non-map payload is treated as empty rather than throwing
      // inside Map.from, which would surface as an uncaught exception after a
      // successful native read.
      if (result is! Map) return null;
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
