import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dev/dev_config.dart';
import '../../../core/dev/dev_flags_provider.dart';

/// Placeholder account session for Settings UI.
///
/// Until real Google OAuth exists, [isSignedIn] is driven by
/// [DevFlags.mockSignedIn] (Developer toggle + Google button / Sign out).
@immutable
class AuthSession {
  const AuthSession({
    required this.isSignedIn,
    this.displayName,
    this.email,
    this.photoBase64,
  });

  static const AuthSession signedOut = AuthSession(isSignedIn: false);

  /// Demo identity for signed-in UI previews.
  static const AuthSession demo = AuthSession(
    isSignedIn: true,
    displayName: 'Alex Rivera',
    email: 'alex.rivera@gmail.com',
  );

  final bool isSignedIn;
  final String? displayName;
  final String? email;

  /// Optional account photo (e.g. Google avatar), base64-encoded.
  ///
  /// Stored for a future decision on when to show it. The dashboard profile
  /// control always paints the membership mesh today and must not read this.
  final String? photoBase64;

  AuthSession copyWith({
    bool? isSignedIn,
    String? displayName,
    String? email,
    String? photoBase64,
    bool clearPhoto = false,
  }) {
    return AuthSession(
      isSignedIn: isSignedIn ?? this.isSignedIn,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoBase64: clearPhoto ? null : (photoBase64 ?? this.photoBase64),
    );
  }
}

/// Effective account session for Settings / membership card.
final authSessionProvider = Provider<AuthSession>((Ref ref) {
  final bool mockSignedIn = ref.watch(devFlagsProvider).mockSignedIn;
  if (mockSignedIn && DevConfig.allowRuntimeOverrides) {
    return AuthSession.demo;
  }
  // Release / locked: always signed out until real auth ships.
  return AuthSession.signedOut;
});

/// Convenience: flip mock signed-in (no-op when runtime overrides are locked).
Future<void> setMockSignedIn(WidgetRef ref, bool signedIn) {
  return ref.read(devFlagsProvider.notifier).setMockSignedIn(signedIn);
}
