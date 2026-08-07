import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/account_profile.dart';

const _kAccountProfileKey = 'account_profile_v1';

final accountProfileProvider =
    StateNotifierProvider<AccountProfileNotifier, AccountProfile>(
  (Ref ref) => AccountProfileNotifier(),
);

class AccountProfileNotifier extends StateNotifier<AccountProfile> {
  AccountProfileNotifier() : super(AccountProfile.empty) {
    _load();
  }

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> _load() async {
    final String? raw = await _storage.read(key: _kAccountProfileKey);
    if (raw == null || raw.isEmpty) return;
    state = AccountProfile.fromJson(raw);
  }

  Future<void> _persist(AccountProfile next) async {
    state = next;
    await _storage.write(key: _kAccountProfileKey, value: next.toJson());
  }

  Future<void> update(AccountProfile Function(AccountProfile) fn) async {
    await _persist(fn(state));
  }

  Future<void> setDateOfBirth(String value) =>
      update((AccountProfile p) => p.copyWith(dateOfBirth: value.trim()));

  Future<void> setPhone(String value) =>
      update((AccountProfile p) => p.copyWith(phone: value.trim()));

  Future<void> setNationality(String value) =>
      update((AccountProfile p) => p.copyWith(nationality: value.trim().toUpperCase()));

  Future<void> setCity(String value) =>
      update((AccountProfile p) => p.copyWith(city: value.trim()));

  Future<void> setNotes(String value) =>
      update((AccountProfile p) => p.copyWith(notes: value.trim()));

  Future<void> clear() async {
    state = AccountProfile.empty;
    await _storage.delete(key: _kAccountProfileKey);
  }
}
