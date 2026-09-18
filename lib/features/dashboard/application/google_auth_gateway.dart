import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/dev/dev_config.dart';

/// Thrown when Google Sign-In cannot produce an ID token.
class GoogleAuthFailure implements Exception {
  const GoogleAuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Obtains a Google OpenID token for `POST /v1/auth/google`.
abstract class GoogleAuthGateway {
  /// Interactive sign-in. Returns `null` when the user cancels.
  Future<String?> signIn();

  Future<void> signOut();
}

final googleAuthGatewayProvider = Provider<GoogleAuthGateway>((Ref ref) {
  return PluginGoogleAuthGateway();
});

/// False until a Web client ID is baked in as `GOOGLE_SERVER_CLIENT_ID`.
///
/// Debug builds then keep the old Developer-token / mock-signed-in path
/// instead of opening the Google account picker.
final googleSignInConfiguredProvider = Provider<bool>((Ref ref) {
  return DevConfig.googleServerClientId.trim().isNotEmpty;
});

class PluginGoogleAuthGateway implements GoogleAuthGateway {
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final String serverClientId = DevConfig.googleServerClientId.trim();
    if (serverClientId.isEmpty) {
      throw const GoogleAuthFailure(
        'Google Sign-In is not configured. Add a Web client ID as '
        'GOOGLE_SERVER_CLIENT_ID.',
      );
    }
    final String iosClientId = DevConfig.googleIosClientId.trim();
    await GoogleSignIn.instance.initialize(
      serverClientId: serverClientId,
      clientId: iosClientId.isEmpty ? null : iosClientId,
    );
    _initialized = true;
  }

  @override
  Future<String?> signIn() async {
    await _ensureInitialized();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const GoogleAuthFailure(
        'Google Sign-In is not available on this device.',
      );
    }
    try {
      final GoogleSignInAccount account =
          await GoogleSignIn.instance.authenticate(
        scopeHint: const <String>['email', 'profile'],
      );
      final String? idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleAuthFailure(
          'Google did not return an ID token. Check the Web client ID.',
        );
      }
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      debugPrint('Google Sign-In failed: ${e.code} ${e.description}');
      throw GoogleAuthFailure(
        e.description?.trim().isNotEmpty == true
            ? e.description!.trim()
            : 'Google Sign-In failed.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
