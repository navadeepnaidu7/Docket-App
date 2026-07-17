import 'package:flutter/material.dart';

import '../../../../../shared/widgets/bounce_tap.dart';

class OnboardingCta extends StatelessWidget {
  const OnboardingCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.inverted = false,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool inverted;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color ink = scheme.onSurface;
    final Color surface = scheme.surface;

    // inverted: filled primary-ink button; default: elevated surface button
    final Color background = inverted ? ink : surface;
    final Color foreground = inverted ? scheme.surface : ink;

    return BounceTap(
      onTap: isLoading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: inverted
              ? null
              : Border.all(
                  color: scheme.outline.withValues(alpha: 0.35),
                  width: 0.5,
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            else ...<Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, color: foreground, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
