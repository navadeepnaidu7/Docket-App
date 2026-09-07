import 'package:flutter_test/flutter_test.dart';

import 'package:docket/features/ids/domain/id_document.dart';
import 'package:docket/features/ids/presentation/flow/id_prompt_flow.dart';
import 'package:docket/shared/prompt_flow/prompt_flow_controller.dart';
import 'package:docket/shared/prompt_flow/prompt_step.dart';

PromptFlowController _flow(IdDocumentType type) => PromptFlowController(
  steps: buildIdFlow(type),
  initialFlags: <String, bool>{IdFlag.isPan: type == IdDocumentType.pan},
);

List<String> _ids(PromptFlowController c) =>
    c.visibleSteps.map((PromptStep s) => s.id).toList();

void _chooseManual(PromptFlowController c) {
  c.setPath(PromptPath.manual);
  c.next();
}

void main() {
  group('shape', () {
    test('PAN asks for father, not gender or address', () {
      final PromptFlowController c = _flow(IdDocumentType.pan);
      c.setPath(PromptPath.manual);

      expect(_ids(c), <String>[
        IdField.method,
        IdField.name,
        IdField.number,
        IdField.dateOfBirth,
        IdField.fatherName,
        IdField.review,
      ]);
      expect(_ids(c), isNot(contains(IdField.gender)));
      expect(_ids(c), isNot(contains(IdField.address)));
    });

    test('Aadhaar asks for gender and address, not father', () {
      final PromptFlowController c = _flow(IdDocumentType.aadhaar);
      c.setPath(PromptPath.manual);

      expect(_ids(c), <String>[
        IdField.method,
        IdField.name,
        IdField.number,
        IdField.dateOfBirth,
        IdField.gender,
        IdField.address,
        IdField.review,
      ]);
      expect(_ids(c), isNot(contains(IdField.fatherName)));
    });
  });

  group('validation', () {
    test('an empty name is blocked until a number exists', () {
      final PromptFlowController c = _flow(IdDocumentType.pan);
      _chooseManual(c);

      expect(c.current.id, IdField.name);
      expect(c.next(), isFalse);
      expect(c.currentError, isNotNull);
    });

    test('name can be skipped when a number is already present', () {
      final PromptFlowController c = _flow(IdDocumentType.pan);
      _chooseManual(c);
      c.setValue(IdField.number, 'ABCDE1234F');

      expect(c.next(), isTrue);
      expect(c.current.id, IdField.number);
    });

    test('a malformed PAN is rejected, a valid one advances', () {
      final PromptFlowController c = _flow(IdDocumentType.pan);
      _chooseManual(c);
      c.setValue(IdField.name, 'Rahul Sharma');
      expect(c.next(), isTrue);

      c.setValue(IdField.number, 'ABCDE12');
      expect(c.next(), isFalse);

      c.setValue(IdField.number, 'ABCDE1234F');
      expect(c.next(), isTrue);
      expect(c.current.id, IdField.dateOfBirth);
    });

    test('a malformed Aadhaar is rejected', () {
      final PromptFlowController c = _flow(IdDocumentType.aadhaar);
      _chooseManual(c);
      c.setValue(IdField.name, 'Rahul Sharma');
      expect(c.next(), isTrue);

      c.setValue(IdField.number, '12345');
      expect(c.next(), isFalse);

      c.setValue(IdField.number, '123412341234');
      expect(c.next(), isTrue);
    });

    test('PAN date of birth requires an adult when filled', () {
      final PromptFlowController c = _flow(IdDocumentType.pan);
      final PromptStep dob = c.visibleSteps.firstWhere(
        (PromptStep s) => s.id == IdField.dateOfBirth,
      );

      expect(dob.validate!('', c.state), isNull);
      expect(dob.validate!('2015-01-01', c.state), isNotNull);
      expect(dob.validate!('1994-03-12', c.state), isNull);
    });
  });

  test('a full PAN walkthrough reaches review', () {
    final PromptFlowController c = _flow(IdDocumentType.pan);
    _chooseManual(c);

    c.setValue(IdField.name, 'Rahul Sharma');
    expect(c.next(), isTrue);
    c.setValue(IdField.number, 'ABCDE1234F');
    expect(c.next(), isTrue);
    c.setValue(IdField.dateOfBirth, '1994-03-12');
    expect(c.next(), isTrue);
    c.setValue(IdField.fatherName, 'Ramesh Sharma');
    expect(c.next(), isTrue);

    expect(c.current.id, IdField.review);
  });
}
