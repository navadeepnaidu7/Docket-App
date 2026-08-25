import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'bounce_tap.dart';

/// What a [PassActionBar] button is currently doing.
///
/// The label is the progress indicator. A spinner on a two-second operation
/// reads as a stall; a word that changes reads as a reply.
enum PassActionState { idle, busy, done }

/// Two text buttons that sit at the end of a pass detail screen's content.
///
/// Text only, no icons — the same rule the boarding-code row on the bus pass
/// already follows: these need to be the obvious thing to press, not a glyph to
/// hunt for.
///
/// Deliberately **not** a pinned bar. Sharing is something you decide to do
/// after reading the pass, not the first thing the screen should offer, and a
/// sticky plate over the ticket face costs vertical space on every visit for an
/// action most of them do not want. So this carries no plate, no hairline and
/// no safe-area inset — it is an ordinary widget the host drops in as the last
/// item of its scroll view, and it scrolls away with everything else.
///
/// It borrows `_StickyCta`'s type and metrics (56pt tall, Inter 16/w700) but
/// not its chrome.
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

  /// Corner radius. Rounder than the entry-screen CTA's 18: these sit inline on
  /// the page rather than on a bar of their own, so they need more shape to
  /// read as buttons and not as another grouped row.
  static const double radius = 24;

  /// Fill for the secondary button.
  ///
  /// Not `AppTokens.groupedFieldFill`: that tint is calibrated to separate a
  /// row from the card *behind* it, and at 0.08 / 0.55 it barely reads as a
  /// button when it is sitting next to a solid one. This is the same ink,
  /// carried far enough to look deliberately grey against either background.
  /// Kept local rather than pushed into the token, which a dozen other screens
  /// depend on at its current weight.
  static Color secondaryFill(ColorScheme scheme, {required bool isDark}) =>
      scheme.onSurface.withValues(alpha: isDark ? 0.16 : 0.12);

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

    return Row(
      children: <Widget>[
        Expanded(
          child: _ActionButton(
            label: secondaryLabel,
            busyLabel: secondaryBusyLabel,
            doneLabel: secondaryDoneLabel,
            state: secondaryState,
            enabled: !_locked,
            fill: secondaryFill(scheme, isDark: isDark),
            ink: scheme.onSurface,
            onTap: onSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          // Wider than the secondary: sharing is the action people scrolled
          // down for, and the reference sets the same balance.
          flex: 3,
          child: _ActionButton(
            label: primaryLabel,
            busyLabel: primaryBusyLabel,
            doneLabel: primaryDoneLabel,
            state: primaryState,
            enabled: !_locked,
            fill: isDark ? scheme.primary : scheme.onSurface,
            ink: isDark ? scheme.onPrimary : scheme.surface,
            onTap: onPrimary,
          ),
        ),
      ],
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
    required this.onTap,
  });

  final String label;
  final String? busyLabel;
  final String? doneLabel;
  final PassActionState state;
  final bool enabled;
  final Color fill;
  final Color ink;
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
          // Flat on purpose. The drop glow the entry-screen CTA uses is there to
          // lift a floating bar off the content it covers; these sit in the
          // content, and the halo only made them look unseated.
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(PassActionBar.radius),
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
