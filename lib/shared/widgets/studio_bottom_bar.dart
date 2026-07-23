import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'bounce_tap.dart';

/// Pinned bottom bar with a full-width primary action.
class StudioBottomBar extends StatelessWidget {
  const StudioBottomBar({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final Color bg = isDark ? scheme.primary : scheme.onSurface;
    final Color fg = isDark ? scheme.onPrimary : scheme.surface;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: AppTokens.separator(scheme), width: 0.5),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: BounceTap(
            onTap: enabled ? onTap : null,
            scaleFactor: 0.975,
            child: Container(
              height: 56,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: enabled
                    ? <BoxShadow>[
                        BoxShadow(
                          color: bg.withValues(alpha: 0.24),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, color: fg, size: 20),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
