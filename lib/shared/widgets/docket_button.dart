import 'package:flutter/material.dart';

import '../../core/haptics/haptic_service.dart';
import '../../core/theme/app_theme.dart';

enum DocketButtonTone {
  /// Solid ink pill: black on light, white on dark. One per screen.
  primary,

  /// Quiet filled pill for a second action next to a primary.
  secondary,
}

/// The app's pill button.
///
/// Presses are shown as a short spring-back scale plus a light haptic rather
/// than an ink ripple, which reads as stock Android chrome.
class DocketButton extends StatefulWidget {
  const DocketButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = DocketButtonTone.primary,
    this.expand = true,
    this.compact = false,
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final DocketButtonTone tone;

  /// Fill the available width. The reference layout pins one full-width
  /// primary to the bottom of the content.
  final bool expand;

  /// Smaller pill for inline actions that should not dominate the screen.
  final bool compact;
  final Widget? leading;

  @override
  State<DocketButton> createState() => _DocketButtonState();
}

class _DocketButtonState extends State<DocketButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _scale = Tween<double>(begin: 1, end: 0.965)
      .animate(
        CurvedAnimation(
          parent: _press,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeOutBack,
        ),
      );

  bool get _enabled => widget.onPressed != null;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink = AppTheme.ink(theme.brightness);
    final bool primary = widget.tone == DocketButtonTone.primary;

    final Color fill = !_enabled
        ? ink.withValues(alpha: 0.10)
        : primary
        ? ink
        : ink.withValues(alpha: isDark ? 0.12 : 0.07);
    final Color fg = !_enabled
        ? ink.withValues(alpha: 0.36)
        : primary
        ? AppTheme.background(theme.brightness)
        : ink;

    final Widget label = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppFonts.ui(
        fontSize: widget.compact ? 15 : 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: fg,
      ),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _press.forward() : null,
        onTapUp: _enabled ? (_) => _press.reverse() : null,
        onTapCancel: _enabled ? _press.reverse : null,
        onTap: _enabled
            ? () {
                HapticService.tap();
                widget.onPressed!();
              }
            : null,
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: widget.compact ? 44 : AppTheme.controlHeight,
            width: widget.expand ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: widget.compact ? 20 : 28),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Row(
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.leading != null) ...[
                  IconTheme.merge(
                    data: IconThemeData(color: fg, size: 18),
                    child: widget.leading!,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(child: label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
