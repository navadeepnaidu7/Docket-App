/// What the user can do next after a failed chip read.
enum NfcRecovery {
  /// Re-run the same read.
  retry,

  /// Jump back to the three BAC fields so they can be corrected.
  fixDetails,

  /// Abandon the chip and keep whatever has been entered so far.
  continueWithout,

  /// Open system settings (NFC is switched off).
  openSettings,

  /// No action — the flow handles it silently.
  none,
}

/// A chip-read failure, translated into something worth showing a person.
///
/// The platform channel reports six distinct error codes, but only two of them
/// used to be mapped; everything else — including the overwhelmingly common
/// "your BAC details are wrong" case — collapsed into a single "Failed to read
/// NFC chip. Please try again." whose only action re-ran the identical failing
/// call. Each code now carries its own explanation and a recovery that can
/// actually change the outcome.
class NfcFailure {
  const NfcFailure({
    required this.code,
    required this.title,
    required this.body,
    required this.primary,
    this.secondary = NfcRecovery.none,
  });

  final String code;
  final String title;
  final String body;
  final NfcRecovery primary;
  final NfcRecovery secondary;

  /// [attempt] is 1-based; the second consecutive BAC failure adds the
  /// `<`-padding hint and offers to skip the chip entirely.
  factory NfcFailure.fromCode(String code, {int attempt = 1}) {
    switch (code) {
      case 'BAC_FAILED':
        return NfcFailure(
          code: code,
          title: 'The chip did not unlock',
          body: attempt > 1
              ? 'That almost always means one of the three details is slightly '
                  'off. Some passports also need the number padded to nine '
                  'characters — we will try that too.'
              : 'That almost always means one of the three details is slightly '
                  'off. Check them against the photo page.',
          primary: NfcRecovery.fixDetails,
          secondary:
              attempt > 1 ? NfcRecovery.continueWithout : NfcRecovery.retry,
        );

      case 'INVALID_ARGS':
        return const NfcFailure(
          code: 'INVALID_ARGS',
          title: 'Some details are missing',
          body: 'The chip needs the passport number, date of birth and expiry '
              'date before it will unlock.',
          primary: NfcRecovery.fixDetails,
        );

      case 'ISO_DEP_NOT_SUPPORTED':
        return const NfcFailure(
          code: 'ISO_DEP_NOT_SUPPORTED',
          title: 'This chip cannot be read',
          body: 'Your phone made contact, but this is not an e-passport chip.',
          primary: NfcRecovery.continueWithout,
          secondary: NfcRecovery.retry,
        );

      case 'NFC_UNAVAILABLE':
      case 'UNAVAILABLE':
        return NfcFailure(
          code: code,
          title: 'NFC is switched off',
          body: 'Turn on NFC in system settings, then come back and try again.',
          primary: NfcRecovery.openSettings,
          secondary: NfcRecovery.continueWithout,
        );

      case 'BUSY':
        return const NfcFailure(
          code: 'BUSY',
          title: 'Another scan is running',
          body: 'Wait a moment for the previous read to finish.',
          primary: NfcRecovery.retry,
        );

      case 'CANCELLED':
        return const NfcFailure(
          code: 'CANCELLED',
          title: '',
          body: '',
          primary: NfcRecovery.none,
        );

      case 'NFC_READ_ERROR':
      default:
        return NfcFailure(
          code: code,
          title: 'The read was interrupted',
          body: 'Hold the phone still against the passport cover for a few '
              'seconds without moving it.',
          primary: NfcRecovery.retry,
          secondary: NfcRecovery.continueWithout,
        );
    }
  }

  /// True when the flow should handle this without showing anything.
  bool get isSilent => code == 'CANCELLED';

  /// True when retrying is worth doing with `<`-padded document number.
  bool get shouldTryPaddedNumber => code == 'BAC_FAILED';
}
