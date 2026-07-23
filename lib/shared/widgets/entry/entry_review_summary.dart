import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../bounce_tap.dart';
import '../studio_section.dart';

/// Read-only summary used on the review step before save.
class EntryReviewSummary extends StatelessWidget {
  const EntryReviewSummary({
    super.key,
    required this.title,
    required this.rows,
    this.onEdit,
    this.leading,
  });

  final String title;
  final List<(String, String)> rows;
  final VoidCallback? onEdit;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color muted = AppTokens.secondaryLabel(scheme);

    return StudioSection(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  leading!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.25,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (onEdit != null)
                  BounceTap(
                    onTap: onEdit,
                    scaleFactor: 0.95,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Edit',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ...rows.where((r) => r.$2.trim().isNotEmpty).map(
              ((String, String) r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 108,
                      child: Text(
                        r.$1,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        r.$2,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EntrySectionLabel extends StatelessWidget {
  const EntrySectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppTokens.secondaryLabel(Theme.of(context).colorScheme),
        ),
      ),
    );
  }
}
