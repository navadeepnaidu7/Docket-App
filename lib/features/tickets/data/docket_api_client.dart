import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../domain/pass_catalog.dart';
import '../domain/pass_ingest.dart';
import '../domain/pass_status.dart';
import 'api_session_store.dart';
import 'remote_pass_repository.dart';

/// HTTP surface used by [RemotePassRepository] and pass ingest.
abstract class DocketApi {
  Future<PassListResponse> fetchPasses({TicketStatus? status});

  Future<WalletPassItem?> fetchPassById(String id);

  Future<String> extractFile({
    required List<int> bytes,
    required String filename,
    required String mimeType,
    required String categoryHint,
  });

  Future<String> createFromPnr(String pnr);
}

class DocketApiClient implements DocketApi {
  DocketApiClient({
    required this.baseUrl,
    required this.session,
    this.devIdToken = '',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final ApiSessionStore session;
  final String devIdToken;
  final http.Client _http;

  static const Duration _httpTimeout = Duration(seconds: 30);

  Future<T> _withTimeout<T>(Future<T> Function() operation) async {
    try {
      return await operation().timeout(_httpTimeout);
    } on TimeoutException {
      throw const PassIngestException(
        PassIngestCode.failed,
        'The request timed out. Check your connection and try again.',
      );
    }
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final String origin = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final Uri uri = Uri.parse('$origin$path');

    // Enforce HTTPS, allowing HTTP only for explicit loopback hosts in debug builds
    if (uri.scheme == 'http') {
      final String host = uri.host.toLowerCase();
      final bool isLoopback = host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '10.0.2.2' ||
          host == '[::1]';
      if (!kDebugMode || !isLoopback) {
        throw const PassIngestException(
          PassIngestCode.failed,
          'API must use HTTPS in production. Use a secure origin or run a debug build with a loopback address.',
        );
      }
    }

    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  @override
  Future<PassListResponse> fetchPasses({TicketStatus? status}) async {
    final http.Response res = await _authed(
      (Map<String, String> headers) => _withTimeout(
        () => _http.get(
          _uri(
            PassApiPaths.passes,
            status == null ? null : <String, String>{'status': status.toJson()},
          ),
          headers: headers,
        ),
      ),
    );
    _throwIfFailed(res, fallback: 'Could not load passes.');
    final Object? body = jsonDecode(res.body);
    if (body is! Map) {
      throw const PassIngestException(
        PassIngestCode.failed,
        'The server sent an unexpected passes response.',
      );
    }
    return PassListResponse.fromJson(Map<String, dynamic>.from(body));
  }

  @override
  Future<WalletPassItem?> fetchPassById(String id) async {
    final http.Response res = await _authed(
      (Map<String, String> headers) => _withTimeout(
        () => _http.get(
          _uri(PassApiPaths.passById(id)),
          headers: headers,
        ),
      ),
    );
    if (res.statusCode == 404) return null;
    _throwIfFailed(res, fallback: 'Could not load that pass.');
    final Object? body = jsonDecode(res.body);
    if (body is! Map) return null;
    try {
      return walletPassItemFromJson(Map<String, dynamic>.from(body));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> extractFile({
    required List<int> bytes,
    required String filename,
    required String mimeType,
    required String categoryHint,
  }) async {
    final http.Response res = await _authed((Map<String, String> headers) async {
      final http.MultipartRequest req = http.MultipartRequest(
        'POST',
        _uri(PassApiPaths.extract),
      );
      req.headers.addAll(headers);
      req.fields['category'] = categoryHint;
      req.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ),
      );
      return _withTimeout(() async {
        final http.StreamedResponse streamed = await _http.send(req);
        return http.Response.fromStream(streamed);
      });
    });
    _throwIfFailed(res, fallback: 'Could not read that ticket.');
    return _ticketIdFrom(res.body);
  }

  @override
  Future<String> createFromPnr(String pnr) async {
    final http.Response res = await _authed(
      (Map<String, String> headers) => _withTimeout(
        () => _http.post(
          _uri(PassApiPaths.tickets),
          headers: <String, String>{
            ...headers,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, String>{'pnr': pnr}),
        ),
      ),
    );
    _throwIfFailed(res, fallback: 'Could not add that PNR.');
    return _ticketIdFrom(res.body);
  }

  Future<http.Response> _authed(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    ApiTokens tokens = await _ensureTokens();
    http.Response res = await send(_headers(tokens.accessToken));
    if (res.statusCode != 401) return res;
    tokens = await _refresh(tokens);
    return send(_headers(tokens.accessToken));
  }

  Map<String, String> _headers(String access) => <String, String>{
        'Authorization': 'Bearer $access',
        'Accept': 'application/json',
      };

  Future<ApiTokens> _ensureTokens() async {
    final ApiTokens? stored = await session.read();
    if (stored != null && stored.accessToken.isNotEmpty) return stored;
    if (devIdToken.trim().isEmpty) {
      throw const PassIngestException(
        PassIngestCode.needsAuth,
        'Sign in first. In debug, set a dev auth token under Settings → Developer.',
      );
    }
    return _exchange(devIdToken.trim());
  }

  Future<ApiTokens> _exchange(String idToken) async {
    final http.Response res = await _withTimeout(
      () => _http.post(
        _uri(PassApiPaths.authGoogle),
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'idToken': idToken,
          'deviceLabel': 'docket-app',
        }),
      ),
    );
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const PassIngestException(
        PassIngestCode.needsAuth,
        'The server rejected the auth token.',
      );
    }
    _throwIfFailed(res, fallback: 'Could not sign in to the server.');
    final ApiTokens tokens = _tokensFrom(res.body);
    await session.write(tokens);
    return tokens;
  }

  Future<ApiTokens> _refresh(ApiTokens current) async {
    if (current.refreshToken.isEmpty) {
      await session.clear();
      throw const PassIngestException(
        PassIngestCode.needsAuth,
        'Session expired. Sign in again.',
      );
    }
    final http.Response res = await _withTimeout(
      () => _http.post(
        _uri(PassApiPaths.authRefresh),
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(<String, String>{'refreshToken': current.refreshToken}),
      ),
    );
    if (res.statusCode == 401) {
      await session.clear();
      throw const PassIngestException(
        PassIngestCode.needsAuth,
        'Session expired. Sign in again.',
      );
    }
    _throwIfFailed(res, fallback: 'Could not refresh the session.');
    final ApiTokens tokens = _tokensFrom(res.body);
    await session.write(tokens);
    return tokens;
  }

  ApiTokens _tokensFrom(String body) {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const PassIngestException(
        PassIngestCode.failed,
        'The server sent an unexpected auth response.',
      );
    }
    final ApiTokens tokens =
        ApiTokens.fromJson(Map<String, dynamic>.from(decoded));
    if (tokens.isEmpty) {
      throw const PassIngestException(
        PassIngestCode.failed,
        'The server sent an empty session.',
      );
    }
    return tokens;
  }

  String _ticketIdFrom(String body) {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const PassIngestException(
        PassIngestCode.failed,
        'The server sent an unexpected ticket response.',
      );
    }
    final String id = decoded['id']?.toString() ?? '';
    if (id.isEmpty) {
      throw const PassIngestException(
        PassIngestCode.failed,
        'The server did not return a ticket id.',
      );
    }
    return id;
  }

  void _throwIfFailed(http.Response res, {required String fallback}) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    if (res.statusCode == 401) {
      throw const PassIngestException(
        PassIngestCode.needsAuth,
        'Sign in first. In debug, set a dev auth token under Settings → Developer.',
      );
    }
    if (res.statusCode == 413) {
      throw const PassIngestException(
        PassIngestCode.fileTooLarge,
        'That file is larger than the 12 MB upload limit.',
      );
    }
    if (res.statusCode == 429) {
      throw _rateLimited(res);
    }
    throw PassIngestException(
      PassIngestCode.failed,
      _errorMessage(res, fallback),
    );
  }

  PassIngestException _rateLimited(http.Response res) {
    int? retryAfter = int.tryParse(res.headers['retry-after'] ?? '');
    String? window;
    try {
      final Object? decoded = jsonDecode(res.body);
      if (decoded is Map) {
        retryAfter ??= (decoded['retryAfterSeconds'] is num)
            ? (decoded['retryAfterSeconds'] as num).round()
            : int.tryParse(decoded['retryAfterSeconds']?.toString() ?? '');
        window = decoded['window']?.toString();
      }
    } catch (_) {}
    final String when;
    if (retryAfter != null && retryAfter > 0) {
      final int minutes = (retryAfter / 60).ceil();
      when = minutes <= 1 ? 'in a minute' : 'in about $minutes minutes';
    } else if (window == 'day') {
      when = 'tomorrow';
    } else {
      when = 'later';
    }
    return PassIngestException(
      PassIngestCode.rateLimited,
      'You have hit the scan limit. Try again $when.',
      retryAfterSeconds: retryAfter,
      window: window,
    );
  }

  String _errorMessage(http.Response res, String fallback) {
    try {
      final Object? decoded = jsonDecode(res.body);
      if (decoded is Map) {
        final String? error = decoded['error']?.toString();
        if (error != null && error.trim().isNotEmpty) return error.trim();
      }
    } catch (_) {}
    return fallback;
  }
}
