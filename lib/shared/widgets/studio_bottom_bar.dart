import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'bounce_tap.dart';

/// Uber-style pinned bottom bar with a single full-width primary action.
class StudioBottomBar extends StatelessWidget {
  const StudioBottomBar({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: AppTokens.separator(scheme), width: 0.5),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
        child: BounceTap(
          onTap: onTap,
          child: Container(
            height: 56,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.onSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.surface,
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
          ),
        ),
      ),
    );
  }
}