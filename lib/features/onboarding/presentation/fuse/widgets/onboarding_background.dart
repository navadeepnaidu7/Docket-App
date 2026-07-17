import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../../core/motion/smooth_curves.dart';

enum BackgroundMode { welcome, morphing, feature, plain }

class OnboardingBackground extends StatefulWidget {
  const OnboardingBackground({
    super.key,
    required this.mode,
    this.accent = const Color(0xFF007AFF),
    this.visible = true,
  });

  final BackgroundMode mode;
  final Color accent;
  final bool visible;

  @override
  State<OnboardingBackground> createState() => _OnboardingBackgroundState();
}

class _OnboardingBackgroundState extends State<OnboardingBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _morphController;

  @override
  void initState() {
    super.initState();
    _morphController = AnimationController(vsync: this, duration: smoothDuration);
    _syncMorph(immediate: true);
  }

  @override
  void didUpdateWidget(OnboardingBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMorph();
  }

  void _syncMorph({bool immediate = false}) {
    final double target = switch (widget.mode) {
      BackgroundMode.welcome => 0.0,
      BackgroundMode.morphing || BackgroundMode.feature || BackgroundMode.plain => 1.0,
    };

    if (immediate) {
      _morphController.value = target;
    } else {
      // Use Curves.linear so the staggered easing curves inside the painter operate correctly without compounding curves
      _morphController.animateTo(target, duration: smoothDuration, curve: Curves.linear);
    }
  }

  @override
  void dispose() {
    _morphController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: widget.accent, end: widget.accent),
      duration: const Duration(milliseconds: 350),
      builder: (BuildContext context, Color? animatedAccent, Widget? child) {
        return AnimatedOpacity(
          opacity: widget.visible ? 1.0 : 0.0,
          duration: smoothDuration,
          curve: smoothCurve,
          child: AnimatedBuilder(
            animation: _morphController,
            builder: (BuildContext context, Widget? child) {
              final bool isDark =
                  Theme.of(context).brightness == Brightness.dark;
              final Color base = Theme.of(context).scaffoldBackgroundColor;
              return CustomPaint(
                painter: _OnboardingBackgroundPainter(
                  morph: _morphController.value,
                  accent: animatedAccent ?? widget.accent,
                  baseColor: base,
                  isDark: isDark,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        );
      },
    );
  }
}

class _OnboardingBackgroundPainter extends CustomPainter {
  _OnboardingBackgroundPainter({
    required this.morph,
    required this.accent,
    required this.baseColor,
    required this.isDark,
  });

  final double morph;
  final Color accent;
  final Color baseColor;
  final bool isDark;

  static const Color _cyan = Color(0xFF00D4FF);
  static const Color _blue = Color(0xFF007AFF);
  static const Color _sky = Color(0xFF4DA3FF);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = baseColor);

    // Staggered easing curves using Interval for overlapping delays
    final double t1 = Curves.easeInOutCubic.transform(morph);
    final double t2 = const Interval(0.12, 0.88, curve: Curves.easeInOutCubic).transform(morph);
    final double t3 = const Interval(0.24, 1.0, curve: Curves.easeInOutCubic).transform(morph);

    final Rect rect = Offset.zero & size;
    final double bloom = isDark ? 0.55 : 1.0;
    final Color transparentEdge = baseColor.withValues(alpha: 0);

    // Tint background colors slightly towards current active accent color
    final Color colorCyan = Color.lerp(_cyan, accent, 0.12)!;
    final Color colorBlue = Color.lerp(_blue, accent, 0.35)!;
    final Color colorSky = Color.lerp(_sky, accent, 0.22)!;

    // Layer 1: Primary Cyan/Blue bloom (starts bottom-right, flows to top-left)
    final Alignment c1 = Alignment(
      lerpDouble(0.45, -0.35, t1)!,
      lerpDouble(1.25, -1.0, t1)!,
    );
    final double r1 = lerpDouble(0.98, 0.95, t1)!;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: c1,
          radius: r1,
          colors: <Color>[
            colorCyan.withValues(alpha: 0.90 * bloom),
            colorBlue.withValues(alpha: 0.55 * bloom),
            transparentEdge,
          ],
          stops: const <double>[0, 0.55, 1],
        ).createShader(rect),
    );

    // Layer 2: Soft Blue glow (starts bottom-left, flows to top-right)
    final Alignment c2 = Alignment(
      lerpDouble(-0.35, 0.3, t2)!,
      lerpDouble(1.35, -0.9, t2)!,
    );
    final double r2 = lerpDouble(1.06, 1.05, t2)!;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: c2,
          radius: r2,
          colors: <Color>[
            colorBlue.withValues(alpha: 0.80 * bloom),
            colorSky.withValues(alpha: 0.45 * bloom),
            transparentEdge,
          ],
          stops: const <double>[0, 0.62, 1],
        ).createShader(rect),
    );

    // Layer 3: Secondary Sky-blue fill (starts bottom-center, rises to top-center)
    final Alignment c3 = Alignment(
      lerpDouble(0.0, -0.1, t3)!,
      lerpDouble(1.12, -1.1, t3)!,
    );
    final double r3 = lerpDouble(0.83, 0.9, t3)!;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: c3,
          radius: r3,
          colors: <Color>[
            colorSky.withValues(alpha: 0.75 * bloom),
            colorBlue.withValues(alpha: 0.32 * bloom),
            transparentEdge,
          ],
          stops: const <double>[0, 0.45, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _OnboardingBackgroundPainter old) {
    return old.morph != morph ||
        old.accent != accent ||
        old.baseColor != baseColor ||
        old.isDark != isDark;
  }
}