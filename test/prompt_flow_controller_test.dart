import 'package:flutter_test/flutter_test.dart';

import 'package:docket/shared/prompt_flow/prompt_flow_controller.dart';
import 'package:docket/shared/prompt_flow/prompt_step.dart';

PromptStep _text(
  String id, {
  bool skippable = false,
  bool Function(PromptFlowState)? visibleWhen,
  String? Function(String, PromptFlowState)? validate,
}) {
  return PromptStep(
    id: id,
    kind: PromptStepKind.text,
    question: (_) => 'What is $id?',
    confirmQuestion: (_) => 'Is this your $id?',
    skippable: skippable,
    visibleWhen: visibleWhen,
    validate: validate,
  );
}

PromptStep _review() => PromptStep(
      id: 'review',
      kind: PromptStepKind.review,
      question: (_) => 'Ready to save',
    );

PromptFlowController _controller(List<PromptStep> steps) =>
    PromptFlowController(steps: steps);

void main() {
  group('conditional visibility', () {
    test('hidden steps are not counted or walked', () {
      final PromptFlowController c = _controller(<PromptStep>[
        _text('a'),
        _text('secret', visibleWhen: (PromptFlowState s) => s.flag('unlocked')),
        _text('b'),
      ]);

      expect(c.stepCount, 2);
      c.next();
      expect(c.current.id, 'b');
    });

    test('flipping a flag inserts the step into the flow', () {
      final PromptFlowController c = _controller(<PromptStep>[
        _text('a'),
        _text('secret', visibleWhen: (PromptFlowState s) => s.flag('unlocked')),
        _text('b'),
      ]);

      c.setFlag('unlocked', value: true);
      expect(c.stepCount, 3);
      c.next();
      expect(c.current.id, 'secret');
    });

    // The screen this replaces rendered the same three fields twice, under two
    // headings, because the NFC prerequisites were a separate branch instead of
    // conditional steps in one list.
    test('a conditional branch declares each field exactly once', () {
      final PromptFlowController c = _controller(<PromptStep>[
        _text('method'),
        _text('number', visibleWhen: (PromptFlowState s) => s.flag('chip')),
        _text('dob', visibleWhen: (PromptFlowState s) => s.flag('chip')),
        _review(),
      ]);

      c.setFlag('chip', value: true);
      final List<String> ids =
          c.visibleSteps.map((PromptStep s) => s.id).toList();

      expect(ids, <String>['method', 'number', 'dob', 'review']);
      expect(ids.toSet().length, ids.length, reason: 'no field asked twice');
    });
  });

  group('validation', () {
    test('a failing step does not advance and surfaces an inline error', () {
      final PromptFlowController c = _controller(<PromptStep>[
        _text('a', validate: (String v, _) => v.isEmpty ? 'Required' : null),
        _text('b'),
      ]);

      expect(c.next(), isFalse);
      expect(c.current.id, 'a');
      expect(c.currentError, 'Required');
    });

    test('typing clears the error on that field', () {
      final PromptFlowController c = _controller(<PromptStep>[
        _text('a', validate: (String v, _) => v.isEmpty ? 'Required' : null),
        _text('b'),
      ]);

      c.next();
      expect(c.currentError, isNotNull);

      c.setValue('a', 'x');
      expect(c.currentError, isNull);
      expect(c.next(), isTrue);
      expect(c.current.id, 'b');
    });

    test('errors survive until fixed, unlike the banner they replace', () {
      final PromptFlowController c = _controller(<PromptStep>[
        _text('a', validate: (String v, _) => v.isEmpty ? 'Required' : null),
        _text('b'),
      ]);

      c.next();
      c.next();
      expect(c.currentError, 'Required', reason: 'not wiped by re-attempting');
    });
  });

  group('back', () {
    test('unwinds the path actually taken, not an index', () {
      final PromptFlowController c = _controller(<PromptStep>[
        _text('method'),
        _text('chipOnly', visibleWhen: (PromptFlowState s) => s.flag('chip')),
        _text('last'),
      ]);

      c.setFlag('chip', value: true);
      c.next();
      expect(c.current.id, 'chipOnly');
      c.next();
      expect(c.current.id, 'last');

      c.back();
      expect(c.current.id, 'chipOnly', reason: 'not the method chooser');
      c.back();
      expect(c.current.id, 'method');
    });

    test('returns false at the start so the caller can pop the route', () {
      final PromptFlowController c = _controller(<PromptStep>[_text('a')]);
      expect(c.back(), isFalse);
    });

    test('marks direction so the view can animate backwards', () {
      final PromptFlowController c =
          _controller(<PromptStep>[_text('a'), _text('b')]);

      c.next();
      expect(c.direction, PromptDirection.forward);
      c.back();
      expect(c.direction, PromptDirection.backward);
    });
  });

  group('skip', () {
    test('only works on skippable steps', () {
      final PromptFlowController c = _controller(<PromptStep>[
        _text('a'),
        _text('b'),
      ]);

      c.skip();
      expect(c.current.id, 'a');
    });

    test('advances and records the step as skipped', () {
      final PromptFlowController c = _controller(<PromptStep>[
        _text('a', skippable: true),
        _text('b'),
      ]);

      c.skip();
      expect(c.current.id, 'b');
      expect(c.wasSkipped('a'), isTrue);
    });
  });

  group('jumpTo / returnTo', () {
    test('editing from review returns to review on commit', () {
      final PromptFlowController c = _controller(<PromptStep>[
        _text('a'),
        _text('b'),
        _review(),
      ]);

      c.next();
      c.next();
      expect(c.current.id, 'review');

      c.jumpTo('a', returnTo: 'review');
      expect(c.current.id, 'a');

      c.setValue('a', 'fixed');
      c.next();
      expect(c.current.id, 'review', reason: 'two taps, not a re-walk');
    });

    test('backing out of an edit also returns to review', () {
      final PromptFlowController c = _controller(<PromptStep>[
        _text('a'),
        _review(),
      ]);

      c.next();
      c.jumpTo('a', returnTo: 'review');
      c.back();
      expect(c.current.id, 'review');
    });
  });

  group('applyScan', () {
    test('fills values, records provenance and enters confirm mode', () {
      final PromptFlowController c = _controller(<PromptStep>[
        _text('name'),
        _text('number'),
      ]);

      c.applyScan(
        <String, String>{'name': 'RAHUL SHARMA', 'number': 'Z3456789'},
        source: FieldSource.scanned,
      );

      expect(c.state.value('name'), 'RAHUL SHARMA');
      expect(c.state.sourceOf('number'), FieldSource.scanned);
      expect(c.state.confirmMode, isTrue);
      expect(c.isConfirming, isTrue);
      expect(c.currentQuestion, 'Is this your name?');
    });

    test('a field the scan missed still asks normally, in place', () {
      final PromptFlowController c = _controller(<PromptStep>[
        _text('name'),
        _text('number'),
      ]);

      c.applyScan(
        <String, String>{'name': 'RAHUL SHARMA', 'number': '  '},
        source: FieldSource.scanned,
      );

      c.next();
      expect(c.current.id, 'number');
      expect(c.isConfirming, isFalse);
      expect(c.currentQuestion, 'What is number?');
    });

    // Both scan paths in the old screen jumped straight to review without
    // validating anything they had just filled in.
    test('a scanned value is still validated on confirm', () {
      final PromptFlowController c = _controller(<PromptStep>[
        _text(
          'dob',
          validate: (String v, _) => v.length == 10 ? null : 'Bad date',
        ),
        _text('after'),
      ]);

      c.applyScan(
        <String, String>{'dob': 'nonsense'},
        source: FieldSource.scanned,
      );

      expect(c.next(), isFalse);
      expect(c.currentError, 'Bad date');
    });

    test('typing over a scanned value marks it typed', () {
      final PromptFlowController c = _controller(<PromptStep>[_text('name')]);

      c.applyScan(
        <String, String>{'name': 'OCR GUESS'},
        source: FieldSource.scanned,
      );
      expect(c.state.sourceOf('name'), FieldSource.scanned);

      c.setValue('name', 'Corrected');
      expect(c.state.sourceOf('name'), FieldSource.typed);
    });

    test('an untrusted scan is flagged for the view', () {
      final PromptFlowController c = _controller(<PromptStep>[_text('a')]);

      c.applyScan(
        <String, String>{'a': 'x'},
        source: FieldSource.scanned,
        trusted: false,
      );

      expect(c.state.flag('trustedScan'), isFalse);
    });
  });

  group('progress', () {
    test('never runs backwards when the visible list grows', () {
      final PromptFlowController c = _controller(<PromptStep>[
        _text('a'),
        _text('b'),
        _text('extra', visibleWhen: (PromptFlowState s) => s.flag('more')),
        _text('c'),
      ]);

      c.next();
      final double before = c.progress;

      c.setFlag('more', value: true);
      expect(c.progress, greaterThanOrEqualTo(before));
    });

    test('reaches 1 on the final step', () {
      final PromptFlowController c =
          _controller(<PromptStep>[_text('a'), _text('b')]);

      c.next();
      expect(c.progress, 1.0);
    });
  });

  test('onCommit receives values only after validation passes', () {
    final List<Map<String, String>> commits = <Map<String, String>>[];
    final PromptFlowController c = PromptFlowController(
      steps: <PromptStep>[
        _text('a', validate: (String v, _) => v.isEmpty ? 'Required' : null),
        _text('b'),
      ],
      onCommit: commits.add,
    );

    c.next();
    expect(commits, isEmpty);

    c.setValue('a', 'ok');
    c.next();
    expect(commits.single['a'], 'ok');
  });
}
