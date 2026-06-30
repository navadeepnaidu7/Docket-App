import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'bounce_tap.dart';

class StudioCircleButton extends StatelessWidget {
  const StudioCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final ColorScheme scheme = theme.colorScheme;

    return BounceTap(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : scheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          border: Border.all(
            color: AppTokens.separator(scheme),
            width: 0.5,
          ),
        ),
        child: Icon(icon, color: scheme.onSurface, size: 22),
      ),
    );
  }
}