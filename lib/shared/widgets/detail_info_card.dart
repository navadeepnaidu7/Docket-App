import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'detail_typography.dart';

/// The information group used below pass, document and payment-card faces.
class DetailInfoCard extends StatelessWidget {
  const DetailInfoCard({
    super.key,
    required this.title,
    required this.children,
    this.ink,
    this.isDark,
  });

  final String title;
  final List<Widget> children;
  final Color? ink;
  final bool? isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = this.ink ?? theme.colorScheme.onSurface;
    final isDark = this.isDark ?? theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.elevated(Brightness.dark) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ink.withValues(alpha: isDark ? 0.08 : 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: DetailType.sectionTitle(ink)),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

/// A label/value pair with optional copy, reveal or navigation controls.
/// Controls retain their normal touch targets; long values can wrap freely.
class DetailInfoRow extends StatelessWidget {
  const DetailInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueWidget,
    this.trailing,
    this.onTap,
    this.missing = false,
    this.tabular = false,
  });

  final String label;
  final String value;
  final Widget? valueWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool missing;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = AppTokens.secondaryLabel(scheme);
    final labelText = Text(label, style: DetailType.label(muted));
    final valueText =
        valueWidget ??
        Text(
          value,
          style: DetailType.value(
            missing ? muted : scheme.onSurface,
          ).copyWith(fontFeatures: tabular ? AppFonts.tabular : null),
        );

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A pair of 48dp controls must not squeeze the value into a sliver.
          final stacked =
              constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(14) > 18;
          final text = stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [labelText, const SizedBox(height: 5), valueText],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 120, child: labelText),
                    Expanded(child: valueText),
                  ],
                );
          return Row(
            children: [
              Expanded(child: text),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          );
        },
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
