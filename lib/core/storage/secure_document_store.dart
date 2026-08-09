import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android storage options shared by every Docket secure store.
///
/// Builds up to 9.2.4 wrote with `RSA_ECB_PKCS1Padding` + `AES_CBC_PKCS7Padding`.
/// The 10.x line re-encrypts that data with the modern ciphers on first read,
/// and only after an install has run a 10.x build is it safe to move to v11 —
/// which drops the old ciphers outright. `migrateWithBackup` keeps a recovery
/// copy while that one-time rewrite runs, because the records being re-encrypted
/// are passports and IDs the user cannot regenerate from anywhere else.
const AndroidOptions kDocketAndroidOptions = AndroidOptions(
  migrateOnAlgorithmChange: true,
  migrateWithBackup: true,
);

/// Encrypted storage for document records, with one-time migration from the
/// legacy SharedPreferences lists used by earlier Docket builds.
class SecureDocumentStore {
  SecureDocumentStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: kDocketAndroidOptions,
  );

  static Future<List<String>> readList(String key) async {
    final encrypted = await _storage.read(key: key);
    if (encrypted != null) return _decodeList(encrypted);

    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getStringList(key) ?? const <String>[];
    if (legacy.isNotEmpty) {
      await writeList(key, legacy);
      await prefs.remove(key);
    }
    return legacy;
  }

  static Future<void> writeList(String key, List<String> values) async {
    await _storage.write(key: key, value: jsonEncode(values));
  }

  static List<String> _decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
    } catch (_) {}
    return const <String>[];
  }
}
