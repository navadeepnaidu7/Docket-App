import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/account_profile.dart';
import 'account_profile_store.dart';

final accountProfileProvider =
    StateNotifierProvider<AccountProfileNotifier, AccountProfile>(
  (Ref ref) => AccountProfileNotifier(),
);

class AccountProfileNotifier extends StateNotifier<AccountProfile> {
  AccountProfileNotifier({AccountProfileStore? store})
      : _store = store ?? const SecureAccountProfileStore(),
        super(AccountProfile.empty) {
    _load();
  }

  final AccountProfileStore _store;

  bool _hydrated = false;

  /// Serializes every state-and-storage mutation, the same way the passport and
  /// ID lists queue their saves. Without it, two edits started from the same
  /// sheet can compute their next profile from the same base and race to write,
  /// so whichever channel call returns last wins and the other field is lost.
  Future<void> _writeQueue = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() action) {
    final Future<T> result = _writeQueue.then((_) => action());
    // The queue itself must survive a failed write, so swallow the error here
    // and let it reach the caller through [result] instead.
    _writeQueue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _load() => _serialize(() async {
        final String? raw;
        try {
          raw = await _store.read();
        } catch (_) {
          // Policy: a store that will not open leaves the profile empty rather
          // than taking the app down on launch. Every field here is optional
          // and re-enterable, and `_hydrated` stays false so a later edit still
          // persists normally once the keystore recovers.
          return;
        }
        if (raw == null || raw.isEmpty) return;
        if (_hydrated || !mounted) return;
        state = AccountProfile.fromJson(raw);
      });

  /// Applies [fn] to the profile and persists the result.
  ///
  /// [fn] runs inside the queue, not at call time, so each edit sees the
  /// previous one's result.
  Future<void> _mutate(AccountProfile Function(AccountProfile) fn) =>
      _serialize(() async {
        if (!mounted) return;
        final AccountProfile previous = state;
        final bool wasHydrated = _hydrated;
        final AccountProfile next = fn(previous);
        state = next;
        _hydrated = true;
        try {
          await _store.write(next.toJson());
        } catch (_) {
          _restore(previous, wasHydrated);
          rethrow;
        }
      });

  /// Puts back the pre-write values after storage rejected the change.
  ///
  /// Safe to do unconditionally because mutations are serialized: nothing newer
  /// has run yet, so this cannot overwrite a later profile.
  void _restore(AccountProfile previous, bool wasHydrated) {
    if (!mounted) return;
    state = previous;
    _hydrated = wasHydrated;
  }

  Future<void> update(AccountProfile Function(AccountProfile) fn) => _mutate(fn);

  Future<void> setDateOfBirth(String value) =>
      _mutate((AccountProfile p) => p.copyWith(dateOfBirth: value.trim()));

  Future<void> setPhone(String value) =>
      _mutate((AccountProfile p) => p.copyWith(phone: value.trim()));

  Future<void> setNationality(String value) => _mutate(
        (AccountProfile p) =>
            p.copyWith(nationality: value.trim().toUpperCase()),
      );

  Future<void> setCity(String value) =>
      _mutate((AccountProfile p) => p.copyWith(city: value.trim()));

  Future<void> clear() => _serialize(() async {
        if (!mounted) return;
        final AccountProfile previous = state;
        final bool wasHydrated = _hydrated;
        state = AccountProfile.empty;
        _hydrated = true;
        try {
          await _store.delete();
        } catch (_) {
          // The record is still on disk, so showing a cleared profile would be
          // a lie about what the device holds.
          _restore(previous, wasHydrated);
          rethrow;
        }
      });
}
