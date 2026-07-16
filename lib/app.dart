import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';

class DocketApp extends ConsumerWidget {
  final bool hasSeenOnboarding;
  const DocketApp({super.key, required this.hasSeenOnboarding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Docket',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: hasSeenOnboarding ? const DashboardScreen() : const OnboardingScreen(),
    );
  }
}
