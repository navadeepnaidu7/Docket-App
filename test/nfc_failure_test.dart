import 'package:flutter_test/flutter_test.dart';

import 'package:docket/features/nfc/domain/nfc_failure.dart';

void main() {
  // Every code the platform channel can emit used to collapse into one
  // "please try again" whose only action re-ran the identical failing call.
  test('every platform code maps to a distinct, actionable failure', () {
    const List<String> codes = <String>[
      'BAC_FAILED',
      'INVALID_ARGS',
      'ISO_DEP_NOT_SUPPORTED',
      'NFC_UNAVAILABLE',
      'BUSY',
      'NFC_READ_ERROR',
    ];

    final Set<String> titles = <String>{};
    for (final String code in codes) {
      final NfcFailure f = NfcFailure.fromCode(code);
      expect(f.title, isNotEmpty, reason: '$code needs a title');
      expect(f.body, isNotEmpty, reason: '$code needs an explanation');
      expect(f.primary, isNot(NfcRecovery.none), reason: '$code needs an exit');
      titles.add(f.title);
    }

    expect(titles.length, codes.length, reason: 'titles must be distinguishable');
  });

  test('a bad BAC triple offers to fix the details, not a blind retry', () {
    final NfcFailure f = NfcFailure.fromCode('BAC_FAILED');
    expect(f.primary, NfcRecovery.fixDetails);
  });

  test('a second BAC failure offers an escape hatch', () {
    final NfcFailure f = NfcFailure.fromCode('BAC_FAILED', attempt: 2);
    expect(f.secondary, NfcRecovery.continueWithout);
    expect(f.body, contains('nine'));
  });

  test('NFC switched off routes to settings', () {
    expect(
      NfcFailure.fromCode('NFC_UNAVAILABLE').primary,
      NfcRecovery.openSettings,
    );
    expect(NfcFailure.fromCode('UNAVAILABLE').primary, NfcRecovery.openSettings);
  });

  test('a non-ICAO tag does not suggest retrying forever', () {
    expect(
      NfcFailure.fromCode('ISO_DEP_NOT_SUPPORTED').primary,
      NfcRecovery.continueWithout,
    );
  });

  test('cancellation is silent', () {
    final NfcFailure f = NfcFailure.fromCode('CANCELLED');
    expect(f.isSilent, isTrue);
    expect(f.primary, NfcRecovery.none);
  });

  test('an unknown code still produces something usable', () {
    final NfcFailure f = NfcFailure.fromCode('SOMETHING_NEW');
    expect(f.title, isNotEmpty);
    expect(f.primary, isNot(NfcRecovery.none));
  });
}
