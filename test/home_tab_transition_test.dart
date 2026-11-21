import 'package:docket/core/motion/smooth_curves.dart';
import 'package:docket/features/dashboard/presentation/widgets/home_tab_transition.dart';
import 'package:docket/features/dashboard/presentation/widgets/wallet_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<TabController> open(
    WidgetTester tester, {
    bool reduced = false,
  }) async {
    final controller = TabController(
      length: 2,
      vsync: tester,
      animationDuration: stepSwitchDuration,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: HomeTabTransition(
            controller: controller,
            ids: const _Counter(key: Key('ids')),
            passes: const _Counter(key: Key('passes')),
          ),
        ),
      ),
    );
    return controller;
  }

  List<double> weights(WidgetTester tester) => tester
      .widgetList<Opacity>(
        find.descendant(
          of: find.byType(HomeTabTransition),
          matching: find.byType(Opacity),
        ),
      )
      .map((opacity) => opacity.opacity)
      .toList();

  testWidgets('handoff uses complementary weights and reverses continuously', (
    tester,
  ) async {
    final controller = await open(tester);
    controller.animateTo(1, curve: strongEaseOut);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final before = weights(tester);
    expect(before[0], greaterThan(0));
    expect(before[1], greaterThan(0));
    expect(before[0] + before[1], closeTo(1, 0.0001));
    controller.animateTo(0, curve: strongEaseOut);
    await tester.pump();
    expect(weights(tester), before);
    await tester.pump(stepSwitchDuration);
    expect(weights(tester), [1, 0]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('both tabs retain state; only the selected tab accepts input', (
    tester,
  ) async {
    final controller = await open(tester);
    final ids = find.byKey(const Key('ids'));
    final passes = find.byKey(const Key('passes'));
    await tester.tap(ids);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    controller.animateTo(1, curve: strongEaseOut);
    await tester.pump();
    await tester.pump(stepSwitchDuration);
    await tester.tap(passes);
    await tester.pump();
    expect(find.text('1'), findsNWidgets(2));
    final layers = tester
        .widgetList<IgnorePointer>(
          find.descendant(
            of: find.byType(HomeTabTransition),
            matching: find.byType(IgnorePointer),
          ),
        )
        .toList();
    expect(layers[0].ignoring, isTrue);
    expect(layers[1].ignoring, isFalse);
    final tickers = tester
        .widgetList<TickerMode>(
          find.descendant(
            of: find.byType(HomeTabTransition),
            matching: find.byType(TickerMode),
          ),
        )
        .toList();
    expect(tickers[0].enabled, isFalse);
    expect(tickers[1].enabled, isTrue);
    controller.animateTo(0);
    await tester.pump();
    await tester.pump(stepSwitchDuration);
    await tester.tap(ids);
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('reduced motion fades without any lateral travel', (
    tester,
  ) async {
    final controller = await open(tester, reduced: true);
    controller.animateTo(
      1,
      duration: reducedSwitchDuration,
      curve: strongEaseOut,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final transforms = tester.widgetList<Transform>(
      find.descendant(
        of: find.byType(HomeTabTransition),
        matching: find.byType(Transform),
      ),
    );
    for (final transform in transforms) {
      expect(transform.transform.getTranslation().x, 0);
    }
    expect(weights(tester).reduce((a, b) => a + b), closeTo(1, 0.0001));
    await tester.pump(reducedSwitchDuration);
    expect(weights(tester), [0, 1]);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets(
    'backdrop tint follows the tab timeline without a trailing tween',
    (tester) async {
      final controller = TabController(
        length: 2,
        vsync: tester,
        animationDuration: stepSwitchDuration,
      );
      final page = ValueNotifier<double>(0);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: WalletBackdrop(
              items: const [],
              pageNotifier: page,
              tabAnimation: controller.animation,
            ),
          ),
        ),
      );
      controller.animateTo(1, curve: strongEaseOut);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      AppleCardGradientPainter painter() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<AppleCardGradientPainter>()
          .single;
      expect(controller.animation!.value, greaterThan(0));
      expect(painter().ticketsMix, controller.animation!.value);
      controller.animateTo(0, curve: strongEaseOut);
      await tester.pump();
      expect(painter().ticketsMix, controller.animation!.value);
      await tester.pump(stepSwitchDuration);
      expect(painter().ticketsMix, 0);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      page.dispose();
    },
  );
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => setState(() => count++),
    child: Center(child: Text('$count')),
  );
}
