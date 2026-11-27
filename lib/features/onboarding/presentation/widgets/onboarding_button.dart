import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/bounce_tap.dart';
import '../onboarding_palette.dart';

enum OnboardingButtonStyle {
  /// Sky pill with white label, on paper or night.
  sky,

  /// Porcelain pill with a sky label, on the sky stage.
  porcelain,

  /// Translucent white pill, the quieter choice on the sky stage.
  glass,

  /// Outlined pill, the quieter choice on paper or night.
  outline,
}

/// Full-width pill used for every onboarding action.
class OnboardingButton extends StatelessWidget {
  const OnboardingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = OnboardingButtonStyle.sky,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final OnboardingButtonStyle style;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final Brightness b = Theme.of(context).brightness;
    final (Decoration deco, Color fg) = switch (style) {
      OnboardingButtonStyle.sky => (
        BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF4A9FF5), OnboardingPalette.skyTop],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: OnboardingPalette.skyTop.withValues(
                alpha: b == Brightness.dark ? 0.30 : 0.32,
              ),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        Colors.white,
      ),
      OnboardingButtonStyle.porcelain => (
        BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          color: Colors.white,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: OnboardingPalette.skyShade.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        OnboardingPalette.skyTop,
      ),
      OnboardingButtonStyle.glass => (
        BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          color: Colors.white.withValues(alpha: 0.16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.42),
            width: 1,
          ),
        ),
        Colors.white,
      ),
      OnboardingButtonStyle.outline => (
        BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          border: Border.all(
            color: OnboardingPalette.ink(b).withValues(alpha: 0.16),
            width: 1,
          ),
        ),
        OnboardingPalette.ink(b),
      ),
    };

    return BounceTap(
      onTap: busy ? null : onPressed,
      child: Container(
        height: AppTheme.controlHeight,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: deco,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: busy
              ? SizedBox(
                  key: const ValueKey<String>('busy'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fg,
                  ),
                )
              : Text(
                  label,
                  key: ValueKey<String>(label),
                  style: AppFonts.ui(
                    color: fg,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
        ),
      ),
    );
  }
}
