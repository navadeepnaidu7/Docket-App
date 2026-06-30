import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'bounce_tap.dart';

class StudioScanButton extends StatelessWidget {
  const StudioScanButton({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle = 'Auto-fill from camera',
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final ColorScheme scheme = theme.colorScheme;

    final Gradient gradient = isDark
        ? LinearGradient(
            colors: <Color>[
              scheme.primary.withValues(alpha: 0.9),
              scheme.primary.withValues(alpha: 0.7),
            ],
          )
        : LinearGradient(
            colors: <Color>[
              scheme.onSurface,
              scheme.onSurface.withValues(alpha: 0.85),
            ],
          );

    return Padding(
      padding: const EdgeInsets.all(AppTokens.sectionPadding),
      child: BounceTap(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: scheme.primary.withValues(alpha: isDark ? 0.20 : 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.camera_alt_rounded, color: scheme.onPrimary, size: 22),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimary.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}