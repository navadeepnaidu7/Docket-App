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
/// `resetOnError` is off for one reason: on Android the plugin implements it as
/// "any exception on any operation wipes the entire store and reports success"
/// (`FlutterSecureStoragePlugin.java`, `deleteOnFailure` -> `deleteAll()` ->
/// `result.success("Data has been reset")`). It defaulted to false in 9.2.4 and
/// flipped to true in 10.x, so leaving it implicit would arm a silent wipe of
/// every passport and ID the first time a keystore hiccups — including during
/// the re-encryption above, which is exactly when a throw is most likely.
/// Failing loudly is recoverable; a wipe that reports success is not.
const AndroidOptions kDocketAndroidOptions = AndroidOptions(
  migrateOnAlgorithmChange: true,
  migrateWithBackup: true,
  resetOnError: false,
);

/// Encrypted storage for document records, with one-time migration from the
/// legacy SharedPreferences lists used by earlier Docket builds.
class SecureDocumentStore {
  SecureDocumentStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: kDocketAndroidOptions,
  );

  /// Keys whose last read threw, so their records are present but unreadable.
  ///
  /// Nothing may be written over them: a failed read surfaces as an empty list
  /// to the caller, and the first save after that would replace real documents
  /// with nothing.
  static final Set<String> _unreadable = <String>{};

  /// True when [key] holds records this process could not decrypt.
  static bool isUnreadable(String key) => _unreadable.contains(key);

  static Future<List<String>> readList(String key) async {
    final String? encrypted;
    try {
      encrypted = await _storage.read(key: key);
    } catch (_) {
      _unreadable.add(key);
      rethrow;
    }
    _unreadable.remove(key);
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
    if (_unreadable.contains(key)) {
      throw StateError(
        'Refusing to write $key: its stored records could not be read, and '
        'saving now would overwrite them.',
      );
    }
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
