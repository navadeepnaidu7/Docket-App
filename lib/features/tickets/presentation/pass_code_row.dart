import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/pass_code.dart';
import 'pass_typography.dart';

/// Shared scan affordance. Only construct for a genuine code.
class PassCodeRow extends StatelessWidget {
  const PassCodeRow({super.key, required this.code, required this.onTap})
    : embedded = false,
      accent = null;

  /// Keeps the movie ticket's white ink and tinted thumbnail shadow.
  const PassCodeRow.embedded({
    super.key,
    required this.code,
    required this.onTap,
    this.accent,
  }) : embedded = true;

  final PassCode code;
  final VoidCallback? onTap;
  final bool embedded;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink = embedded ? Colors.white : theme.colorScheme.onSurface;
    final Color muted = embedded
        ? Colors.white.withValues(alpha: 0.55)
        : AppTokens.secondaryLabel(theme.colorScheme);
    final BorderRadius radius = BorderRadius.circular(16);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: embedded
              ? null
              : BoxDecoration(
                  color: isDark
                      ? AppTheme.elevated(Brightness.dark)
                      : Colors.white,
                  borderRadius: radius,
                  border: Border.all(
                    color: ink.withValues(alpha: isDark ? 0.08 : 0.06),
                  ),
                ),
          child: Padding(
            padding: embedded
                ? const EdgeInsets.symmetric(vertical: 4)
                : const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 88,
                  height: 88,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                    boxShadow: accent == null
                        ? null
                        : <BoxShadow>[
                            BoxShadow(
                              color: accent!.withValues(alpha: 0.30),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  // A static glyph, not the payload: rendering a dense code at
                  // thumbnail size is costly and unreadable. Full screen shows it.
                  child: Center(
                    child: Icon(
                      code.format == PassCodeFormat.qr
                          ? Icons.qr_code_2_rounded
                          : Icons.view_week_rounded,
                      size: 64,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        code.format == PassCodeFormat.qr
                            ? 'QR code'
                            : 'Barcode',
                        style: PassType.sectionTitle(ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to open full screen for scanning',
                        style: PassType.caption(muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: muted, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
