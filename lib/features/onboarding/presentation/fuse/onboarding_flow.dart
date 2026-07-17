import 'package:flutter/material.dart';

import '../../domain/onboarding_content.dart';
import '../../../../core/motion/smooth_curves.dart';
import 'completion_step.dart';
import 'multi_step_form.dart';
import 'welcome_screen.dart';
import 'widgets/onboarding_background.dart';

enum OnboardingPhase { welcome, featureTour, completion }

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  OnboardingPhase _phase = OnboardingPhase.welcome;
  Color _accent = OnboardingContent.fuseBlue;
  late final List<FeatureStep> _steps = OnboardingContent.featureSteps();

  BackgroundMode get _backgroundMode {
    return switch (_phase) {
      OnboardingPhase.welcome => BackgroundMode.welcome,
      OnboardingPhase.featureTour => BackgroundMode.feature,
      OnboardingPhase.completion => BackgroundMode.plain,
    };
  }

  void _handleWelcomeContinue() {
    setState(() {
      _phase = OnboardingPhase.featureTour;
      _accent = _steps.first.accent;
    });
  }

  void _handleFeatureTourFinished() {
    setState(() => _phase = OnboardingPhase.completion);
  }

  Widget _buildForeground() {
    return switch (_phase) {
      OnboardingPhase.welcome => WelcomeScreen(onContinue: _handleWelcomeContinue),
      OnboardingPhase.featureTour => MultiStepForm(
          steps: _steps,
          onStepAccentChanged: (Color accent) => setState(() => _accent = accent),
          onFinished: _handleFeatureTourFinished,
        ),
      OnboardingPhase.completion => CompletionStep(onComplete: widget.onComplete),
    };
  }

  @override
  Widget build(BuildContext context) {
    final Color scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          OnboardingBackground(
            mode: _backgroundMode,
            accent: _accent,
            visible: _phase != OnboardingPhase.completion,
          ),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: smoothDuration,
              switchInCurve: smoothCurve,
              switchOutCurve: smoothCurve,
              child: KeyedSubtree(
                key: ValueKey<OnboardingPhase>(_phase),
                child: _buildForeground(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}