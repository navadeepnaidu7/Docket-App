import 'package:flutter/material.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/prompt_typography.dart';
import '../prompt_step.dart';

/// One line on the review screen.
class PromptReviewRow {
  const PromptReviewRow({
    required this.stepId,
    required this.label,
    required this.value,
    required this.source,
    this.missing = false,
  });

  final String stepId;
  final String label;
  final String value;
  final FieldSource source;

  /// An optional field that was skipped — offered as "Add" rather than hidden,
  /// so the user can see what they chose not to fill in.
  final bool missing;
}

/// The final summary. Every row is tappable and edits in place.
///
/// Row padding matches [Space.gutter] so labels line up with the questions the
/// user just answered. The screens this replaces used `fromLTRB(10,12,10,4)` on
/// the form steps and `fromLTRB(16,16,16,10)` on review, so nothing aligned
/// between one step and the next.
class PromptReviewCard extends StatelessWidget {
  const PromptReviewCard({
    super.key,
    required this.rows,
    required this.onEdit,
    this.chipVerified = false,
    this.portrait,
  });

  final List<PromptReviewRow> rows;
  final void Function(String stepId) onEdit;

  /// Shown once at the top when values were confirmed against the chip.
  final bool chipVerified;

  /// Optional portrait read from the chip.
  final Widget? portrait;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (chipVerified) ...<Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.verified_rounded,
                size: 16,
                color: AppTokens.success(scheme),
              ),
              const SizedBox(width: Space.x2),
              Text(
                'Verified against the chip',
                style: theme.textTheme.promptHelper(scheme).copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.success(scheme),
                    ),
              ),
            ],
          ),
          const SizedBox(height: Space.x4),
        ],
        if (portrait != null) ...<Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            child: SizedBox(width: 56, height: 72, child: portrait),
          ),
          const SizedBox(height: Space.x4),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppTokens.groupedFieldFill(
              scheme,
              isDark: theme.brightness == Brightness.dark,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: AppTokens.separator(scheme)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < rows.length; i++) ...<Widget>[
                if (i > 0)
                  Divider(
                    height: 0.5,
                    thickness: 0.5,
                    indent: Space.x4,
                    color: AppTokens.separator(scheme),
                  ),
                _Row(
                  row: rows[i],
                  onTap: () {
                    HapticService.select();
                    onEdit(rows[i].stepId);
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.onTap});

  final PromptReviewRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x4,
            vertical: Space.x3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 108,
                child: Text(
                  row.label,
                  style: theme.textTheme.promptReviewLabel(scheme),
                ),
              ),
              Expanded(
                child: row.missing
                    ? Text(
                        'Add',
                        style: theme.textTheme.promptReviewValue.copyWith(
                          color: scheme.primary,
                        ),
                      )
                    : Text(
                        row.value,
                        style: theme.textTheme.promptReviewValue,
                      ),
              ),
              if (!row.missing) _Provenance(source: row.source),
              const SizedBox(width: Space.x2),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppTokens.tertiaryLabel(scheme),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where a value came from. Typed values show nothing — the common case
/// should be the quiet one.
class _Provenance extends StatelessWidget {
  const _Provenance({required this.source});

  final FieldSource source;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return switch (source) {
      FieldSource.chip =>
        Icon(Icons.nfc_rounded, size: 13, color: scheme.primary),
      FieldSource.scanned => Text(
          'SCANNED',
          style: theme.textTheme.promptStepCount(scheme).copyWith(fontSize: 10),
        ),
      FieldSource.typed => const SizedBox.shrink(),
    };
  }
}
