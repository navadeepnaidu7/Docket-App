import 'package:flutter/material.dart';

import '../../core/haptics/haptic_service.dart';
import '../../core/motion/entry_reveal.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/prompt_typography.dart';
import '../widgets/bounce_tap.dart';
import 'prompt_flow_controller.dart';
import 'prompt_step.dart';

/// Chrome for a prompted flow: back, progress, the question, and one action.
///
/// The body of each step is supplied by [stepBuilder] so this file stays free
/// of document-specific knowledge — the passport and ID flows share it.
///
/// Layout is fixed so nothing shifts sideways or jumps vertically between
/// steps: everything aligns to [Space.gutter], and the error lane reserves its
/// height whether or not a message is showing, so the CTA never moves when
/// validation fails.
class PromptFlowScreen extends StatefulWidget {
  const PromptFlowScreen({
    super.key,
    required this.controller,
    required this.stepBuilder,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.onExit,
    this.primaryEnabled = true,
    this.showPrimary = true,
    this.showChrome = true,
    this.minimal = false,
  });

  final PromptFlowController controller;

  /// Builds the interactive part of a step (input, choices, action UI).
  final Widget Function(BuildContext context, PromptStep step) stepBuilder;

  final String primaryLabel;
  final VoidCallback onPrimary;

  /// Tertiary action under the CTA — "Skip", "Type it in instead".
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Called when back is pressed on the first step.
  final VoidCallback? onExit;

  final bool primaryEnabled;

  /// False on steps whose answer *is* the tap (the route chooser). A disabled
  /// button there is a dead control and a block of wasted space.
  final bool showPrimary;

  /// Action steps (camera, NFC) hide the question block and own the body.
  final bool showChrome;
  final bool minimal;

  @override
  State<PromptFlowScreen> createState() => _PromptFlowScreenState();
}

class _PromptFlowScreenState extends State<PromptFlowScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onFlowChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onFlowChanged);
    super.dispose();
  }

  void _onFlowChanged() => setState(() {});

  /// Unwinds one step, or leaves the flow when there is nowhere left to go.
  ///
  /// Exits with `Navigator.pop`, never `maybePop`. `maybePop` consults the
  /// enclosing [PopScope], which is this widget — so calling it from inside the
  /// pop handler re-enters the handler and spins the UI thread until Android
  /// shows "app isn't responding".
  void _handleBack() {
    HapticService.select();
    if (widget.controller.back()) return;

    if (widget.onExit != null) {
      widget.onExit!();
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final PromptFlowController c = widget.controller;
    final PromptStep step = c.current;

    return PopScope(
      // Only intercept while there is flow left to unwind. On the first step the
      // system pop is allowed through, so the back gesture behaves normally and
      // cannot bounce off a handler that refuses to let go.
      canPop: c.isFirstStep,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        // The footer is padded by viewInsets instead, so the CTA rides the
        // keyboard the way iOS does without any padding arithmetic.
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Chrome(
                controller: c,
                onBack: _handleBack,
                minimal: widget.minimal,
              ),
              if (!widget.minimal) _Progress(value: c.progress, scheme: scheme),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Duration(
                    milliseconds: MediaQuery.disableAnimationsOf(context)
                        ? 120
                        : 400,
                  ),
                  switchInCurve: easeOutQuint,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (Widget child, Animation<double> anim) {
                    final bool reduced = MediaQuery.disableAnimationsOf(
                      context,
                    );
                    if (reduced) {
                      return FadeTransition(opacity: anim, child: child);
                    }
                    // Incoming and outgoing must travel opposite ways or both
                    // drift off the same edge and the heading appears to swap
                    // in place. Key equality tells us which child is arriving.
                    final bool back = c.direction == PromptDirection.backward;
                    final bool incoming =
                        child.key == ValueKey<String>(step.id);
                    final double dx = back ? -0.06 : 0.06;
                    final Offset begin = incoming
                        ? Offset(dx, 0)
                        : Offset(-dx, 0);
                    return FadeTransition(
                      opacity: anim.drive(
                        CurveTween(curve: const Interval(0.0, 0.9)),
                      ),
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: begin,
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    );
                  },
                  layoutBuilder: (Widget? current, List<Widget> previous) {
                    // Top-left aligned so a short step does not visually
                    // centre-jump against a tall one mid-crossfade.
                    return Stack(
                      alignment: Alignment.topLeft,
                      fit: StackFit.expand,
                      children: <Widget>[
                        for (final child in previous)
                          ExcludeFocus(
                            child: IgnorePointer(
                              child: ExcludeSemantics(child: child),
                            ),
                          ),
                        ?current,
                      ],
                    );
                  },
                  // Keyed on the step id, not an index. Keying on an index is
                  // why the screen this replaces animated not at all between
                  // two steps that happened to share a progress position.
                  child: _StepBody(
                    key: ValueKey<String>(step.id),
                    question: c.currentQuestion,
                    helper: step.helper?.call(c.state),
                    error: c.currentError,
                    minimal: widget.minimal,
                    showChrome: widget.showChrome,
                    child: widget.stepBuilder(context, step),
                  ),
                ),
              ),
              _Footer(
                primaryLabel: widget.primaryLabel,
                onPrimary: widget.onPrimary,
                primaryEnabled: widget.primaryEnabled,
                showPrimary: widget.showPrimary,
                secondaryLabel: widget.secondaryLabel,
                onSecondary: widget.onSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Back control and step counter.
class _Chrome extends StatelessWidget {
  const _Chrome({
    required this.controller,
    required this.onBack,
    required this.minimal,
  });

  final bool minimal;

  final PromptFlowController controller;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return SizedBox(
      height: AppTheme.controlHeightSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.x2),
        child: Row(
          children: <Widget>[
            // A bare chevron in a 44pt target. The filled circle it replaces
            // was decoration on a control that is already unambiguous.
            SizedBox(
              width: AppTheme.controlHeightSm,
              height: AppTheme.controlHeightSm,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onBack,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 26,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
            const Spacer(),
            if (!minimal && controller.stepCount > 1)
              Padding(
                padding: const EdgeInsets.only(right: Space.x3),
                child: Text(
                  '${controller.currentIndex + 1} / ${controller.stepCount}',
                  style: text.promptStepCount(scheme),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A 2px hairline. Flat fill, no gradient — it is a progress readout, not an
/// ornament.
class _Progress extends StatelessWidget {
  const _Progress({required this.value, required this.scheme});

  final double value;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: SizedBox(
          height: 2,
          child: Stack(
            children: <Widget>[
              ColoredBox(
                color: AppTokens.separator(scheme),
                child: const SizedBox.expand(),
              ),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 320),
                curve: easeOutQuint,
                widthFactor: value.clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: ColoredBox(color: scheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Question, helper, body and the reserved error lane.
class _StepBody extends StatelessWidget {
  const _StepBody({
    super.key,
    required this.question,
    required this.helper,
    required this.error,
    required this.minimal,
    required this.child,
    required this.showChrome,
  });

  final String question;
  final String? helper;
  final String? error;
  final bool minimal;
  final Widget child;
  final bool showChrome;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme text = theme.textTheme;

    // Centred in the space between the progress bar and the CTA, rather than
    // pinned to the top with the rest of the screen left empty. On a tall
    // phone one question and one input read as a deliberate composition; hung
    // from the top they read as a form that ran out of content.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.x6,
            Space.gutter,
            Space.x6,
          ),
          child: ConstrainedBox(
            // Fill the viewport so centring has room to work, but let the
            // column grow past it and scroll when the keyboard is up or the
            // text is scaled.
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - Space.x6 * 2).clamp(
                0.0,
                double.infinity,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: minimal
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.start,
              children: <Widget>[
                if (showChrome) ...<Widget>[
                  EntryReveal(
                    enabled:
                        !minimal && !MediaQuery.disableAnimationsOf(context),
                    slideY: 12,
                    duration: const Duration(milliseconds: 320),
                    child: Text(
                      question,
                      textAlign: minimal ? TextAlign.center : TextAlign.start,
                      style: minimal
                          ? text.promptQuestion.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.45,
                              height: 1.25,
                            )
                          : text.promptQuestion,
                      maxLines: 3,
                      // Large accessibility sizes would otherwise push the input off
                      // a short screen entirely.
                      textScaler: TextScaler.linear(
                        MediaQuery.textScalerOf(
                          context,
                        ).scale(1.0).clamp(1.0, 1.3),
                      ),
                    ),
                  ),
                  if (helper != null && helper!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: Space.x2),
                    EntryReveal(
                      enabled:
                          !minimal && !MediaQuery.disableAnimationsOf(context),
                      slideY: 10,
                      delay: const Duration(milliseconds: 40),
                      duration: const Duration(milliseconds: 320),
                      child: Text(
                        helper!,
                        textAlign: minimal ? TextAlign.center : TextAlign.start,
                        style: text
                            .promptHelper(scheme)
                            .copyWith(
                              fontSize: minimal ? 13 : 15,
                              letterSpacing:
                                  minimal &&
                                      RegExp(r'^[A-Z0-9]+$').hasMatch(helper!)
                                  ? 1.8
                                  : 0,
                            ),
                      ),
                    ),
                  ],
                  const SizedBox(height: Space.x8),
                ],
                EntryReveal(
                  enabled: !minimal && !MediaQuery.disableAnimationsOf(context),
                  slideY: 10,
                  delay: const Duration(milliseconds: 80),
                  duration: const Duration(milliseconds: 320),
                  child: child,
                ),
                // Reserved whether or not an error is showing, so the CTA
                // below never jumps when validation fails.
                SizedBox(
                  height: error == null ? 40 : null,
                  child: error == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(
                            top: Space.x1,
                            left: 2,
                          ),
                          child: Text(
                            error!,
                            textAlign: minimal
                                ? TextAlign.center
                                : TextAlign.start,
                            style: text.promptError,
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Sticky CTA plus optional tertiary action, padded to ride the keyboard.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.primaryLabel,
    required this.onPrimary,
    required this.primaryEnabled,
    required this.showPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool primaryEnabled;
  final bool showPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final MediaQueryData mq = MediaQuery.of(context);
    final double keyboard = mq.viewInsets.bottom;

    final Color fill = isDark ? scheme.primary : scheme.onSurface;
    final Color label = isDark ? scheme.onPrimary : scheme.surface;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x3,
        Space.gutter,
        (keyboard > 0 ? keyboard : mq.padding.bottom) + Space.x3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showPrimary)
            Opacity(
              opacity: primaryEnabled ? 1 : 0.45,
              child: BounceTap(
                scaleFactor: 0.975,
                onTap: primaryEnabled ? onPrimary : null,
                child: Container(
                  height: AppTheme.controlHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    primaryLabel,
                    style: theme.textTheme.promptCta.copyWith(color: label),
                  ),
                ),
              ),
            ),
          if (secondaryLabel != null) ...<Widget>[
            const SizedBox(height: Space.x1),
            SizedBox(
              height: AppTheme.controlHeightSm,
              child: TextButton(
                onPressed: onSecondary,
                child: Text(
                  secondaryLabel!,
                  style: theme.textTheme
                      .promptHelper(scheme)
                      .copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface.withValues(alpha: 0.75),
                      ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
