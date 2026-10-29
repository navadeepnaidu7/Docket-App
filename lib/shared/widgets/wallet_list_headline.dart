import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/motion/smooth_curves.dart';
import '../../core/theme/app_theme.dart';

/// The wallet's rise-in: fade plus a 14 px lift, staggered 70 ms per [step].
///
/// Shared by [WalletListHeadline] and `WalletEmptyState` so every wallet view
/// enters on the same beat. Empty when reduced motion is on.
List<Effect<dynamic>> walletRise(int step, {required bool reduced}) => reduced
    ? const <Effect<dynamic>>[]
    : <Effect<dynamic>>[
        FadeEffect(
          delay: Duration(milliseconds: 60 + step * 70),
          duration: const Duration(milliseconds: 420),
          curve: strongEaseOut,
        ),
        MoveEffect(
          delay: Duration(milliseconds: 60 + step * 70),
          duration: const Duration(milliseconds: 520),
          curve: strongEaseOut,
          begin: const Offset(0, 14),
          end: Offset.zero,
        ),
      ];

/// The 26 pt two-tone headline of the empty states, set over a list.
///
/// A muted [lead] saying where the user is, an ink [prompt] saying what the
/// view is for, and one small [hint] naming the gestures. Left-aligned rather
/// than centred: it heads a list, and a centred headline over left-aligned
/// rows reads as two unrelated blocks.
class WalletListHeadline extends StatelessWidget {
  const WalletListHeadline({
    super.key,
    required this.lead,
    required this.prompt,
    required this.hint,
  });

  final String lead;
  final String prompt;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final Brightness b = Theme.of(context).brightness;
    final Color ink = AppTheme.ink(b);
    final bool reduced = MediaQuery.disableAnimationsOf(context);

    final TextStyle base = AppFonts.ui(
      fontSize: 26,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.7,
      height: 1.2,
      color: ink,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '$lead\n',
                  style: base.copyWith(
                    color: ink.withValues(
                      alpha: b == Brightness.dark ? 0.48 : 0.42,
                    ),
                  ),
                ),
                TextSpan(text: prompt),
              ],
            ),
            style: base,
          ).animate(effects: walletRise(0, reduced: reduced)),
          const SizedBox(height: 10),
          Text(
            hint,
            style: AppFonts.ui(
              fontSize: 13,
              letterSpacing: -0.1,
              color: ink.withValues(alpha: b == Brightness.dark ? 0.5 : 0.45),
            ),
          ).animate(effects: walletRise(1, reduced: reduced)),
        ],
      ),
    );
  }
}
