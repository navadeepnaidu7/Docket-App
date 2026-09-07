import 'package:flutter/material.dart';

/// Shared caret-line motion for slot dashes and free-text underlines.
abstract final class PromptCaret {
  PromptCaret._();

  static const Duration period = Duration(milliseconds: 1080);

  /// Snap on, hold, ease out, rest dim — never fully gone.
  static double envelope(double t) {
    if (t < 0.10) return Curves.easeOut.transform(t / 0.10);
    if (t < 0.54) return 1;
    if (t < 0.76) {
      return 1 - Curves.easeInOut.transform((t - 0.54) / 0.22);
    }
    return 0.16;
  }
}

/// Full-width dim rule with a blinking dash at the insertion point.
class PromptCaretLine extends StatelessWidget {
  const PromptCaretLine({
    super.key,
    required this.blink,
    required this.focused,
    required this.reduced,
    required this.ink,
    required this.caretX,
    this.caretWidth = 22,
  });

  final double blink;
  final bool focused;
  final bool reduced;
  final Color ink;
  final double caretX;
  final double caretWidth;

  @override
  Widget build(BuildContext context) {
    final double glow = (!focused || reduced) ? 1 : PromptCaret.envelope(blink);

    return SizedBox(
      height: 3,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            top: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ink.withValues(alpha: focused ? 0.22 : 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const SizedBox(height: 1, width: double.infinity),
            ),
          ),
          if (focused)
            Positioned(
              left: caretX,
              width: caretWidth,
              top: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.22 + glow * 0.78),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: glow > 0.4
                      ? <BoxShadow>[
                          BoxShadow(
                            color: ink.withValues(alpha: (glow - 0.4) * 0.28),
                            blurRadius: 5,
                            spreadRadius: 0.4,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
