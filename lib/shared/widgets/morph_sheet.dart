import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/haptics/haptic_service.dart';
import '../../core/theme/app_theme.dart';

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
  static const Duration _morph = Duration(milliseconds: 380);

  /// Fraction of the screen the *step body* may occupy before it scrolls.
  /// Header and chrome sit outside this, so the sheet still leaves the wallet
  /// visible behind it.
  static const double _maxBodyFraction = 0.66;

  @override
  bool get isRoot => _stack.length == 1;

  @override
  void push(MorphStep step) {
    HapticService.select();
    setState(() => _stack = <MorphStep>[..._stack, step]);
  }

  @override
  void back() {
    if (isRoot) return;
    HapticService.select();
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
          borderRadius: BorderRadius.circular(AppTheme.radiusSheet),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppTokens.sheetBackground(scheme),
                borderRadius: BorderRadius.circular(AppTheme.radiusSheet),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            height: 44,
            width: double.infinity,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _HeaderButton(
                isRoot: isRoot,
                onTap: isRoot ? close : back,
                color: scheme.onSurface,
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
        ],
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
            duration: const Duration(milliseconds: 260),
            reverseDuration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder:
                (Widget? currentChild, List<Widget> previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: <Widget>[
                      // Positioned children do not contribute to a Stack's
                      // size, so the Stack measures the incoming step alone.
                      ...previousChildren.map(
                        (Widget child) => Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: child,
                        ),
                      ),
                      ?currentChild,
                    ],
                  );
                },
            transitionBuilder: (Widget child, Animation<double> animation) {
              // Vertical drift rather than a horizontal slide: it reads the
              // same forwards and backwards, so there is no wrong-direction
              // artifact when AnimatedSwitcher replays an outgoing child's
              // transition in reverse.
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(animation),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            step.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          if (step.subtitle != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              step.subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTokens.secondaryLabel(scheme),
                fontWeight: FontWeight.w500,
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

/// Close at the root, back deeper in — cross-faded so the change is visible.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.isRoot,
    required this.onTap,
    required this.color,
  });

  final bool isRoot;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isRoot ? 'Close' : 'Back',
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 44,
          height: 44,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isRoot ? Icons.close_rounded : Icons.arrow_back_rounded,
              key: ValueKey<bool>(isRoot),
              color: color,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
