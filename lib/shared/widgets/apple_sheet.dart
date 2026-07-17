import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class AppleSheet extends StatelessWidget {
  const AppleSheet({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.showDragHandle = true,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color bgColor = AppTokens.sheetBackground(scheme);
    final Color handleColor = AppTokens.sheetHandle(scheme);
    final Color titleColor = scheme.onSurface;
    final Color subtitleColor = AppTokens.secondaryLabel(scheme);
    final Color borderColor = isDark
        ? scheme.onSurface.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.40);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSheet),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusSheet),
              border: Border.all(
                color: borderColor,
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                  blurRadius: 32,
                  spreadRadius: -4,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                if (showDragHandle)
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: handleColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                if (title != null) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      title!,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: subtitleColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
