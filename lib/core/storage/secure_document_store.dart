import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Encrypted storage for document records, with one-time migration from the
/// legacy SharedPreferences lists used by earlier Docket builds.
class SecureDocumentStore {
  SecureDocumentStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
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
      if (decoded is List) return decoded.whereType<String>().toList(growable: false);
    } catch (_) {}
    return const <String>[];
  }
}