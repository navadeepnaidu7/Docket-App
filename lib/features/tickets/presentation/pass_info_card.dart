import 'package:flutter/material.dart';

import '../../../shared/widgets/detail_info_card.dart';
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
    this.labelWidth = 120,
    this.valueColor,
  });

  final String title;
  final Color ink;
  final Color muted;
  final bool isDark;
  final List<(String, String)> rows;
  final double labelWidth;

  /// Colour for one row's value, or null for [ink]. Keyed by the row itself
  /// because blank rows are dropped, so an index would drift.
  final Color? Function(String label, String value)? valueColor;

  @override
  Widget build(BuildContext context) {
    final List<(String, String)> shown = rows
        .where(((String, String) r) => r.$2.trim().isNotEmpty)
        .toList(growable: false);
    if (shown.isEmpty) return const SizedBox.shrink();

    return DetailInfoCard(
      title: title,
      ink: ink,
      isDark: isDark,
      children: <Widget>[
        ...shown.map(
          ((String, String) r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: labelWidth,
                  child: Text(r.$1, style: PassType.label(muted)),
                ),
                Expanded(
                  child: Text(
                    r.$2,
                    style: PassType.value(valueColor?.call(r.$1, r.$2) ?? ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
