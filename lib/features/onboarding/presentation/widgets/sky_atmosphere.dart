import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../onboarding_palette.dart';

/// The icon's sky as a living backdrop: the tile gradient with slow light
/// blooms drifting across it and the soft glow along the bottom breathing.
///
/// Motion is on a long loop and small, so it reads as air, not animation.
/// With reduced motion the blooms hold still.
class SkyAtmosphere extends StatefulWidget {
  const SkyAtmosphere({super.key, this.depth = 0});

  /// 0 is the icon's daylight sky; 1 deepens it toward dusk blue, used in
  /// dark mode so the stage does not glare.
  final double depth;

  @override
  State<SkyAtmosphere> createState() => _SkyAtmosphereState();
}

class _SkyAtmosphereState extends State<SkyAtmosphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: SkyPainter(time: _loop, depth: widget.depth),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class SkyPainter extends CustomPainter {
  SkyPainter({required this.time, this.depth = 0}) : super(repaint: time);

  final Animation<double> time;
  final double depth;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = Offset.zero & size;
    final double t = time.value * 2 * math.pi;

    final Color top = Color.lerp(
      OnboardingPalette.skyTop,
      OnboardingPalette.skyDeep,
      depth,
    )!;
    final Color mid = Color.lerp(
      OnboardingPalette.sky,
      OnboardingPalette.skyShade,
      depth * 0.8,
    )!;
    final Color low = Color.lerp(
      OnboardingPalette.skyHorizon,
      OnboardingPalette.skyTop,
      depth * 0.7,
    )!;
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[top, top, mid, low],
          stops: const <double>[0, 0.12, 0.56, 1],
        ).createShader(r),
    );

    void bloom(Offset c, double radius, Color color) {
      final Rect b = Rect.fromCircle(center: c, radius: radius);
      canvas.drawRect(
        r,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ).createShader(b),
      );
    }

    final double w = size.width;
    final double h = size.height;
    // Upper-left daylight, drifting on a slow ellipse.
    bloom(
      Offset(w * (0.22 + 0.05 * math.sin(t)), h * (0.14 + 0.03 * math.cos(t))),
      w * 0.9,
      Colors.white.withValues(alpha: 0.22 * (1 - depth * 0.5)),
    );
    // Cool cyan pocket on the right.
    bloom(
      Offset(
        w * (0.92 + 0.06 * math.cos(t + 1.3)),
        h * (0.48 + 0.04 * math.sin(t + 0.6)),
      ),
      w * 0.75,
      const Color(0xFF8CDCFF).withValues(alpha: 0.26),
    );
    // Faint violet low on the left keeps the blue from going flat.
    bloom(
      Offset(w * (0.04 + 0.04 * math.sin(t * 2 + 2)), h * 0.80),
      w * 0.7,
      const Color(0xFF7C8CFF).withValues(alpha: 0.14 + 0.06 * depth),
    );
    // The soft white glow along the bottom edge, breathing.
    final double breath = 0.5 + 0.5 * math.sin(t * 2);
    final Rect glow = Rect.fromCenter(
      center: Offset(w * 0.5, h * 1.02),
      width: w * 1.5,
      height: h * 0.55,
    );
    canvas.save();
    canvas.translate(glow.center.dx, glow.center.dy);
    canvas.scale(1, glow.height / glow.width);
    canvas.translate(-glow.center.dx, -glow.center.dy);
    bloom(
      glow.center,
      glow.width / 2,
      Colors.white.withValues(alpha: (0.30 + 0.08 * breath) * (1 - depth * 0.55)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(SkyPainter old) => old.depth != depth;
}
