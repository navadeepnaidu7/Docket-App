import 'package:flutter/material.dart';

import '../../../domain/onboarding_content.dart';
import '../../../../../core/motion/smooth_curves.dart';

class AccordionStep extends StatelessWidget {
  const AccordionStep({
    super.key,
    required this.step,
    required this.stepIndex,
    required this.isExpanded,
    required this.isPast,
    required this.isFuture,
  });

  final FeatureStep step;
  final int stepIndex;
  final bool isExpanded;
  final bool isPast;
  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    final Color tone = isFuture
        ? Colors.black.withValues(alpha: 0.28)
        : Colors.black.withValues(alpha: 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            AnimatedContainer(
              duration: stepAdvanceDuration,
              curve: smoothCurve,
              width: isExpanded ? 34 : 20,
              height: isExpanded ? 34 : 20,
              decoration: BoxDecoration(
                color: isExpanded
                    ? step.accent.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(isExpanded ? 10 : 0),
              ),
              child: Center(
                child: AnimatedScale(
                  scale: isExpanded ? 1.0 : 20 / 18,
                  duration: stepAdvanceDuration,
                  curve: smoothCurve,
                  child: Icon(
                    step.icon,
                    size: 18,
                    color: isExpanded ? step.accent : tone,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedSlide(
                duration: stepAdvanceDuration,
                curve: smoothCurve,
                offset: isExpanded ? Offset.zero : const Offset(0, 0.06),
                child: AnimatedDefaultTextStyle(
                  duration: stepAdvanceDuration,
                  curve: smoothCurve,
                  style: TextStyle(
                    color: isExpanded ? Colors.black : tone,
                    fontSize: isExpanded ? 32 : 22,
                    height: isExpanded ? 1.02 : 1.2,
                    fontWeight: isExpanded ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: isExpanded ? -0.5 : -0.2,
                  ),
                  child: Text(step.title),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: (!isExpanded && isPast && step.state == FeatureStepState.success) ? 1.0 : 0.0,
              duration: stepAdvanceDuration,
              curve: smoothCurve,
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Icon(Icons.check_circle_rounded, size: 20, color: step.accent),
              ),
            ),
          ],
        ),
        _RevealDescription(
          isExpanded: isExpanded,
          description: step.description,
        ),
      ],
    );
  }
}

class _RevealDescription extends StatefulWidget {
  const _RevealDescription({
    required this.isExpanded,
    required this.description,
  });

  final bool isExpanded;
  final String description;

  @override
  State<_RevealDescription> createState() => _RevealDescriptionState();
}

class _RevealDescriptionState extends State<_RevealDescription>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: stepAdvanceDuration,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: smoothCurve),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: smoothCurve));

    if (widget.isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _RevealDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded && !oldWidget.isExpanded) {
      _controller.forward(from: 0);
    } else if (!widget.isExpanded && oldWidget.isExpanded) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedAlign(
        duration: stepAdvanceDuration,
        curve: smoothCurve,
        alignment: Alignment.topCenter,
        heightFactor: widget.isExpanded ? 1.0 : 0.0,
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 16),
                Text(
                  widget.description,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.55),
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingStepCta extends StatelessWidget {
  const OnboardingStepCta({
    super.key,
    required this.stepIndex,
    required this.state,
    required this.onPressed,
  });

  final int stepIndex;
  final FeatureStepState state;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (Widget? current, List<Widget> previous) => current ?? const SizedBox.shrink(),
      child: switch (state) {
        FeatureStepState.loading => _ctaShell(
            key: const ValueKey<String>('loading'),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
          ),
        FeatureStepState.success => _ctaShell(
            key: const ValueKey<String>('success'),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
          ),
        FeatureStepState.idle => SizedBox(
            key: ValueKey<String>('got-it-$stepIndex'),
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text(
                'Got it',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
      },
    );
  }

  Widget _ctaShell({required Widget child, Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(child: child),
    );
  }
}