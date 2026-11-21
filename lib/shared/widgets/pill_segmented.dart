import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// iOS-style sliding segmented control with press scale + thumb motion.
///
/// The Settings theme picker and the train pass Details | Live status switch
/// share it, so the two controls move and read the same.
class PillSegmented<T> extends StatefulWidget {
  const PillSegmented({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> segments;
  final ValueChanged<T> onChanged;

  @override
  State<PillSegmented<T>> createState() => _PillSegmentedState<T>();
}

class _PillSegmentedState<T> extends State<PillSegmented<T>> {
  static const double _height = 40;
  static const double _pad = 3;
  static const Duration _slideDuration = Duration(milliseconds: 280);
  static const Curve _slideCurve = Curves.easeOutCubic;

  int? _pressedIndex;

  int get _selectedIndex {
    final int i = widget.segments.indexWhere((e) => e.$1 == widget.value);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = Theme.of(context).colorScheme.onSurface;

    // Dark: deeper track + brighter elevated thumb for clear contrast.
    final Color track = isDark
        ? const Color(0xFF0C0C10)
        : ink.withValues(alpha: 0.07);
    final Color trackBorder = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.04);
    final Color thumbBg = isDark
        ? const Color(0xFF3A3A44)
        : const Color(0xFFFFFFFF);
    final Color thumbBorder = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.04);
    final Color selectedFg = isDark
        ? const Color(0xFFF5F5F7)
        : const Color(0xFF1C1C1E);
    final Color unselectedFg = isDark
        ? Colors.white.withValues(alpha: 0.58)
        : ink.withValues(alpha: 0.48);

    final int count = widget.segments.length;
    final int selected = _selectedIndex;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double innerW = constraints.maxWidth - _pad * 2;
        final double segmentW = innerW / count;
        final double thumbLeft = _pad + selected * segmentW;

        return Container(
          height: _height,
          decoration: BoxDecoration(
            color: track,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: trackBorder, width: 0.5),
          ),
          child: Stack(
            children: <Widget>[
              // Sliding thumb
              AnimatedPositioned(
                duration: _slideDuration,
                curve: _slideCurve,
                left: thumbLeft,
                width: segmentW,
                top: _pad,
                bottom: _pad,
                child: AnimatedScale(
                  scale: _pressedIndex == selected ? 0.96 : 1.0,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOutCubic,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: thumbBg,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: thumbBorder, width: 0.5),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.45 : 0.08,
                          ),
                          blurRadius: isDark ? 10 : 8,
                          offset: const Offset(0, 2),
                        ),
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // Labels + hit targets
              Row(
                children: <Widget>[
                  for (int i = 0; i < count; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => setState(() => _pressedIndex = i),
                        onTapUp: (_) => setState(() => _pressedIndex = null),
                        onTapCancel: () => setState(() => _pressedIndex = null),
                        onTap: () {
                          final T key = widget.segments[i].$1;
                          if (key != widget.value) {
                            widget.onChanged(key);
                          }
                        },
                        child: AnimatedScale(
                          scale: _pressedIndex == i ? 0.94 : 1.0,
                          duration: const Duration(milliseconds: 110),
                          curve: Curves.easeOutCubic,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: _slideDuration,
                              curve: _slideCurve,
                              style: AppFonts.ui(
                                // Slightly tighter type when 4 segments (theme row).
                                fontSize: count >= 4 ? 11.5 : 13,
                                fontWeight: i == selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                letterSpacing: count >= 4 ? -0.25 : -0.2,
                                color: i == selected
                                    ? selectedFg
                                    : unselectedFg,
                                height: 1.1,
                              ),
                              child: Text(
                                widget.segments[i].$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
