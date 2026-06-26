import 'package:flutter/material.dart';

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
  bool _isAdvancing = false;
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _stepKeys = <GlobalKey>[];

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

  void _handleSubmit(int index) {
    if (_isAdvancing || index != _currentStep) return;
    _isAdvancing = true;

    if (index >= widget.steps.length - 1) {
      widget.onFinished();
      _isAdvancing = false;
      return;
    }

    final int nextStep = index + 1;
    setState(() {
      widget.steps[index].state = FeatureStepState.success;
      _currentStep = nextStep;
      widget.steps[nextStep].state = FeatureStepState.idle;
    });
    widget.onStepAccentChanged(widget.steps[nextStep].accent);
    _scrollToCurrentStep();

    // Reset _isAdvancing guard after the transition completes
    Future<void>.delayed(stepAdvanceDuration, () {
      if (mounted) {
        _isAdvancing = false;
      }
    });
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
                        isExpanded: index == _currentStep,
                        isPast: index < _currentStep,
                        isFuture: index > _currentStep,
                      ),
                    );
                  }),
                  const SizedBox(height: 64),
                  OnboardingStepCta(
                    stepIndex: _currentStep,
                    state: widget.steps[_currentStep].state,
                    onPressed: () => _handleSubmit(_currentStep),
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