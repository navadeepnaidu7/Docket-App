import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/haptics/haptic_service.dart';
import '../../core/motion/entry_reveal.dart';
import '../../core/theme/app_theme.dart';
import 'bounce_tap.dart';

/// Builds the body of one step. The [controller] lets a step advance the flow
/// in place rather than opening another route.
typedef MorphStepBuilder =
    Widget Function(BuildContext context, MorphSheetController controller);

/// One screen of a [MorphSheet] flow.
@immutable
class MorphStep {
  const MorphStep({
    required this.id,
    required this.title,
    required this.builder,
    this.subtitle,
  });

  /// Identity for the cross-fade. Two steps with the same id are treated as the
  /// same screen and will not animate between each other.
  final String id;

  final String title;
  final String? subtitle;
  final MorphStepBuilder builder;
}

/// Drives a [MorphSheet] from inside a step body.
abstract class MorphSheetController {
  /// Advances to [step], growing or shrinking the sheet around it.
  void push(MorphStep step);

  /// Returns to the previous step. No-op at the root.
  void back();

  /// Dismisses the whole sheet.
  void close();

  /// Whether the root step is showing — i.e. [back] would do nothing.
  bool get isRoot;
}

/// Opens a [MorphSheet] as a modal bottom sheet.
///
/// The entire flow lives on this one route: sub-steps morph in place instead of
/// popping the sheet and pushing another, which is what the old add flow did.
Future<void> showMorphSheet({
  required BuildContext context,
  required MorphStep root,
  String heading = 'Add',
}) {
  HapticService.confirm();
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) =>
        MorphSheet(root: root, heading: heading),
  );
}

class MorphSheet extends StatefulWidget {
  const MorphSheet({super.key, required this.root, this.heading = 'Add'});

  final MorphStep root;

  /// Constant title in the header bar — it does not change between steps.
  final String heading;

  @override
  State<MorphSheet> createState() => _MorphSheetState();
}

class _MorphSheetState extends State<MorphSheet>
    implements MorphSheetController {
  late List<MorphStep> _stack = <MorphStep>[widget.root];

  /// How long the sheet takes to resize around a new step.
  ///
  /// The resize deliberately outlasts the content swap below: the sheet leads,
  /// the content settles into it. Equal timings read as one flat dissolve.
  static const Duration _morph = Duration(milliseconds: 460);

  /// Corner radius for the floating sheet. Larger than [AppTheme.radiusSheet],
  /// which is tuned for sheets pinned to the screen edge — this one is inset
  /// 16 on both sides and reads as a card, so it wants a rounder corner.
  static const double _radius = 38;

  /// Fraction of the screen the *step body* may occupy before it scrolls.
  /// Header and chrome sit outside this, so the sheet still leaves the wallet
  /// visible behind it.
  static const double _maxBodyFraction = 0.66;

  @override
  bool get isRoot => _stack.length == 1;

  // No haptic in push/back. Every route into them is a BounceTap — a tile or
  // the header button — which already pulses on touch down. Firing again here
  // landed a second pulse about 100 ms later, which reads as a stutter rather
  // than a confirmation.

  @override
  void push(MorphStep step) {
    setState(() => _stack = <MorphStep>[..._stack, step]);
  }

  @override
  void back() {
    if (isRoot) return;
    setState(() => _stack = _stack.sublist(0, _stack.length - 1));
  }

  @override
  void close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final MediaQueryData mq = MediaQuery.of(context);

    final Color borderColor = isDark
        ? scheme.onSurface.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.40);

    return PopScope(
      // Android back walks the flow one step at a time and only leaves from the
      // root. Without this, back from a sub-step drops the entire sheet, which
      // is the behaviour this redesign exists to remove.
      canPop: isRoot,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) back();
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, mq.padding.bottom + 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppTokens.sheetBackground(scheme),
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(color: borderColor, width: 0.5),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                    blurRadius: 32,
                    spreadRadius: -4,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTokens.sheetHandle(scheme),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  _buildHeader(theme, scheme),
                  _buildMorphingBody(theme, scheme, mq),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme scheme) {
    final bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      // 19, not the body's 24: each button's 44 tap box is 5 wider than its
      // visual circle on either side, so this lands the circles' outer edges
      // on 24 — flush with the step title below. Padding to 24 would push them
      // visibly inboard of the text they head.
      padding: const EdgeInsets.fromLTRB(19, 6, 19, 2),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Back only exists when there is somewhere to go. It keeps its slot
            // reserved either way so the heading never shifts as it appears.
            Align(
              alignment: Alignment.centerLeft,
              child: _HeaderSlot(
                visible: !isRoot,
                child: _HeaderButton(
                  icon: Icons.arrow_back_rounded,
                  semanticLabel: 'Back',
                  onTap: back,
                  color: scheme.onSurface,
                  isDark: isDark,
                ),
              ),
            ),
            Text(
              widget.heading,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            // Close never moves and never changes meaning — one tap out of the
            // whole flow, from any depth, always in the same place.
            Align(
              alignment: Alignment.centerRight,
              child: _HeaderButton(
                icon: Icons.close_rounded,
                semanticLabel: 'Close',
                onTap: close,
                color: scheme.onSurface,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMorphingBody(
    ThemeData theme,
    ColorScheme scheme,
    MediaQueryData mq,
  ) {
    // The three pieces below are load-bearing together:
    //
    // 1. AnimatedSize is anchored to bottomCenter. The default (topCenter) pins
    //    the top edge and grows downward, off the bottom of the screen; anchored
    //    at the bottom, a taller step glides upward and the sheet's bottom edge
    //    never moves.
    // 2. The AnimatedSwitcher below uses a layoutBuilder that takes outgoing
    //    children out of the layout, or the Stack would immediately measure as
    //    tall as the taller step and the size would snap instead of animating.
    // 3. The cap plus a scroll view means a long step scrolls rather than
    //    overflowing, while short steps stay short.
    return AnimatedSize(
      alignment: Alignment.bottomCenter,
      duration: _morph,
      curve: Curves.easeOutQuint,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: mq.size.height * _maxBodyFraction,
        ),
        child: SingleChildScrollView(
          child: AnimatedSwitcher(
            // Asymmetric on purpose. The outgoing step leaves quickly and gets
            // out of the way; the incoming one takes its time arriving, under
            // a resize that is longer still. Symmetric timings are what made
            // this read as a plain dissolve.
            duration: const Duration(milliseconds: 300),
            reverseDuration: const Duration(milliseconds: 130),
            switchInCurve: easeOutQuint,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder:
                (Widget? currentChild, List<Widget> previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: <Widget>[
                      // Positioned children do not contribute to a Stack's
                      // size, so the Stack measures the incoming step alone.
                      ...previousChildren.map(
                        (Widget child) =>
                            Positioned(left: 0, right: 0, top: 0, child: child),
                      ),
                      ?currentChild,
                    ],
                  );
                },
            transitionBuilder: (Widget child, Animation<double> animation) {
              // Scale as well as fade, so a step recedes and its replacement
              // grows into the space rather than simply appearing there. Kept
              // direction-agnostic: AnimatedSwitcher replays an outgoing
              // child's own transition in reverse, so anything with a left/
              // right sense would run the wrong way on the way out.
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
                  child: child,
                ),
              );
            },
            child: _buildStep(_stack.last, theme, scheme),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(MorphStep step, ThemeData theme, ColorScheme scheme) {
    return Padding(
      key: ValueKey<String>(step.id),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      // Title, subtitle and grid arrive on a short cascade instead of together.
      // A single block appearing at one instant is what reads as unconsidered;
      // ~50 ms between elements is enough to feel authored without feeling slow.
      // The grid itself staggers its own tiles on top of this.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          EntryReveal(
            slideY: 8,
            duration: const Duration(milliseconds: 380),
            child: Text(
              step.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          if (step.subtitle != null) ...<Widget>[
            const SizedBox(height: 4),
            EntryReveal(
              slideY: 8,
              delay: const Duration(milliseconds: 50),
              duration: const Duration(milliseconds: 380),
              child: Text(
                step.subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTokens.secondaryLabel(scheme),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          step.builder(context, this),
        ],
      ),
    );
  }
}

/// Reserves a button's slot whether or not the button is currently offered.
///
/// Holding the space means the heading never jumps sideways as back appears;
/// fading and sliding it in from the left says where it came from. Hidden, it
/// takes no taps and is invisible to a screen reader.
class _HeaderSlot extends StatelessWidget {
  const _HeaderSlot({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const Duration duration = Duration(milliseconds: 280);
    return ExcludeSemantics(
      excluding: !visible,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(-0.3, 0),
          duration: duration,
          curve: easeOutQuint,
          child: AnimatedScale(
            scale: visible ? 1 : 0.8,
            duration: duration,
            curve: easeOutQuint,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A circular header control.
///
/// Deliberately not an [InkResponse]: Material's ink draws a rectangular
/// highlight on a circular control, and nothing else in this app uses ink.
/// [BounceTap] is the house press treatment.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: BounceTap(
          onTap: onTap,
          // 0.96 is the app's press depth (BounceTap's own default, and what
          // AddFab uses). 0.90 on a control this small read as rubbery.
          scaleFactor: 0.96,
          // The visual circle is 34, but the tap box is 44 — the platform
          // minimum. BounceTap hit-tests its child, so sizing the target to
          // the artwork made the button easy to miss.
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.10 : 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color.withValues(alpha: 0.85),
                  size: 19,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
