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
    this.stacked = false,
    this.valueColor,
  });

  final String title;
  final Color ink;
  final Color muted;
  final bool isDark;
  final List<(String, String)> rows;

  /// Each row's label as the primary line with its value beneath, for rows
  /// that name a person rather than a field. A name in the 120dp label column
  /// wrapped, and widening the column on one card broke the shared value edge.
  final bool stacked;

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
            child: stacked ? _stackedRow(r) : _row(r),
          ),
        ),
      ],
    );
  }

  Color _valueInk((String, String) r) => valueColor?.call(r.$1, r.$2) ?? ink;

  Widget _row((String, String) r) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      SizedBox(width: 120, child: Text(r.$1, style: PassType.label(muted))),
      Expanded(child: Text(r.$2, style: PassType.value(_valueInk(r)))),
    ],
  );

  Widget _stackedRow((String, String) r) {
    final Color value = _valueInk(r);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(r.$1, style: PassType.value(ink)),
        const SizedBox(height: 3),
        // Muted unless the row carries a status colour.
        Text(r.$2, style: PassType.label(value == ink ? muted : value)),
      ],
    );
  }
}
