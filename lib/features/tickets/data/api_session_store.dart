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

/// Membership profile from `POST /v1/auth/google` / `GET /v1/me`.
class ApiUser {
  const ApiUser({
    required this.id,
    required this.publicId,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.joinedAt,
  });

  final String id;
  final String publicId;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final DateTime? joinedAt;

  bool get isEmpty => id.isEmpty;

  factory ApiUser.fromJson(Map<String, dynamic> json) {
    DateTime? joined;
    final String rawJoined = json['joinedAt']?.toString() ?? '';
    if (rawJoined.isNotEmpty) joined = DateTime.tryParse(rawJoined);
    return ApiUser(
      id: json['id']?.toString() ?? '',
      publicId: json['publicId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      email: _nonEmpty(json['email']?.toString()),
      avatarUrl: _nonEmpty(json['avatarUrl']?.toString()),
      joinedAt: joined,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'publicId': publicId,
        'displayName': displayName,
        if (email != null) 'email': email,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (joinedAt != null) 'joinedAt': joinedAt!.toUtc().toIso8601String(),
      };

  static String? _nonEmpty(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

class StoredApiSession {
  const StoredApiSession({required this.tokens, this.user});

  final ApiTokens tokens;
  final ApiUser? user;
}

/// Persists API tokens. Same Android options as [SecureDocumentStore]; a
/// failed read is treated as signed-out rather than wiping the key.
class ApiSessionStore {
  ApiSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(aOptions: kDocketAndroidOptions),
        _memory = null;

  /// In-memory store for tests. Does not touch the device keystore.
  ApiSessionStore.memory()
      : _storage = null,
        _memory = <String, String>{};

  static const String _key = 'docket_api_session_v1';

  final FlutterSecureStorage? _storage;
  final Map<String, String>? _memory;
  bool _unreadable = false;

  bool get isUnreadable => _unreadable;

  Future<ApiTokens?> read() async {
    final StoredApiSession? stored = await readSession();
    if (stored == null || stored.tokens.isEmpty) return null;
    return stored.tokens;
  }

  Future<StoredApiSession?> readSession() async {
    if (_unreadable) return null;
    final String? raw;
    try {
      final Map<String, String>? memory = _memory;
      raw = memory != null
          ? memory[_key]
          : await _storage!.read(key: _key);
    } catch (_) {
      _unreadable = true;
      return null;
    }
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);
      final ApiTokens tokens = ApiTokens.fromJson(map);
      if (tokens.isEmpty) return null;
      ApiUser? user;
      final Object? userRaw = map['user'];
      if (userRaw is Map) {
        user = ApiUser.fromJson(Map<String, dynamic>.from(userRaw));
        if (user.isEmpty) user = null;
      }
      return StoredApiSession(tokens: tokens, user: user);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(ApiTokens tokens, {ApiUser? user}) async {
    if (_unreadable) {
      throw StateError('API session key is unreadable; refusing to overwrite');
    }
    final ApiUser? nextUser = user ?? (await readSession())?.user;
    final Map<String, dynamic> payload = <String, dynamic>{
      ...tokens.toJson(),
      if (nextUser != null) 'user': nextUser.toJson(),
    };
    final String encoded = jsonEncode(payload);
    final Map<String, String>? memory = _memory;
    if (memory != null) {
      memory[_key] = encoded;
      return;
    }
    await _storage!.write(key: _key, value: encoded);
  }

  Future<void> clear() async {
    if (_unreadable) return;
    final Map<String, String>? memory = _memory;
    if (memory != null) {
      memory.remove(_key);
      return;
    }
    await _storage!.delete(key: _key);
  }
}
