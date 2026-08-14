import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/secure_document_store.dart';

/// Access + refresh tokens for `docket_server`. Separate from document lists.
class ApiTokens {
  const ApiTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;

  bool get isEmpty => accessToken.isEmpty;

  factory ApiTokens.fromJson(Map<String, dynamic> json) {
    return ApiTokens(
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };
}

/// Persists API tokens. Same Android options as [SecureDocumentStore]; a
/// failed read is treated as signed-out rather than wiping the key.
class ApiSessionStore {
  ApiSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(aOptions: kDocketAndroidOptions);

  static const String _key = 'docket_api_session_v1';

  final FlutterSecureStorage _storage;
  bool _unreadable = false;

  bool get isUnreadable => _unreadable;

  Future<ApiTokens?> read() async {
    if (_unreadable) return null;
    final String? raw;
    try {
      raw = await _storage.read(key: _key);
    } catch (_) {
      _unreadable = true;
      return null;
    }
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final ApiTokens tokens =
          ApiTokens.fromJson(Map<String, dynamic>.from(decoded));
      if (tokens.isEmpty) return null;
      return tokens;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(ApiTokens tokens) async {
    if (_unreadable) {
      throw StateError('API session key is unreadable; refusing to overwrite');
    }
    await _storage.write(key: _key, value: jsonEncode(tokens.toJson()));
  }

  Future<void> clear() async {
    if (_unreadable) return;
    await _storage.delete(key: _key);
  }
}
