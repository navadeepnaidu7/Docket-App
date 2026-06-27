import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/onboarding_content.dart';
import '../../../../core/motion/smooth_curves.dart';
import 'widgets/accordion_step.dart';

class MultiStepForm extends StatefulWidget {
  const MultiStepForm({
    super.key,
    required this.steps,
    required this.onStepAccentChanged,
    required this.onFinished,
  });

  final List<FeatureStep> steps;
  final ValueChanged<Color> onStepAccentChanged;
  final VoidCallback onFinished;

  @override
  State<MultiStepForm> createState() => _MultiStepFormState();
}

class _MultiStepFormState extends State<MultiStepForm> {
  int _currentStep = 0;
  int? _expandedStep = 0;
  bool _isAdvancing = false;
  bool _showAuthButtons = false;
  bool _isGoogleLoggingIn = false;
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _stepKeys = <GlobalKey>[];
  final GlobalKey _authButtonsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _stepKeys.addAll(
      List<GlobalKey>.generate(widget.steps.length, (_) => GlobalKey()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onStepAccentChanged(widget.steps.first.accent);
      _scrollToCurrentStep();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentStep() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? context = _stepKeys[_currentStep].currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: stepAdvanceDuration,
        curve: smoothCurve,
        alignment: 0.05,
      );
    });
  }

  void _scrollToAuthButtons() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? context = _authButtonsKey.currentContext;
      if (context == null) return;
      final bool isTesting = Platform.environment.containsKey('FLUTTER_TEST');
      Scrollable.ensureVisible(
        context,
        duration: isTesting ? Duration.zero : const Duration(milliseconds: 500),
        curve: smoothCurve,
        alignment: 0.95,
      );
    });
  }

  void _handleSubmit(int index) {
    if (_isAdvancing || index != _currentStep) return;
    _isAdvancing = true;

    if (index >= widget.steps.length - 1) {
      setState(() => widget.steps[index].state = FeatureStepState.success);

      // Stagger: success checkmark → collapse accordion → reveal auth buttons.
      Future<void>.delayed(const Duration(milliseconds: 360), () {
        if (!mounted) return;
        setState(() => _expandedStep = null);
        Future<void>.delayed(const Duration(milliseconds: 280), () {
          if (!mounted) return;
          setState(() => _showAuthButtons = true);
          _scrollToAuthButtons();
          Future<void>.delayed(stepAdvanceDuration, () {
            if (mounted) _isAdvancing = false;
          });
        });
      });
      return;
    }

    final int nextStep = index + 1;
    setState(() => widget.steps[index].state = FeatureStepState.success);

    // Stagger: success checkmark → collapse current → expand next.
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => _expandedStep = null);

      Future<void>.delayed(const Duration(milliseconds: 220), () {
        if (!mounted) return;
        setState(() {
          _currentStep = nextStep;
          _expandedStep = nextStep;
          widget.steps[nextStep].state = FeatureStepState.idle;
        });
        widget.onStepAccentChanged(widget.steps[nextStep].accent);
        _scrollToCurrentStep();

        Future<void>.delayed(stepAdvanceDuration, () {
          if (mounted) _isAdvancing = false;
        });
      });
    });
  }

  void _handleAuthFinished({required bool isGoogle}) {
    if (_isAdvancing) return;
    _isAdvancing = true;

    if (isGoogle) {
      setState(() => _isGoogleLoggingIn = true);
      // Simulate loading for 800ms
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          widget.onFinished();
          _isAdvancing = false;
        }
      });
    } else {
      widget.onFinished();
      _isAdvancing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(42, 28, 42, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Spacer(),
                  // Accordion steps
                  ...List<Widget>.generate(widget.steps.length, (int index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == widget.steps.length - 1 ? 0 : 32,
                      ),
                      child: AccordionStep(
                        key: _stepKeys[index],
                        step: widget.steps[index],
                        stepIndex: index,
                        isExpanded: index == _expandedStep,
                        isPast: index < _currentStep ||
                            (widget.steps[index].state == FeatureStepState.success &&
                                index != _expandedStep),
                        isFuture: index > _currentStep,
                      ),
                    );
                  }),
                  const SizedBox(height: 40),
                  AnimatedCrossFade(
                    duration: stepAdvanceDuration,
                    sizeCurve: smoothCurve,
                    firstCurve: smoothCurve,
                    secondCurve: smoothCurve,
                    alignment: Alignment.topCenter,
                    crossFadeState: _showAuthButtons
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: SizedBox(
                      width: double.infinity,
                      child: OnboardingStepCta(
                        key: const ValueKey<String>('step_cta'),
                        stepIndex: _currentStep,
                        state: widget.steps[_currentStep].state,
                        onPressed: () => _handleSubmit(_currentStep),
                      ),
                    ),
                    secondChild: SizedBox(
                      width: double.infinity,
                      child: Column(
                        key: _authButtonsKey,
                        mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Center(
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: _isGoogleLoggingIn
                                  ? null
                                  : () => _handleAuthFinished(isGoogle: true),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _isGoogleLoggingIn
                                    ? Container(
                                        key: const ValueKey<String>('google_loading'),
                                        height: 54,
                                        width: 236.25,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF131314),
                                          borderRadius: BorderRadius.circular(27),
                                          border: Border.all(
                                            color: const Color(0xFF8E918F),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Color(0xFFE3E3E3),
                                            ),
                                          ),
                                        ),
                                      )
                                    : SvgPicture.asset(
                                        'assets/identity/android_dark_rd_SI.svg',
                                        key: const ValueKey<String>('google_button'),
                                        height: 54,
                                        width: 236.25,
                                        fit: BoxFit.contain,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: _isGoogleLoggingIn
                                ? null
                                : () => _handleAuthFinished(isGoogle: false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Skip, I will login later',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.45),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}