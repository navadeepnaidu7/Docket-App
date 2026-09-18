import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dev/dev_config.dart';
import '../../../core/dev/dev_flags_provider.dart';
import '../../tickets/application/api_providers.dart';
import '../../tickets/data/api_session_store.dart';
import '../../tickets/data/docket_api_client.dart';
import '../../tickets/domain/pass_ingest.dart';
import 'google_auth_gateway.dart';

/// Account session for Settings / membership card.
@immutable
class AuthSession {
  const AuthSession({
    required this.isSignedIn,
    this.id,
    this.publicId,
    this.displayName,
    this.email,
    this.avatarUrl,
    this.joinedAt,
    this.photoBase64,
  });

  static const AuthSession signedOut = AuthSession(isSignedIn: false);

  /// Demo identity for signed-in UI previews (Developer → Mock signed in).
  static final AuthSession demo = AuthSession(
    isSignedIn: true,
    publicId: '4377',
    displayName: 'Alex Rivera',
    email: 'alex.rivera@gmail.com',
    joinedAt: DateTime.utc(2026, 7, 15),
  );

  final bool isSignedIn;
  final String? id;
  final String? publicId;
  final String? displayName;
  final String? email;
  final String? avatarUrl;
  final DateTime? joinedAt;

  /// Optional account photo (e.g. Google avatar), base64-encoded.
  ///
  /// Stored for a future decision on when to show it. The dashboard profile
  /// control always paints the membership mesh today and must not read this.
  final String? photoBase64;

  String get joinedLabel {
    final DateTime? at = joinedAt;
    if (at == null) return '';
    const List<String> months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final DateTime local = at.toLocal();
    return '${months[local.month - 1]} ${local.year}';
  }

  String get membershipNumber {
    final String? raw = publicId?.trim();
    if (raw == null || raw.isEmpty) return '';
    return '#$raw';
  }

  factory AuthSession.fromUser(ApiUser user) {
    return AuthSession(
      isSignedIn: user.id.isNotEmpty,
      id: user.id,
      publicId: user.publicId,
      displayName: user.displayName,
      email: user.email,
      avatarUrl: user.avatarUrl,
      joinedAt: user.joinedAt,
    );
  }

  AuthSession copyWith({
    bool? isSignedIn,
    String? id,
    String? publicId,
    String? displayName,
    String? email,
    String? avatarUrl,
    DateTime? joinedAt,
    String? photoBase64,
    bool clearPhoto = false,
    bool clearAvatar = false,
  }) {
    return AuthSession(
      isSignedIn: isSignedIn ?? this.isSignedIn,
      id: id ?? this.id,
      publicId: publicId ?? this.publicId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      joinedAt: joinedAt ?? this.joinedAt,
      photoBase64: clearPhoto ? null : (photoBase64 ?? this.photoBase64),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSession &&
          isSignedIn == other.isSignedIn &&
          id == other.id &&
          publicId == other.publicId &&
          displayName == other.displayName &&
          email == other.email &&
          avatarUrl == other.avatarUrl &&
          joinedAt == other.joinedAt &&
          photoBase64 == other.photoBase64;

  @override
  int get hashCode => Object.hash(
        isSignedIn,
        id,
        publicId,
        displayName,
        email,
        avatarUrl,
        joinedAt,
        photoBase64,
      );
}

class AuthControllerState {
  const AuthControllerState({
    required this.session,
    this.busy = false,
  });

  static const AuthControllerState signedOut = AuthControllerState(
    session: AuthSession.signedOut,
  );

  final AuthSession session;
  final bool busy;

  AuthControllerState copyWith({
    AuthSession? session,
    bool? busy,
  }) {
    return AuthControllerState(
      session: session ?? this.session,
      busy: busy ?? this.busy,
    );
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthControllerState>((Ref ref) {
  return AuthController(ref);
});

/// Effective account session for Settings / membership card.
///
/// A live Google session wins. The Developer mock is only a preview when
/// nobody is actually signed in.
final authSessionProvider = Provider<AuthSession>((Ref ref) {
  final AuthSession real =
      ref.watch(authControllerProvider.select((AuthControllerState s) => s.session));
  if (real.isSignedIn) return real;
  final bool mockSignedIn = ref.watch(devFlagsProvider).mockSignedIn;
  if (mockSignedIn && DevConfig.allowRuntimeOverrides) {
    return AuthSession.demo;
  }
  return AuthSession.signedOut;
});

class AuthController extends StateNotifier<AuthControllerState> {
  AuthController(this._ref) : super(AuthControllerState.signedOut) {
    _hydrate();
  }

  final Ref _ref;

  Future<void> _hydrate() async {
    final ApiSessionStore store = _ref.read(apiSessionStoreProvider);
    final StoredApiSession? stored = await store.readSession();
    if (!mounted) return;
    if (stored == null || stored.tokens.isEmpty) return;
    final ApiUser? cached = stored.user;
    if (cached != null && !cached.isEmpty) {
      state = state.copyWith(session: AuthSession.fromUser(cached));
    }
    final DocketApiClient? api = _ref.read(docketApiClientProvider);
    if (api == null) return;
    try {
      final ApiUser user = await api.fetchMe();
      if (!mounted) return;
      state = state.copyWith(session: AuthSession.fromUser(user));
    } on PassIngestException catch (e) {
      if (e.code == PassIngestCode.needsAuth) {
        await store.clear();
        if (!mounted) return;
        state = AuthControllerState.signedOut;
      }
    } catch (_) {
      // Keep the cached snapshot when the network is down.
    }
  }

  /// Returns `true` on success, `false` if the user cancelled.
  Future<bool> signInWithGoogle() async {
    if (state.busy) return false;
    state = state.copyWith(busy: true);
    if (!_ref.read(googleSignInConfiguredProvider)) {
      return _signInWithDevBypass();
    }
    try {
      final DocketApiClient? api = _ref.read(docketApiClientProvider);
      if (api == null) {
        throw const GoogleAuthFailure(
          'Set an API URL under Settings → Developer first.',
        );
      }
      final String? idToken =
          await _ref.read(googleAuthGatewayProvider).signIn();
      if (idToken == null) {
        if (mounted) state = state.copyWith(busy: false);
        return false;
      }
      final ApiUser user = await api.loginWithGoogle(idToken);
      if (!mounted) return false;
      state = AuthControllerState(
        session: AuthSession.fromUser(user),
      );
      return true;
    } on GoogleAuthFailure {
      if (mounted) state = state.copyWith(busy: false);
      rethrow;
    } on PassIngestException catch (e) {
      if (mounted) state = state.copyWith(busy: false);
      throw GoogleAuthFailure(e.message);
    } catch (_) {
      if (mounted) state = state.copyWith(busy: false);
      throw const GoogleAuthFailure('Could not sign in. Try again.');
    }
  }

  /// Debug / staging: exchange the Developer bypass token, or preview the card.
  Future<bool> _signInWithDevBypass() async {
    if (!DevConfig.allowRuntimeOverrides) {
      if (mounted) state = state.copyWith(busy: false);
      throw const GoogleAuthFailure(
        'Google Sign-In is not configured. Add a Web client ID as '
        'GOOGLE_SERVER_CLIENT_ID.',
      );
    }
    final String token = _ref.read(devFlagsProvider).devAuthIdToken.trim();
    if (token.isEmpty) {
      await _ref.read(devFlagsProvider.notifier).setMockSignedIn(true);
      if (mounted) state = state.copyWith(busy: false);
      return true;
    }
    final DocketApiClient? api = _ref.read(docketApiClientProvider);
    if (api == null) {
      if (mounted) state = state.copyWith(busy: false);
      throw const GoogleAuthFailure(
        'Set an API URL under Settings → Developer first.',
      );
    }
    try {
      final ApiUser user = await api.loginWithGoogle(token);
      if (!mounted) return false;
      state = AuthControllerState(session: AuthSession.fromUser(user));
      return true;
    } on PassIngestException catch (e) {
      if (mounted) state = state.copyWith(busy: false);
      throw GoogleAuthFailure(e.message);
    } catch (_) {
      if (mounted) state = state.copyWith(busy: false);
      throw const GoogleAuthFailure('Could not sign in. Try again.');
    }
  }

  Future<void> signOut() async {
    if (state.busy) return;
    state = state.copyWith(busy: true);
    final DocketApiClient? api = _ref.read(docketApiClientProvider);
    try {
      await api?.logout();
    } catch (_) {}
    try {
      await _ref.read(googleAuthGatewayProvider).signOut();
    } catch (_) {}
    await _ref.read(devFlagsProvider.notifier).setMockSignedIn(false);
    if (!mounted) return;
    state = AuthControllerState.signedOut;
  }
}

/// Convenience: flip mock signed-in (no-op when runtime overrides are locked).
Future<void> setMockSignedIn(WidgetRef ref, bool signedIn) {
  return ref.read(devFlagsProvider.notifier).setMockSignedIn(signedIn);
}
