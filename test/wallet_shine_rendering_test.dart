import 'package:docket/shared/widgets/wallet_card_shine_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _PaintCounter extends CustomPainter {
  int paints = 0;
  @override
  void paint(Canvas canvas, Size size) {
    paints++;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.blue);
  }

  @override
  bool shouldRepaint(_PaintCounter oldDelegate) => false;
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    _PaintCounter counter, {
    bool reduced = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Center(
          child: WalletCardShineBorder(
            enabled: true,
            isActive: true,
            idleDelay: const Duration(milliseconds: 10),
            child: SizedBox(
              width: 300,
              height: 200,
              child: CustomPaint(painter: counter),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('moving shine never repaints the static card face', (
    tester,
  ) async {
    final counter = _PaintCounter();
    await mount(tester, counter);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 1000));
    final baseline = counter.paints;
    expect(baseline, greaterThan(0));
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(counter.paints, baseline);
    expect(
      tester.binding.hasScheduledFrame,
      isTrue,
      reason: 'shine should actually be running during this assertion',
    );
  });

  testWidgets('reduced motion does not start the looping shine', (
    tester,
  ) async {
    await mount(tester, _PaintCounter(), reduced: true);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
