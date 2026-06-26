import 'package:flutter/material.dart';

class CarouselItem {
  const CarouselItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

enum FeatureStepState { idle, loading, success }

class FeatureStep {
  FeatureStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  FeatureStepState state = FeatureStepState.idle;
}

class OnboardingContent {
  static const Color fuseBlue = Color(0xFF007AFF);
  static const Color fuseCyan = Color(0xFF00D4FF);

  static const List<CarouselItem> carouselItems = <CarouselItem>[
    CarouselItem(label: 'Documents', icon: Icons.bar_chart_rounded),
    CarouselItem(label: 'Scan', icon: Icons.document_scanner_outlined),
    CarouselItem(label: 'Verify', icon: Icons.nfc_rounded),
    CarouselItem(label: 'Passes', icon: Icons.confirmation_number_outlined),
    CarouselItem(label: 'Travel', icon: Icons.flight_takeoff_rounded),
  ];

  static const String welcomeTitle = 'Your wallet,\nupgraded.';
  static const String welcomeDescription =
      'Save passports, IDs, and travel passes in one refined offline workspace.';

  static List<FeatureStep> featureSteps() => <FeatureStep>[
    FeatureStep(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Your Wallet',
      description:
          'SlickPort holds IDs — passports, PAN, and Aadhaar — alongside travel passes in one secure local wallet. Everything stays on your device.',
      accent: fuseBlue,
    ),
    FeatureStep(
      icon: Icons.document_scanner_rounded,
      title: 'Documents & Capture',
      description:
          'Tap + to add a passport or ID. Aim the camera at the MRZ zone and fields fill automatically — review and save in the capture studio.',
      accent: const Color(0xFF0A84FF),
    ),
    FeatureStep(
      icon: Icons.nfc_rounded,
      title: 'E-Passport & NFC',
      description:
          'Biometric passports carry an NFC chip. MRZ-derived access keys unlock a calm verification read while sensitive data stays offline.',
      accent: const Color(0xFF32ADE6),
    ),
    FeatureStep(
      icon: Icons.confirmation_number_rounded,
      title: 'Travel Passes',
      description:
          'Preview train passes with live journey progress. Flights, buses, and event passes are on the roadmap — adding tickets arrives in a future update.',
      accent: const Color(0xFF5AC8FA),
    ),
  ];

  static const String completionLoadingTitle = 'Preparing your wallet';
  static const String completionLoadingDescription =
      'Staging your documents and passes workspace.';
  static const String completionSuccessTitle = "You're ready";
  static const String completionSuccessDescription =
      'Enter SlickPort and tap + to add your first document.';
}