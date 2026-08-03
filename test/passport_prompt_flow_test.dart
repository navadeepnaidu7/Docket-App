import 'package:flutter_test/flutter_test.dart';

import 'package:docket/features/passport/presentation/flow/passport_prompt_flow.dart';
import 'package:docket/shared/prompt_flow/prompt_flow_controller.dart';
import 'package:docket/shared/prompt_flow/prompt_step.dart';

PromptFlowController _flow({required bool isEPassport}) =>
    PromptFlowController(
      steps: buildPassportFlow(),
      initialFlags: <String, bool>{PassportFlag.isEPassport: isEPassport},
    );

List<String> _ids(PromptFlowController c) =>
    c.visibleSteps.map((PromptStep s) => s.id).toList();

/// Picks a route and advances off the method step, mirroring what the screen's
/// option tiles do.
void _choose(PromptFlowController c, PromptPath path) {
  c.setPath(path);
  c.next();
}

void main() {
  group('chip step visibility', () {
    // The old screen asked "E-Passport or Regular?" in a sheet and then never
    // read the answer, so it offered a chip read to passports that have none.
    test('a regular passport never sees the chip step', () {
      final PromptFlowController c = _flow(isEPassport: false);
      c.setPath(PromptPath.chip);

      expect(_ids(c), isNot(contains(PassportField.nfcRead)));
    });

    test('an e-passport sees it only on the chip route', () {
      final PromptFlowController c = _flow(isEPassport: true);

      c.setPath(PromptPath.manual);
      expect(_ids(c), isNot(contains(PassportField.nfcRead)));

      c.setPath(PromptPath.chip);
      expect(_ids(c), contains(PassportField.nfcRead));
    });

    // The chip route should collect the three values BAC needs and nothing
    // else. Name, nationality and sex are all carried by DG1, so asking for
    // them first is collecting data we are about to read off the document.
    test('the chip route asks for only the three BAC fields', () {
      final PromptFlowController c = _flow(isEPassport: true);
      c.setPath(PromptPath.chip);

      expect(_ids(c), <String>[
        PassportField.method,
        PassportField.passportNumber,
        PassportField.dateOfBirth,
        PassportField.expiryDate,
        PassportField.nfcRead,
        PassportField.review,
      ]);
    });

    test('dropping to manual after a failed read restores the rest', () {
      final PromptFlowController c = _flow(isEPassport: true);
      c.setPath(PromptPath.chip);
      expect(_ids(c), isNot(contains(PassportField.name)));

      // What _recover(continueWithout) does.
      c.setPath(PromptPath.manual);
      expect(_ids(c), contains(PassportField.name));
      expect(_ids(c), contains(PassportField.nationality));
    });

    test('the chip read comes after all three BAC fields', () {
      final PromptFlowController c = _flow(isEPassport: true);
      c.setPath(PromptPath.chip);
      final List<String> ids = _ids(c);

      expect(ids.indexOf(PassportField.nfcRead),
          greaterThan(ids.indexOf(PassportField.passportNumber)));
      expect(ids.indexOf(PassportField.nfcRead),
          greaterThan(ids.indexOf(PassportField.dateOfBirth)));
      expect(ids.indexOf(PassportField.nfcRead),
          greaterThan(ids.indexOf(PassportField.expiryDate)));
    });
  });

  // The screen this replaces rendered passport number, DOB and expiry twice,
  // on the same controllers, under two headings, both saying "step 2 of 3".
  test('no field is asked twice on any route', () {
    for (final PromptPath path in PromptPath.values) {
      final PromptFlowController c = _flow(isEPassport: true);
      c.setPath(path);
      final List<String> ids = _ids(c);

      expect(ids.toSet().length, ids.length, reason: 'duplicate on $path');
    }
  });

  group('validation gates', () {
    test('the flow will not advance past an empty passport number', () {
      final PromptFlowController c = _flow(isEPassport: false);
      _choose(c, PromptPath.manual);

      c.setValue(PassportField.name, 'Rahul Sharma');
      c.next();
      expect(c.current.id, PassportField.passportNumber);

      expect(c.next(), isFalse);
      expect(c.currentError, isNotNull);
    });

    test('a malformed passport number is rejected', () {
      final PromptFlowController c = _flow(isEPassport: false);
      _choose(c, PromptPath.manual);
      c.setValue(PassportField.name, 'Rahul Sharma');
      c.next();

      c.setValue(PassportField.passportNumber, 'AB12');
      expect(c.next(), isFalse);

      c.setValue(PassportField.passportNumber, 'Z3456789');
      expect(c.next(), isTrue);
    });

    test('expiry is checked against the date of birth', () {
      final PromptFlowController c = _flow(isEPassport: false);
      _choose(c, PromptPath.manual);
      c.setValue(PassportField.dateOfBirth, '1994-03-12');
      c.setValue(PassportField.expiryDate, '1990-01-01');

      final PromptStep expiry = c.visibleSteps
          .firstWhere((PromptStep s) => s.id == PassportField.expiryDate);

      expect(expiry.validate!('1990-01-01', c.state), isNotNull);
    });
  });

  test('a full manual walkthrough reaches review', () {
    final PromptFlowController c = _flow(isEPassport: false);
    _choose(c, PromptPath.manual);

    c.setValue(PassportField.name, 'Rahul Sharma');
    expect(c.next(), isTrue);
    c.setValue(PassportField.passportNumber, 'Z3456789');
    expect(c.next(), isTrue);
    c.setValue(PassportField.dateOfBirth, '1994-03-12');
    expect(c.next(), isTrue);
    c.setValue(PassportField.expiryDate, '2032-09-04');
    expect(c.next(), isTrue);
    c.setValue(PassportField.nationality, 'IND');
    expect(c.next(), isTrue);
    c.setValue(PassportField.gender, 'M');
    expect(c.next(), isTrue);

    expect(c.current.id, PassportField.review);
    expect(c.progress, 1.0);
  });

  group('normaliseGender', () {
    // JMRTD reports MALE/FEMALE/UNKNOWN and the MRZ carries M/F. Both were
    // written to the same field, so a record's sex was stored in one of two
    // incompatible encodings depending on how it was added.
    test('collapses both encodings to one', () {
      expect(normaliseGender('MALE'), 'M');
      expect(normaliseGender('M'), 'M');
      expect(normaliseGender('FEMALE'), 'F');
      expect(normaliseGender('F'), 'F');
    });

    test('unknown becomes X, empty stays empty', () {
      expect(normaliseGender('UNKNOWN'), 'X');
      expect(normaliseGender(''), '');
    });
  });
}
