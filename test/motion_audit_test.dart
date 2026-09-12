import 'package:docket/core/motion/smooth_curves.dart';
import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/features/dashboard/presentation/widgets/dot_indicator.dart';
import 'package:docket/features/dashboard/presentation/widgets/wallet_backdrop.dart';
import 'package:docket/shared/prompt_flow/prompt_flow_controller.dart';
import 'package:docket/shared/prompt_flow/prompt_flow_screen.dart';
import 'package:docket/shared/prompt_flow/prompt_step.dart';
import 'package:docket/shared/widgets/completion_celebration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the first bundle of the motion audit — findings 1, 2, 3 and 5.
/// See docs/features/motion-audit.md.

Future<void> _pumpIndicator(
  WidgetTester tester, {
  required int count,
  required double page,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: DotIndicator(count: count, page: page),
        ),
      ),
    ),
  );
}

Finder _dots() => find.descendant(
  of: find.byType(DotIndicator),
  matching: find.byType(DecoratedBox),
);

/// The scroll pill's own box. Measured through the [Transform] rather than at
/// it: a RenderTransform applies its offset to its child, not to itself, so
/// asking the Transform for its position always reports the track origin.
Finder _pill() => find.descendant(
  of: find.descendant(
    of: find.byType(DotIndicator),
    matching: find.byType(Transform),
  ),
  matching: find.byType(DecoratedBox),
);

/// Runs the backdrop past its deferred start so the ambient drift is either
/// running or provably refusing to.
Future<void> _settleBackdropStart(WidgetTester tester) async {
  await tester.pump();
  // The start is deferred ~480ms so the first frames stay free for layout.
  await tester.pump(const Duration(milliseconds: 500));
}

Widget _backdrop({bool reduceMotion = false}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Builder(
      builder: (BuildContext context) {
        final Widget backdrop = WalletBackdrop(
          items: const <Object>[],
          pageNotifier: ValueNotifier<double>(0),
        );
        if (!reduceMotion) return backdrop;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: backdrop,
        );
      },
    ),
  );
}

AppleCardGradientPainter _painterOf(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find
        .descendant(
          of: find.byType(WalletBackdrop),
          matching: find.byType(CustomPaint),
        )
        .first,
  );
  return paint.painter! as AppleCardGradientPainter;
}

PromptFlowController _twoStepFlow() => PromptFlowController(
  steps: <PromptStep>[
    PromptStep(
      id: 'first',
      kind: PromptStepKind.text,
      question: (PromptFlowState s) => 'First question',
    ),
    PromptStep(
      id: 'second',
      kind: PromptStepKind.text,
      question: (PromptFlowState s) => 'Second question',
    ),
  ],
);

void main() {
  group('finding 2 - indicators do not chase the finger', () {
    testWidgets('dot size is the derived value on the very next frame', (
      WidgetTester tester,
    ) async {
      // What a fully settled build at page 1 looks like.
      await _pumpIndicator(tester, count: 3, page: 1);
      await tester.pump(const Duration(milliseconds: 400));
      final List<Size> settled = <Size>[
        tester.getSize(_dots().at(0)),
        tester.getSize(_dots().at(1)),
        tester.getSize(_dots().at(2)),
      ];

      // Now arrive at page 1 from page 0 and allow exactly one frame. An
      // implicit 200ms tween would still be mid-flight here.
      await _pumpIndicator(tester, count: 3, page: 0);
      await tester.pump(const Duration(milliseconds: 400));
      await _pumpIndicator(tester, count: 3, page: 1);
      await tester.pump();

      expect(<Size>[
        tester.getSize(_dots().at(0)),
        tester.getSize(_dots().at(1)),
        tester.getSize(_dots().at(2)),
      ], settled);
    });

    testWidgets('dot size interpolates mid-drag', (WidgetTester tester) async {
      // Halfway between two cards both dots should be halfway in size, which
      // only happens if the value is derived rather than tweened to a target.
      await _pumpIndicator(tester, count: 3, page: 0.5);
      await tester.pump();

      expect(tester.getSize(_dots().at(0)).width, closeTo(8, 0.01));
      expect(tester.getSize(_dots().at(1)).width, closeTo(8, 0.01));
      expect(tester.getSize(_dots().at(2)).width, closeTo(6, 0.01));
    });

    testWidgets('the scroll pill lands on its offset in one frame', (
      WidgetTester tester,
    ) async {
      // count > _dotThreshold switches to the pill. pill = 48/8 = 6, so the
      // travel is 42 and page 7 of 7 sits at the bottom of the track.
      await _pumpIndicator(tester, count: 8, page: 0);
      await tester.pump(const Duration(milliseconds: 400));
      final double trackTop = tester.getTopLeft(find.byType(DotIndicator)).dy;
      expect(tester.getTopLeft(_pill()).dy - trackTop, closeTo(0, 0.01));

      await _pumpIndicator(tester, count: 8, page: 7);
      await tester.pump();
      expect(tester.getTopLeft(_pill()).dy - trackTop, closeTo(42, 0.01));
    });
  });

  group('finding 1 - backdrop ambience', () {
    testWidgets('reduced motion leaves the wash static', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_backdrop(reduceMotion: true));
      await _settleBackdropStart(tester);
      // Would time out if either ambient ticker were repeating.
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_painterOf(tester).ambientProgress, 0);
      expect(_painterOf(tester).deepProgress, 0);
    });

    testWidgets('the drift starts when motion is allowed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_backdrop());
      await _settleBackdropStart(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      expect(_painterOf(tester).ambientProgress, greaterThan(0));
    });

    testWidgets('ambient progress is reported at 20Hz, not every frame', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_backdrop());
      await _settleBackdropStart(tester);
      await tester.pump(const Duration(milliseconds: 100));
      final double start = _painterOf(tester).ambientProgress;
      // Guards the two assertions below against passing merely because the
      // drift had not begun yet.
      expect(start, greaterThan(0));

      // One 60fps frame is well inside a 50ms bucket, so nothing is reported
      // and the full-screen canvas is not rebuilt.
      await tester.pump(const Duration(milliseconds: 16));
      expect(_painterOf(tester).ambientProgress, start);

      // Crossing a bucket does report.
      await tester.pump(const Duration(milliseconds: 60));
      expect(_painterOf(tester).ambientProgress, greaterThan(start));
    });
  });

  group('finding 3 - a prompt step change is one timeline', () {
    testWidgets('everything has settled by stepSwitchDuration', (
      WidgetTester tester,
    ) async {
      final PromptFlowController flow = _twoStepFlow();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: PromptFlowScreen(
            controller: flow,
            primaryLabel: 'Continue',
            onPrimary: () => flow.next(),
            stepBuilder: (BuildContext context, PromptStep step) =>
                SizedBox(key: ValueKey<String>('body-${step.id}'), height: 40),
          ),
        ),
      );
      await tester.pumpAndSettle();

      flow.next();
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);

      // The switcher and the progress hairline share one duration, and no
      // per-element reveal runs on top of them.
      await tester.pump(stepSwitchDuration);
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('Second question'), findsOneWidget);
      expect(find.text('First question'), findsNothing);
    });
  });

  group('finding 5 - the checkmark settles rather than inflates', () {
    testWidgets('scale never drops below 0.94', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CompletionCelebration(
              loadingTitle: 'Saving',
              loadingDescription: 'Encrypting',
              successTitle: 'Done',
              successDescription: 'Stored',
              loadingDelay: Duration.zero,
              onComplete: () {},
            ),
          ),
        ),
      );

      // Let the loading phase hand over to success.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // Scoped to the checkmark: Material puts its own ScaleTransition in the
      // tree, so find.byType alone is ambiguous here.
      final Finder scale = find.ancestor(
        of: find.byIcon(Icons.check_circle_rounded),
        matching: find.byType(ScaleTransition),
      );
      expect(scale, findsOneWidget);

      // Sample the whole spring. The old code drove ScaleTransition straight
      // off a controller sitting at 0.0, so the first frame was scale(0).
      double lowest = double.infinity;
      for (int i = 0; i < 70; i++) {
        final double v = tester.widget<ScaleTransition>(scale).scale.value;
        if (v < lowest) lowest = v;
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(lowest, greaterThanOrEqualTo(0.94));
      expect(lowest, lessThan(1.0));
    });
  });
}
