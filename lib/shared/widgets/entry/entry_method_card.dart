import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../bounce_tap.dart';

/// Scan-first method chooser tile.
class EntryMethodCard extends StatelessWidget {
  const EntryMethodCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.hero = false,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool hero;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    if (hero) {
      return BounceTap(
        onTap: onTap,
        scaleFactor: 0.98,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? <Color>[
                      scheme.primary,
                      scheme.primary.withValues(alpha: 0.78),
                    ]
                  : <Color>[
                      scheme.onSurface,
                      const Color(0xFF1A2740),
                    ],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: (isDark ? scheme.primary : scheme.onSurface)
                    .withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.85),
                size: 22,
              ),
            ],
          ),
        ),
      );
    }

    final Color surface = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.82);
    final Color border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : scheme.onSurface.withValues(alpha: 0.06);

    return BounceTap(
      onTap: onTap,
      scaleFactor: 0.98,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: scheme.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: AppTokens.secondaryLabel(scheme),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTokens.tertiaryLabel(scheme),
                  size: 22,
                ),
          ],
        ),
      ),
    );
  }
}

class EntryTextAction extends StatelessWidget {
  const EntryTextAction({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: BounceTap(
        onTap: onTap,
        scaleFactor: 0.97,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: scheme.primary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.15,
            ),
          ),
        ),
      ),
    );
  }
}
