import 'dart:math' as math;

import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/shared/widgets/pass_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpBar(
  WidgetTester tester, {
  required Brightness brightness,
  PassActionState secondary = PassActionState.idle,
  PassActionState primary = PassActionState.idle,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: PassActionBar(
            secondaryLabel: 'Save',
            secondaryBusyLabel: 'Saving',
            secondaryDoneLabel: 'Saved',
            primaryLabel: 'Share',
            primaryBusyLabel: 'Preparing',
            secondaryState: secondary,
            primaryState: primary,
            onSecondary: () {},
            onPrimary: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Flattens [fg] onto [bg], which is what the eye actually sees — the button
/// fills are translucent, so their raw alpha says nothing on its own.
Color _over(Color fg, Color bg) {
  final double a = fg.a;
  double mix(double f, double b) => f * a + b * (1 - a);
  return Color.from(
    alpha: 1,
    red: mix(fg.r, bg.r),
    green: mix(fg.g, bg.g),
    blue: mix(fg.b, bg.b),
  );
}

void main() {
  group('PassActionBar', () {
    testWidgets('shows both labels', (WidgetTester tester) async {
      await _pumpBar(tester, brightness: Brightness.light);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('swaps the label for the busy and done states',
        (WidgetTester tester) async {
      await _pumpBar(
        tester,
        brightness: Brightness.light,
        secondary: PassActionState.busy,
      );
      expect(find.text('Saving'), findsOneWidget);

      await _pumpBar(
        tester,
        brightness: Brightness.light,
        secondary: PassActionState.done,
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('a busy button disables both', (WidgetTester tester) async {
      await _pumpBar(
        tester,
        brightness: Brightness.light,
        primary: PassActionState.busy,
      );

      // Both rasterise the same card; a second capture must not start while
      // the first is still in the overlay.
      for (final AnimatedOpacity o
          in tester.widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))) {
        expect(o.opacity, lessThan(1.0));
      }
    });

    // The drop glow the entry-screen CTA uses exists to lift a floating bar off
    // the content it covers. These sit *in* the content, where a halo only made
    // them look unseated.
    for (final Brightness b in Brightness.values) {
      testWidgets('paints no shadow in ${b.name}', (WidgetTester tester) async {
        await _pumpBar(tester, brightness: b);

        final Iterable<Container> boxes = tester
            .widgetList<Container>(find.byType(Container))
            .where((Container c) => c.decoration is BoxDecoration);
        expect(boxes, isNotEmpty);
        for (final Container c in boxes) {
          expect((c.decoration! as BoxDecoration).boxShadow, isNull);
        }
      });

      // "Grey enough" as a property rather than a hex value: composited onto
      // the page it must land clearly off the background, so it reads as a
      // button and not as an empty slot next to the filled one.
      test('secondary fill reads as a distinct block in ${b.name}', () {
        final ThemeData theme =
            b == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;
        final Color page = theme.scaffoldBackgroundColor;
        final Color fill = PassActionBar.secondaryFill(
          theme.colorScheme,
          isDark: b == Brightness.dark,
        );

        final double delta = (_over(fill, page).computeLuminance() -
                page.computeLuminance())
            .abs();

        // The old grouped-row tint sat around half this, which is what made it
        // look like no button at all.
        expect(
          delta,
          greaterThan(0.02),
          reason: 'secondary button barely separates from the page in ${b.name}',
        );
        // And not so far that it competes with the filled primary.
        final Color primary = b == Brightness.dark
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface;
        expect(
          delta,
          lessThan(
            (primary.computeLuminance() - page.computeLuminance()).abs(),
          ),
        );
      });
    }

    test('secondary is greyer than the shared grouped-row tint', () {
      for (final Brightness b in Brightness.values) {
        final ThemeData theme =
            b == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme;
        final bool isDark = b == Brightness.dark;
        final Color page = theme.scaffoldBackgroundColor;

        double sep(Color fill) =>
            (_over(fill, page).computeLuminance() - page.computeLuminance())
                .abs();

        expect(
          sep(PassActionBar.secondaryFill(theme.colorScheme, isDark: isDark)),
          greaterThan(
            sep(AppTokens.groupedFieldFill(theme.colorScheme, isDark: isDark)),
          ),
          reason: 'no longer an improvement on the token it replaced (${b.name})',
        );
      }
    });

    test('both buttons share one radius', () {
      expect(PassActionBar.radius, greaterThan(18));
      expect(PassActionBar.radius, lessThanOrEqualTo(28));
      // A 56pt button at radius 28 is a stadium; the design is a rounded rect.
      expect(PassActionBar.radius, lessThan(56 / 2));
      expect(math.max(PassActionBar.radius, 0), PassActionBar.radius);
    });
  });
}
