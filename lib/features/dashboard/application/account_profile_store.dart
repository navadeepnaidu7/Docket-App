import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/secure_document_store.dart';

const String kAccountProfileKey = 'account_profile_v1';

/// The three storage operations the account profile needs.
///
/// Narrow on purpose: it gives tests a seam for read/write/delete failures
/// without standing up a platform channel, which is the only way to exercise
/// a keystore that refuses to open.
abstract class AccountProfileStore {
  Future<String?> read();

  Future<void> write(String value);

  Future<void> delete();
}

/// Production store — the same encrypted backend the document lists use.
class SecureAccountProfileStore implements AccountProfileStore {
  const SecureAccountProfileStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: kDocketAndroidOptions,
  );

  @override
  Future<String?> read() => _storage.read(key: kAccountProfileKey);

  @override
  Future<void> write(String value) =>
      _storage.write(key: kAccountProfileKey, value: value);

  @override
  Future<void> delete() => _storage.delete(key: kAccountProfileKey);
}
