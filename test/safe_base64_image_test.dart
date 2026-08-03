import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docket/shared/widgets/safe_base64_image.dart';

/// A 1x1 transparent PNG.
const String _validPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAC'
    'hwGA60e6kgAAAABJRU5ErkJggg==';

Future<void> _mount(WidgetTester tester, String payload) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SafeBase64Image(
            base64: payload,
            width: 40,
            height: 40,
            placeholder: const Icon(Icons.person_rounded),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the image when the payload decodes', (
    WidgetTester tester,
  ) async {
    await _mount(tester, _validPng);

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsNothing);
  });

  // The whole point of the widget. base64Decode throws a FormatException on
  // input like this, and a throw inside build takes down the entire wallet --
  // one corrupt record used to mean no cards at all.
  testWidgets('falls back to the placeholder on a malformed payload', (
    WidgetTester tester,
  ) async {
    await _mount(tester, 'not base64 !!!');

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  // What the passport card did on every MRZ-scanned record: `imagePath` held a
  // filesystem path, and it was handed straight to base64Decode.
  testWidgets('a filesystem path does not throw', (WidgetTester tester) async {
    await _mount(tester, '/data/user/0/com.example.docket/cache/capture.jpg');

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
  });

  testWidgets('an empty payload shows the placeholder', (
    WidgetTester tester,
  ) async {
    await _mount(tester, '');

    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('re-decodes when the payload changes', (
    WidgetTester tester,
  ) async {
    await _mount(tester, '');
    expect(find.byType(Image), findsNothing);

    await _mount(tester, _validPng);
    expect(find.byType(Image), findsOneWidget);
  });
}
