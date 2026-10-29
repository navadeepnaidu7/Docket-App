import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/motion/smooth_curves.dart';
import '../../core/theme/app_theme.dart';
import 'docket_button.dart';
import 'wallet_list_headline.dart';

/// Empty wallet tab: artwork, a two-tone headline and one full-width action.
///
/// The headline is two sentences in two tones — a muted statement of where
/// the user is, then the ink line that says what to do — centred with the
/// artwork and a compact button in the middle of the tab.
class WalletEmptyState extends StatelessWidget {
  const WalletEmptyState({
    super.key,
    required this.artwork,
    required this.lead,
    required this.prompt,
    required this.actionLabel,
    required this.onAction,
    required this.bottomClearance,
    this.actionIcon,
    this.actionTone = DocketButtonTone.primary,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondary,
    this.footnote,
  });

  final Widget artwork;

  /// Muted first line: "Nothing here yet."
  final String lead;

  /// Ink second line: what the action does.
  final String prompt;
  final String actionLabel;
  final VoidCallback? onAction;
  final double bottomClearance;

  /// Leading glyph for the action, usually a `LineIcon`.
  final Widget? actionIcon;
  final DocketButtonTone actionTone;

  /// Optional quiet pill beside the primary, for a view with two exits.
  final String? secondaryLabel;
  final Widget? secondaryIcon;
  final VoidCallback? onSecondary;

  /// Optional small line under the button.
  final Widget? footnote;

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

    List<Effect<dynamic>> rise(int step) => walletRise(step, reduced: reduced);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: EdgeInsets.fromLTRB(28, 24, 28, bottomClearance),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: artwork.animate(
                        effects: reduced
                            ? const <Effect<dynamic>>[]
                            : <Effect<dynamic>>[
                                const FadeEffect(
                                  duration: Duration(milliseconds: 500),
                                  curve: strongEaseOut,
                                ),
                                const ScaleEffect(
                                  duration: Duration(milliseconds: 700),
                                  curve: strongEaseOut,
                                  begin: Offset(0.94, 0.94),
                                  end: Offset(1, 1),
                                ),
                              ],
                      ),
                    ),
                    const SizedBox(height: 32),
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
                      textAlign: TextAlign.center,
                    ).animate(effects: rise(1)),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        DocketButton(
                          label: actionLabel,
                          onPressed: onAction,
                          expand: false,
                          compact: true,
                          tone: actionTone,
                          leading: actionIcon,
                        ),
                        if (secondaryLabel != null) ...<Widget>[
                          const SizedBox(width: 10),
                          DocketButton(
                            label: secondaryLabel!,
                            onPressed: onSecondary,
                            tone: DocketButtonTone.secondary,
                            expand: false,
                            compact: true,
                            leading: secondaryIcon,
                          ),
                        ],
                      ],
                    ).animate(effects: rise(2)),
                    if (footnote != null) ...[
                      const SizedBox(height: 18),
                      Center(child: footnote!).animate(effects: rise(3)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "icon  **Bold part** muted rest" — the small social-proof style line.
class WalletFootnote extends StatelessWidget {
  const WalletFootnote({
    super.key,
    required this.icon,
    required this.strong,
    required this.rest,
    this.onTap,
  });

  /// A `LineIcon` or `Icon`; sized and tinted through [IconTheme].
  final Widget icon;
  final String strong;
  final String rest;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Brightness b = Theme.of(context).brightness;
    final Color ink = AppTheme.ink(b);
    final Color muted = ink.withValues(
      alpha: b == Brightness.dark ? 0.5 : 0.45,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme.merge(
              data: IconThemeData(size: 15, color: muted),
              child: icon,
            ),
            const SizedBox(width: 6),
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: strong,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: ' $rest'),
                ],
              ),
              style: AppFonts.ui(
                fontSize: 13,
                color: muted,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
