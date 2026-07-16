import 'package:flutter/material.dart';

import '../../domain/onboarding_content.dart';
import '../../../../shared/widgets/completion_celebration.dart';

class CompletionStep extends StatelessWidget {
  const CompletionStep({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return CompletionCelebration(
      loadingTitle: OnboardingContent.completionLoadingTitle,
      loadingDescription: OnboardingContent.completionLoadingDescription,
      successTitle: OnboardingContent.completionSuccessTitle,
      successDescription: OnboardingContent.completionSuccessDescription,
      actionLabel: 'Enter Docket',
      onComplete: onComplete,
    );
  }
}
