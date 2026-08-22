import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'pass_typography.dart';

/// A titled group of label/value rows on a pass detail screen.
///
/// Shared by the movie and bus detail screens. It was private to the movie
/// screen and the bus screen was about to grow its own copy, which is how the
/// two would have drifted a row-height at a time.
///
/// Rows whose value is blank are dropped rather than rendered against a dash:
/// a detail screen is a reference, and an empty row is noise on a card that is
/// already a list of facts.
class PassInfoCard extends StatelessWidget {
  const PassInfoCard({
    super.key,
    required this.title,
    required this.ink,
    required this.muted,
    required this.isDark,
    required this.rows,
    this.labelWidth = 110,
  });

  final String title;
  final Color ink;
  final Color muted;
  final bool isDark;
  final List<(String, String)> rows;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final Color surface =
        isDark ? AppTheme.elevated(Brightness.dark) : Colors.white;
    final Color border = ink.withValues(alpha: isDark ? 0.08 : 0.06);

    final List<(String, String)> shown = rows
        .where(((String, String) r) => r.$2.trim().isNotEmpty)
        .toList(growable: false);
    if (shown.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: PassType.sectionTitle(ink)),
          const SizedBox(height: 6),
          ...shown.map(
            ((String, String) r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: labelWidth,
                    child: Text(r.$1, style: PassType.label(muted)),
                  ),
                  Expanded(
                    child: Text(r.$2, style: PassType.value(ink)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
