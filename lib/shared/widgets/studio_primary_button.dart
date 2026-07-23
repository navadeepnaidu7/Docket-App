import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'bounce_tap.dart';

class StudioPrimaryButton extends StatelessWidget {
  const StudioPrimaryButton({
    super.key,
    required this.onTap,
    this.label = 'Save',
    this.icon = Icons.save_rounded,
    this.enabled = true,
    this.expanded = true,
  });

  final VoidCallback onTap;
  final String label;
  final IconData? icon;
  final bool enabled;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color bg = isDark ? scheme.primary : scheme.onSurface;
    final Color fg = isDark ? scheme.onPrimary : scheme.surface;

    final Widget content = Opacity(
      opacity: enabled ? 1 : 0.45,
      child: BounceTap(
        onTap: enabled ? onTap : null,
        scaleFactor: 0.975,
        child: Container(
          height: 54,
          width: expanded ? double.infinity : null,
          padding: expanded
              ? null
              : const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: bg.withValues(alpha: 0.26),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, color: fg, size: 20),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  color: fg,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return content;
  }
}

/// Secondary outlined action used under hero CTAs.
class StudioSecondaryButton extends StatelessWidget {
  const StudioSecondaryButton({
    super.key,
    required this.onTap,
    required this.label,
    this.icon,
  });

  final VoidCallback onTap;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return BounceTap(
      onTap: onTap,
      scaleFactor: 0.975,
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.onSurface.withValues(alpha: isDark ? 0.12 : 0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, color: scheme.onSurface, size: 20),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                color: scheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
