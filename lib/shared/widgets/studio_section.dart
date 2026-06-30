import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Flat iOS Settings–style grouped section (no blur).
class StudioSection extends StatelessWidget {
  const StudioSection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTokens.groupedFieldFill(scheme, isDark: isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: AppTokens.separator(scheme),
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}