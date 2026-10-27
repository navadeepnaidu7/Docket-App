import 'package:docket/features/dashboard/presentation/widgets/membership_card_material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget card({VoidCallback? onTap, bool reduced = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: 340,
            height: 226,
            child: MembershipCardMaterial(
              child: GestureDetector(
                onTap: onTap,
                child: const ColoredBox(color: Color(0xFFF2F0F7)),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Matrix4 transform(WidgetTester tester) => tester
      .widget<Transform>(
        find.descendant(
          of: find.byType(MembershipCardMaterial),
          matching: find.byType(Transform),
        ),
      )
      .transform;

  testWidgets(
    'rests without a ticker, tracks touch and settles after release',
    (tester) async {
      await tester.pumpWidget(card());
      expect(tester.hasRunningAnimations, isFalse);
      final center = tester.getCenter(find.byType(MembershipCardMaterial));
      final gesture = await tester.startGesture(
        center + const Offset(110, -50),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(transform(tester).storage[2].abs(), greaterThan(0.01));
      expect(transform(tester).storage[13], lessThan(-1));
      await gesture.moveTo(center + const Offset(-110, 50));
      await tester.pump();
      expect(transform(tester).storage[2], greaterThan(0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(transform(tester).storage[2], closeTo(0, 0.0001));
      expect(transform(tester).storage[13], closeTo(0, 0.0001));
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets('embedded actions still receive taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(card(onTap: () => taps++));
    await tester.tap(find.byType(MembershipCardMaterial));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('reduced motion keeps the card level during touch', (
    tester,
  ) async {
    await tester.pumpWidget(card(reduced: true));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(MembershipCardMaterial)) +
          const Offset(100, 60),
    );
    await tester.pump();
    expect(transform(tester).storage[2], 0);
    expect(transform(tester).storage[13], 0);
    expect(tester.hasRunningAnimations, isFalse);
    await gesture.up();
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
