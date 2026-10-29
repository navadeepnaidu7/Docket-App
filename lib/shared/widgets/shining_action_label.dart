import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The quiet moving highlight used below Docket's wallet cards.
class ShiningActionLabel extends StatefulWidget {
  const ShiningActionLabel({
    super.key,
    required this.label,
    this.enabled = true,
    this.fontSize = 12,
    this.arrowSize = 10,
    this.baseOpacity,
    this.color,
    this.showArrow = true,
    this.glow = false,
    this.fontWeight = FontWeight.w600,
    this.letterSpacing = 0.2,
    this.height,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
  });

  final String label;
  final bool enabled;
  final double fontSize;
  final double arrowSize;
  final double? baseOpacity;
  final Color? color;
  final bool showArrow;
  final bool glow;
  final FontWeight fontWeight;
  final double letterSpacing;
  final double? height;
  final int maxLines;
  final TextAlign textAlign;

  @override
  State<ShiningActionLabel> createState() => _ShiningActionLabelState();
}

class _ShiningActionLabelState extends State<ShiningActionLabel>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  );
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _syncShine();
  }

  @override
  void didUpdateWidget(ShiningActionLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _syncShine();
  }

  void _syncShine() {
    if (widget.enabled && !_reducedMotion) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _label(Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(
          widget.label,
          maxLines: widget.maxLines,
          textAlign: widget.textAlign,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.ui(
            fontSize: widget.fontSize,
            fontWeight: widget.fontWeight,
            letterSpacing: widget.letterSpacing,
            height: widget.height,
            color: color,
          ),
        ),
      ),
      if (widget.showArrow) ...[
        const SizedBox(width: 4),
        Icon(
          Icons.arrow_forward_ios_rounded,
          size: widget.arrowSize,
          color: color,
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink = widget.color ?? theme.colorScheme.onSurface;
    final base = ink.withValues(
      alpha: widget.baseOpacity ?? (isDark ? 0.40 : 0.48),
    );
    if (_reducedMotion) return _label(base);

    final mid = widget.glow
        ? ink.withValues(alpha: 0.84)
        : isDark
        ? Colors.white.withValues(alpha: 0.72)
        : ink.withValues(alpha: 0.72);
    final peak = widget.glow
        ? ink
        : isDark
        ? Colors.white.withValues(alpha: 0.92)
        : ink.withValues(alpha: 0.90);

    return AnimatedBuilder(
      animation: _controller,
      child: _label(Colors.white),
      builder: (context, child) {
        final t = Curves.easeInOutCubic.transform(_controller.value);
        final glowTravel = const Interval(
          0.08,
          0.85,
          curve: Curves.easeInOutSine,
        ).transform(_controller.value);
        Widget sweep() => ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            // A broad band glints across several letters at a time.
            final x = widget.glow ? 2 * glowTravel - 1 : 1.55 * t - 0.55;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, base, mid, peak, mid, base, base],
              stops: const [0, 0.28, 0.42, 0.50, 0.58, 0.72, 1],
              transform: _ShimmerSlide(x),
            ).createShader(bounds);
          },
          child: child,
        );
        if (!widget.glow) return sweep();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              ExcludeSemantics(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.28,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: sweep(),
                    ),
                  ),
                ),
              ),
              sweep(),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerSlide extends GradientTransform {
  const _ShimmerSlide(this.dxInWidths);

  final double dxInWidths;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * dxInWidths, 0, 0);
}
