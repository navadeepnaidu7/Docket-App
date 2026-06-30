import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'bounce_tap.dart';

/// Uber-style bottom actions: full-width primary + optional text secondary.
class StudioActionBar extends StatelessWidget {
  const StudioActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: AppTokens.separator(scheme), width: 0.5),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            BounceTap(
              onTap: onPrimary,
              child: Container(
                height: 56,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.onSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  primaryLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.surface,
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
            if (secondaryLabel != null && onSecondary != null) ...<Widget>[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onSecondary,
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  foregroundColor: scheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  secondaryLabel!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}