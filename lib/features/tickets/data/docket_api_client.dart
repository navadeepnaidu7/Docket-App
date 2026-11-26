import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../application/ticket_code_scanner.dart';
import '../domain/calendar_import.dart';
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
    ScannedTicketCode? code,
    // Boarding passes after [code]: one per further flight on the document.
    List<ScannedTicketCode> moreCodes = const <ScannedTicketCode>[],
    // Completes a calendar-imported pass that lacked details, in place.
    String? attachToPassId,
  });

  Future<String> createFromPnr(String pnr);

  /// `DELETE /v1/passes/{id}`. A 404 is success — the row is already gone.
  Future<void> deletePass(String id);
}

abstract interface class TrainJourneyApi {
  Future<void> refreshTrainJourney(String id);
}

/// Google Calendar link (`/v1/integrations/google-calendar`). The app never sees a Google
/// token: it only opens the consent URL the server mints and reads status back.
abstract interface class CalendarImportApi {
  Future<CalendarConnectionStatus> fetchCalendarStatus();

  /// Returns the Google consent URL for this signed-in user.
  Future<Uri> startCalendarConnect();

  Future<CalendarConnectionStatus> requestCalendarSync();

  Future<void> disconnectCalendar();
}

class DocketApiClient implements DocketApi, TrainJourneyApi, CalendarImportApi {
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

  Future<void> registerDevice({
    required String token,
    required String timezone,
  }) async {
    await _notificationRequest('POST', '/v1/devices', {
      'token': token,
      'platform': 'android',
      'deviceLabel': 'Docket Android',
      'timezone': timezone,
    });
  }

  Future<void> unregisterDevice(String token) async {
    await _notificationRequest('DELETE', '/v1/devices', {'token': token});
  }

  Future<Map<String, dynamic>> fetchNotificationPreferences() async => _jsonMap(
    (await _notificationRequest('GET', '/v1/me/notification-preferences')).body,
  );

  Future<void> putNotificationPreferences(
    Map<String, dynamic> preferences,
  ) async {
    await _notificationRequest(
      'PUT',
      '/v1/me/notification-preferences',
      preferences,
    );
  }

  /// Local cleanup belongs to AuthController and runs only after a confirmed 204.
  Future<void> deleteAccount() async {
    final before = await session.readSession();
    try {
      final response = await _notificationRequest('DELETE', '/v1/me', {
        'confirm': 'DELETE',
      });
      if (response.statusCode != 204) {
        throw const PassIngestException(
          PassIngestCode.failed,
          'Could not delete your account. Try again.',
        );
      }
    } catch (_) {
      // Authentication retry may clear expired credentials. Deletion failure
      // must preserve the phone's session and identity as well as its passes.
      if (before != null) {
        await session.write(
          before.tokens,
          user: before.user,
          developerSession: before.developerSession,
        );
      }
      rethrow;
    }
  }

  Future<http.Response> _notificationRequest(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final response = await _authed(
      (headers) => _withTimeout(() {
        final h = {...headers, 'Content-Type': 'application/json'};
        return switch (method) {
          'GET' => _http.get(_uri(path), headers: h),
          'POST' => _http.post(_uri(path), headers: h, body: jsonEncode(body)),
          'PUT' => _http.put(_uri(path), headers: h, body: jsonEncode(body)),
          _ => _http.delete(_uri(path), headers: h, body: jsonEncode(body)),
        };
      }),
    );
    _throwIfFailed(
      response,
      fallback: 'Could not complete the account request. Try again.',
    );
    return response;
  }

  @override
  Future<void> refreshTrainJourney(String id) async {
    final response = await _authed(
      (headers) => _withTimeout(
        () => _http.post(_uri('/tickets/$id/refresh'), headers: headers),
      ),
    );
    _throwIfFailed(
      response,
      fallback: 'Railway details are unavailable. Please try again later.',
    );
  }

  @override
  Future<CalendarConnectionStatus> fetchCalendarStatus() async {
    final http.Response res = await _authed(
      (Map<String, String> headers) => _withTimeout(
        () => _http.get(_uri(PassApiPaths.googleCalendar), headers: headers),
      ),
    );
    _throwIfCalendarFailed(res);
    return CalendarConnectionStatus.fromJson(_jsonMap(res.body));
  }

  @override
  Future<Uri> startCalendarConnect() async {
    final http.Response res = await _authed(
      (Map<String, String> headers) => _withTimeout(
        () => _http.post(
          _uri(PassApiPaths.googleCalendarConnect),
          headers: headers,
        ),
      ),
    );
    _throwIfCalendarFailed(res);
    final Uri? url = Uri.tryParse(
      _jsonMap(res.body)['authorizationUrl']?.toString() ?? '',
    );
    // Only ever hand Google's own consent page to the browser.
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'accounts.google.com') {
      throw const CalendarImportException(
        'failed',
        'The server sent an unexpected sign-in link.',
      );
    }
    return url;
  }

  @override
  Future<CalendarConnectionStatus> requestCalendarSync() async {
    final http.Response res = await _authed(
      (Map<String, String> headers) => _withTimeout(
        () =>
            _http.post(_uri(PassApiPaths.googleCalendarSync), headers: headers),
      ),
    );
    _throwIfCalendarFailed(res);
    return CalendarConnectionStatus.fromJson(_jsonMap(res.body));
  }

  @override
  Future<void> disconnectCalendar() async {
    final http.Response res = await _authed(
      (Map<String, String> headers) => _withTimeout(
        () => _http.delete(_uri(PassApiPaths.googleCalendar), headers: headers),
      ),
    );
    _throwIfCalendarFailed(res);
  }

  Map<String, dynamic> _jsonMap(String body) {
    final Object? decoded = body.isEmpty ? null : jsonDecode(body);
    if (decoded is! Map) {
      throw const CalendarImportException(
        'failed',
        'The server sent an unexpected calendar response.',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _throwIfCalendarFailed(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    if (res.statusCode == 401) {
      _throwIfFailed(res, fallback: '');
    }
    String code = 'failed';
    String? message;
    int? retryAfter = int.tryParse(res.headers['retry-after'] ?? '');
    try {
      final Object? decoded = jsonDecode(res.body);
      if (decoded is Map) {
        code = decoded['code']?.toString() ?? code;
        message = decoded['error']?.toString();
        retryAfter ??= (decoded['retryAfterSeconds'] as num?)?.toInt();
      }
    } catch (_) {}
    throw CalendarImportException(
      code,
      code == 'failed' && (message == null || message.isEmpty)
          ? 'Calendar request failed. Try again.'
          : calendarReasonCopy(code) == calendarReasonCopy(null)
          ? (message ?? calendarReasonCopy(null))
          : calendarReasonCopy(code),
      retryAfterSeconds: retryAfter,
    );
  }

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
      final bool isLoopback =
          host == 'localhost' ||
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
        () => _http.get(_uri(PassApiPaths.passById(id)), headers: headers),
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
    ScannedTicketCode? code,
    List<ScannedTicketCode> moreCodes = const <ScannedTicketCode>[],
    String? attachToPassId,
  }) async {
    final http.Response res = await _authed((
      Map<String, String> headers,
    ) async {
      final http.MultipartRequest req = http.MultipartRequest(
        'POST',
        _uri(PassApiPaths.extract),
      );
      req.headers.addAll(headers);
      req.fields['category'] = categoryHint;
      if (attachToPassId != null) req.fields['attachToPassId'] = attachToPassId;
      // The code decoded on device, when there was one. Sent as fields rather
      // than folded into the file so the server stores it verbatim instead of
      // asking a model to read a bitmap it cannot read.
      if (code != null) {
        req.fields['codeFormat'] = code.format.wire;
        final String? payload = code.payload;
        final String? payloadBase64 = code.payloadBase64;
        if (payload != null) req.fields['codePayload'] = payload;
        if (payloadBase64 != null) {
          req.fields['codePayloadBase64'] = payloadBase64;
        }
      }
      // Every code, the first included, so the server can give each flight
      // of an itinerary its own boarding pass. Older servers ignore it.
      if (code != null && moreCodes.isNotEmpty) {
        req.fields['codes'] = jsonEncode(<Map<String, String>>[
          for (final ScannedTicketCode c in <ScannedTicketCode>[
            code,
            ...moreCodes,
          ])
            <String, String>{
              'format': c.format.wire,
              if (c.payload != null) 'payload': c.payload!,
              if (c.payloadBase64 != null) 'payloadBase64': c.payloadBase64!,
            },
        ]);
      }
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
  Future<void> deletePass(String id) async {
    final http.Response res = await _authed(
      (Map<String, String> headers) => _withTimeout(
        () => _http.delete(_uri(PassApiPaths.passById(id)), headers: headers),
      ),
    );
    if (res.statusCode == 404) return;
    _throwIfFailed(res, fallback: 'Could not remove that pass.');
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
      throw PassIngestException(
        PassIngestCode.needsAuth,
        kDebugMode
            ? 'Sign in first. In debug, set a dev auth token under Settings → Developer.'
            : 'Sign in with Google first.',
      );
    }
    return _exchange(devIdToken.trim());
  }

  /// Exchange a Google ID token for a Docket session.
  Future<ApiUser> loginWithGoogle(
    String idToken, {
    bool developerSession = false,
  }) async {
    final _AuthPayload payload = await _postGoogle(idToken);
    await session.write(
      payload.tokens,
      user: payload.user,
      developerSession: developerSession,
    );
    return payload.user;
  }

  Future<ApiUser> fetchMe() async {
    final http.Response res = await _authed(
      (Map<String, String> headers) => _withTimeout(
        () => _http.get(_uri(PassApiPaths.me), headers: headers),
      ),
    );
    _throwIfFailed(res, fallback: 'Could not load your account.');
    final ApiUser user = _userFrom(res.body);
    final ApiTokens? tokens = await session.read();
    if (tokens != null) {
      await session.write(tokens, user: user);
    }
    return user;
  }

  Future<void> logout({bool all = false}) async {
    final StoredApiSession? stored = await session.readSession();
    if (stored != null && !stored.tokens.isEmpty) {
      try {
        await _authed(
          (Map<String, String> headers) => _withTimeout(
            () => _http.post(
              _uri(PassApiPaths.authLogout),
              headers: <String, String>{
                ...headers,
                'Content-Type': 'application/json',
              },
              body: jsonEncode(<String, Object>{
                'refreshToken': stored.tokens.refreshToken,
                'all': all,
              }),
            ),
          ),
        );
      } catch (_) {
        // Local sign-out still has to happen if the server is unreachable.
      }
    }
    await session.clear();
  }

  Future<ApiTokens> _exchange(String idToken) async {
    final _AuthPayload payload = await _postGoogle(idToken);
    await session.write(
      payload.tokens,
      user: payload.user,
      developerSession: true,
    );
    return payload.tokens;
  }

  Future<_AuthPayload> _postGoogle(String idToken) async {
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
        'The server rejected the Google sign-in.',
      );
    }
    _throwIfFailed(res, fallback: 'Could not sign in to the server.');
    return _authPayloadFrom(res.body);
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
        body: jsonEncode(<String, String>{
          'refreshToken': current.refreshToken,
        }),
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

  ApiTokens _tokensFrom(String body) => _authPayloadFrom(body).tokens;

  _AuthPayload _authPayloadFrom(String body) {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const PassIngestException(
        PassIngestCode.failed,
        'The server sent an unexpected auth response.',
      );
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);
    final ApiTokens tokens = ApiTokens.fromJson(map);
    if (tokens.isEmpty) {
      throw const PassIngestException(
        PassIngestCode.failed,
        'The server sent an empty session.',
      );
    }
    final Object? userRaw = map['user'];
    if (userRaw is! Map) {
      throw const PassIngestException(
        PassIngestCode.failed,
        'The server sent an auth response without a user.',
      );
    }
    final ApiUser user = ApiUser.fromJson(Map<String, dynamic>.from(userRaw));
    if (user.isEmpty) {
      throw const PassIngestException(
        PassIngestCode.failed,
        'The server sent an empty user.',
      );
    }
    return _AuthPayload(tokens: tokens, user: user);
  }

  ApiUser _userFrom(String body) {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const PassIngestException(
        PassIngestCode.failed,
        'The server sent an unexpected account response.',
      );
    }
    final ApiUser user = ApiUser.fromJson(Map<String, dynamic>.from(decoded));
    if (user.isEmpty) {
      throw const PassIngestException(
        PassIngestCode.failed,
        'The server sent an empty account.',
      );
    }
    return user;
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
      throw PassIngestException(
        PassIngestCode.needsAuth,
        kDebugMode
            ? 'Sign in first. In debug, set a dev auth token under Settings → Developer.'
            : 'Sign in with Google first.',
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

class _AuthPayload {
  const _AuthPayload({required this.tokens, required this.user});

  final ApiTokens tokens;
  final ApiUser user;
}
