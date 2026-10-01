import 'package:docket/core/wallet/wallet_backdrop_tilt.dart';
import 'package:docket/shared/widgets/card_touch_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ValueNotifier<double> x;
  late ValueNotifier<double> y;
  late WalletBackdropTilt backdrop;
  int taps = 0;
  int holds = 0;

  setUp(() {
    x = ValueNotifier(0);
    y = ValueNotifier(0);
    backdrop = WalletBackdropTilt();
    taps = 0;
    holds = 0;
  });
  tearDown(() {
    x.dispose();
    y.dispose();
    backdrop.dispose();
  });

  Future<void> mount(WidgetTester tester, {bool reduced = false}) =>
      tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Center(
              child: SizedBox(
                width: 300,
                height: 200,
                child: CardTouchLayer(
                  tiltX: x,
                  tiltY: y,
                  backdropTilt: backdrop,
                  onTap: () => taps++,
                  onLongPress: () => holds++,
                  child: const ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('release settles from live tilt and a new touch interrupts it', (
    tester,
  ) async {
    await mount(tester);
    final center = tester.getCenter(find.byType(CardTouchLayer));
    final drag = await tester.startGesture(center);
    await drag.moveBy(const Offset(90, 0));
    final released = y.value;
    expect(released, lessThan(0));
    await drag.up();
    expect(y.value, released, reason: 'release must not snap flat');
    expect(backdrop.dragging, isFalse);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(y.value.abs(), lessThan(released.abs()));
    expect(y.value, isNot(0));

    final next = await tester.startGesture(center);
    final grabbed = y.value;
    await tester.pump(const Duration(milliseconds: 100));
    expect(y.value, grabbed, reason: 'a new touch owns the live pose');
    await next.cancel();
    await tester.pumpAndSettle();
    expect(y.value, 0);
    expect(backdrop.value, Offset.zero);
    expect(taps, 0);
  });

  testWidgets('vertical travel stays flat and never becomes a flip or hold', (
    tester,
  ) async {
    await mount(tester);
    final drag = await tester.startGesture(
      tester.getCenter(find.byType(CardTouchLayer)),
    );
    await drag.moveBy(const Offset(2, -90));
    await tester.pump(const Duration(milliseconds: 600));
    await drag.up();
    expect(x.value, 0);
    expect(y.value, 0);
    expect(taps, 0);
    expect(holds, 0);
  });

  testWidgets('second pointer cannot trigger a flip during an owned drag', (
    tester,
  ) async {
    await mount(tester);
    final center = tester.getCenter(find.byType(CardTouchLayer));
    final first = await tester.startGesture(center, pointer: 1);
    await first.moveBy(const Offset(90, 0));
    final second = await tester.startGesture(center, pointer: 2);
    await second.up();
    expect(taps, 0);
    expect(y.value, isNot(0));
    await first.up();
    await tester.pumpAndSettle();
    expect(taps, 0);
  });

  testWidgets('reduced motion keeps tilt flat and ordinary taps work', (
    tester,
  ) async {
    await mount(tester, reduced: true);
    final drag = await tester.startGesture(
      tester.getCenter(find.byType(CardTouchLayer)),
    );
    await drag.moveBy(const Offset(90, 0));
    await drag.up();
    expect(y.value, 0);
    await tester.tap(find.byType(CardTouchLayer));
    expect(taps, 1);
  });

  testWidgets('long press fires once and does not flip on release', (
    tester,
  ) async {
    await mount(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CardTouchLayer)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    expect(holds, 1);
    expect(taps, 0);
  });
}
