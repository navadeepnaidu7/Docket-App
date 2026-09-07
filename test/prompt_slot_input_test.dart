import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docket/shared/prompt_flow/prompt_step.dart';
import 'package:docket/shared/prompt_flow/widgets/prompt_inputs.dart';
import 'package:docket/shared/prompt_flow/widgets/prompt_slot_input.dart';

Future<void> _pump(
  WidgetTester tester, {
  required String value,
  required ValueChanged<String> onChanged,
  VoidCallback? onComplete,
  bool isDate = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PromptSlotInput(
          value: value,
          label: isDate ? 'Date of birth' : 'Number',
          isDate: isDate,
          onChanged: onChanged,
          onSubmitted: () {},
          onComplete: onComplete,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('passport slots upper-case and cap at nine characters', (
    WidgetTester tester,
  ) async {
    String value = '';
    await _pump(tester, value: value, onChanged: (String v) => value = v);

    await tester.enterText(find.byType(TextField), 'z3 456789x');
    await tester.pump();

    expect(value, 'Z3456789X');
    expect(find.text('Z'), findsOneWidget);
    expect(find.text('X'), findsOneWidget);
  });

  testWidgets('a full passport number fires onComplete once', (
    WidgetTester tester,
  ) async {
    String value = '';
    int complete = 0;
    await _pump(
      tester,
      value: value,
      onChanged: (String v) => value = v,
      onComplete: () => complete++,
    );

    await tester.enterText(find.byType(TextField), 'Z3456789');
    await tester.pump();
    expect(complete, 0);

    await tester.enterText(find.byType(TextField), 'Z34567891');
    await tester.pump();
    expect(value, 'Z34567891');
    expect(complete, 1);

    await tester.enterText(find.byType(TextField), 'A34567891');
    await tester.pump();
    expect(complete, 1);
  });

  testWidgets('an 8-digit date is stored as ISO and auto-completes', (
    WidgetTester tester,
  ) async {
    String value = '';
    var complete = false;
    await _pump(
      tester,
      value: value,
      isDate: true,
      onChanged: (String v) => value = v,
      onComplete: () => complete = true,
    );

    await tester.enterText(find.byType(TextField), '12031994');
    await tester.pump();

    expect(value, '1994-03-12');
    expect(complete, isTrue);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('incomplete dates stay as typed digits', (
    WidgetTester tester,
  ) async {
    String value = '';
    await _pump(
      tester,
      value: value,
      isDate: true,
      onChanged: (String v) => value = v,
    );

    await tester.enterText(find.byType(TextField), '1203');
    await tester.pump();

    expect(value, '1203');
  });

  testWidgets('a 10-digit PNR row rejects letters and completes at ten', (
    WidgetTester tester,
  ) async {
    String value = '';
    var complete = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PromptSlotInput(
            value: value,
            label: 'PNR',
            length: 10,
            digitsOnly: true,
            onChanged: (String v) => value = v,
            onSubmitted: () {},
            onComplete: () => complete = true,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '12345abc67890');
    await tester.pump();

    expect(value, '1234567890');
    expect(complete, isTrue);
  });

  testWidgets('a free-text prompt keeps a full field, not character slots', (
    WidgetTester tester,
  ) async {
    String value = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PromptTextInput(
            step: PromptStep(
              id: 'name',
              kind: PromptStepKind.text,
              question: (_) => 'Enter the name on the passport',
              placeholder: 'Full name',
            ),
            value: '',
            onChanged: (String v) => value = v,
            onSubmitted: () {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Rahul Sharma');
    await tester.pump();

    expect(value, 'Rahul Sharma');
    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('R'), findsNothing);
  });
}
