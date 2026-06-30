import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'bounce_tap.dart';

class StudioPrimaryButton extends StatelessWidget {
  const StudioPrimaryButton({
    super.key,
    required this.onTap,
    this.label = 'Save',
    this.icon = Icons.save_rounded,
  });

  final VoidCallback onTap;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return BounceTap(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: scheme.onPrimary, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}