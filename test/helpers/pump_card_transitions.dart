import 'package:flutter_test/flutter_test.dart';

/// Let finite route/deck springs finish while the active card's ambient clock
/// keeps running. pumpAndSettle cannot settle an intentionally living surface.
Future<void> pumpCardTransitions(WidgetTester tester) async {
  await tester.pump();
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
