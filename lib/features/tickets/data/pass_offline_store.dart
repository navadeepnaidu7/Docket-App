import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/secure_document_store.dart';
import '../domain/pass_catalog.dart';

/// Passes from the last successful sync, as saved on this phone.
@immutable
class OfflinePassSnapshot {
  const OfflinePassSnapshot({required this.items, required this.savedAt});

  final List<WalletPassItem> items;
  final DateTime savedAt;
}

/// Encrypted, account-scoped copy of the server pass list.
///
/// Unlike document records this is a rebuildable cache: an unreadable entry is
/// treated as absent and the next successful sync overwrites it.
/// See docs/features/offline-passes.md.
class PassOfflineStore {
  PassOfflineStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(aOptions: kDocketAndroidOptions);

  static const String _prefix = 'docket.passes.offline.v1.';

  final FlutterSecureStorage _storage;

  /// Scope keys never contain the raw account id or origin.
  static String scopeFor({required String origin, required String account}) =>
      base64Url.encode(utf8.encode('$origin|$account')).replaceAll('=', '');

  Future<OfflinePassSnapshot?> read(String scope) async {
    try {
      final String? raw = await _storage.read(key: '$_prefix$scope');
      if (raw == null || raw.isEmpty) return null;
      return await compute(_decode, raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String scope, List<WalletPassItem> items) async {
    final String raw = await compute(_encode, <Object>[
      DateTime.now().toUtc().toIso8601String(),
      items,
    ]);
    await _storage.write(key: '$_prefix$scope', value: raw);
  }

  /// Removes every account's snapshot. Used on sign-out.
  Future<void> clearAll() async {
    final Map<String, String> all = await _storage.readAll();
    for (final String key in all.keys) {
      if (key.startsWith(_prefix)) await _storage.delete(key: key);
    }
  }
}

String _encode(List<Object> input) => jsonEncode(<String, Object?>{
  'savedAt': input[0],
  'items': <Map<String, dynamic>>[
    for (final WalletPassItem item in input[1] as List<WalletPassItem>)
      item.toJson(),
  ],
});

OfflinePassSnapshot? _decode(String raw) {
  final Object? json = jsonDecode(raw);
  if (json is! Map) return null;
  final DateTime? savedAt = DateTime.tryParse(
    json['savedAt']?.toString() ?? '',
  );
  final Object? items = json['items'];
  if (savedAt == null || items is! List) return null;
  return OfflinePassSnapshot(
    savedAt: savedAt,
    items: <WalletPassItem>[
      for (final Object? item in items)
        if (item is Map)
          walletPassItemFromJson(Map<String, dynamic>.from(item)),
    ],
  );
}
