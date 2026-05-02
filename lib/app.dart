import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';

class SlickPortApp extends StatelessWidget {
  final bool hasSeenOnboarding;
  const SlickPortApp({super.key, required this.hasSeenOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SlickPort',
      theme: AppTheme.lightTheme,
      home: hasSeenOnboarding ? const DashboardScreen() : const OnboardingScreen(),
    );
  }
}
