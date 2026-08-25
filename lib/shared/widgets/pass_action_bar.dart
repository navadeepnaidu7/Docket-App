import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'bounce_tap.dart';

/// What a [PassActionBar] button is currently doing.
///
/// The label is the progress indicator. A spinner on a two-second operation
/// reads as a stall; a word that changes reads as a reply.
enum PassActionState { idle, busy, done }

/// Two text buttons pinned to the bottom of a pass detail screen.
///
/// Text only, no icons — the same rule the boarding-code row on the bus pass
/// already follows: these need to be the obvious thing to press, not a glyph to
/// hunt for.
///
/// Visually a sibling of `_StickyCta` in `document_entry_scaffold.dart` (same
/// 56pt height, 18pt radius, Inter 16/w700 and hairline-topped plate) rather
/// than a refactor of it: that one is built around a single full-width CTA and
/// widening its contract to carry a second button would complicate every
/// document entry screen for one caller's benefit.
class PassActionBar extends StatelessWidget {
  const PassActionBar({
    super.key,
    required this.secondaryLabel,
    required this.primaryLabel,
    required this.onSecondary,
    required this.onPrimary,
    this.secondaryState = PassActionState.idle,
    this.primaryState = PassActionState.idle,
    this.secondaryBusyLabel,
    this.secondaryDoneLabel,
    this.primaryBusyLabel,
    this.primaryDoneLabel,
  });

  final String secondaryLabel;
  final String primaryLabel;

  final VoidCallback onSecondary;
  final VoidCallback onPrimary;

  final PassActionState secondaryState;
  final PassActionState primaryState;

  /// Labels for the non-idle states. Null falls back to [secondaryLabel] /
  /// [primaryLabel], so a button with nothing to say simply does not change.
  final String? secondaryBusyLabel;
  final String? secondaryDoneLabel;
  final String? primaryBusyLabel;
  final String? primaryDoneLabel;

  /// True while either button is mid-operation. Both are disabled together:
  /// sharing and saving both rasterise the same card, and letting the second
  /// start while the first is still capturing would put two off-screen copies
  /// in the overlay at once.
  bool get _locked =>
      secondaryState == PassActionState.busy ||
      primaryState == PassActionState.busy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Material(
      color: theme.scaffoldBackgroundColor.withValues(alpha: 0.96),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTokens.separator(scheme), width: 0.5),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _ActionButton(
                  label: secondaryLabel,
                  busyLabel: secondaryBusyLabel,
                  doneLabel: secondaryDoneLabel,
                  state: secondaryState,
                  enabled: !_locked,
                  fill: AppTokens.groupedFieldFill(scheme, isDark: isDark),
                  ink: scheme.onSurface,
                  glow: false,
                  onTap: onSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                // Wider than the secondary: sharing is the action people came
                // to this bar for, and the reference sets the same balance.
                flex: 3,
                child: _ActionButton(
                  label: primaryLabel,
                  busyLabel: primaryBusyLabel,
                  doneLabel: primaryDoneLabel,
                  state: primaryState,
                  enabled: !_locked,
                  fill: isDark ? scheme.primary : scheme.onSurface,
                  ink: isDark ? scheme.onPrimary : scheme.surface,
                  glow: true,
                  onTap: onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.busyLabel,
    required this.doneLabel,
    required this.state,
    required this.enabled,
    required this.fill,
    required this.ink,
    required this.glow,
    required this.onTap,
  });

  final String label;
  final String? busyLabel;
  final String? doneLabel;
  final PassActionState state;
  final bool enabled;
  final Color fill;
  final Color ink;
  final bool glow;
  final VoidCallback onTap;

  String get _shownLabel => switch (state) {
        PassActionState.idle => label,
        PassActionState.busy => busyLabel ?? label,
        PassActionState.done => doneLabel ?? label,
      };

  @override
  Widget build(BuildContext context) {
    final Widget text = Text(
      _shownLabel,
      // Keyed by the text so the switcher animates on a wording change and
      // stays put when only the enabled state moves.
      key: ValueKey<String>(_shownLabel),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        color: ink,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );

    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.45,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: BounceTap(
        onTap: enabled ? onTap : null,
        scaleFactor: 0.975,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
            boxShadow: glow && enabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: fill.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> anim) {
              // Rise into place while fading, so the word reads as replaced
              // rather than cross-dissolved.
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              );
            },
            child: text,
          ),
        ),
      ),
    );
  }
}
