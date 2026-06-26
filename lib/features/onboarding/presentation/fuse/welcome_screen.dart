import 'package:flutter/material.dart';

import '../../domain/onboarding_content.dart';
import 'widgets/onboarding_cta.dart';
import 'widgets/text_carousel.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(42, 16, 42, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Text Carousel at the top-left, with some spacing below the notch
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: TextCarousel(items: OnboardingContent.carouselItems),
                  ),
                  const Spacer(),
                  // Wallet Icon Indicator
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Color(0xFF007AFF),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Welcome Title
                  Text(
                    OnboardingContent.welcomeTitle,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 34,
                      height: 1.06,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Welcome Description
                  Text(
                    OnboardingContent.welcomeDescription,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.55),
                      fontSize: 16,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Continue button
                  OnboardingCta(label: 'Continue', onPressed: onContinue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}