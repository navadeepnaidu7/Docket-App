import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Docket's fixed blue and violet light, shared by every horizon.
/// Card schemes and wallet contents never alter this surface.
class MembershipHorizon extends StatefulWidget {
  const MembershipHorizon({super.key});

  static const palette = <Color>[
    Color(0xFF648BFF),
    Color(0xFF796DDD),
    Color(0xFFABA8FF),
  ];

  @override
  State<MembershipHorizon> createState() => _MembershipHorizonState();
}

class _MembershipHorizonState extends State<MembershipHorizon>
    with TickerProviderStateMixin {
  late final _light = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );
  late final _bloom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
  );
  bool _entered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _light.stop();
      _light.value = 0;
      _bloom.value = 1;
      _entered = true;
    } else {
      if (!_entered) {
        _entered = true;
        _bloom.forward();
      }
      if (!_light.isAnimating) _light.repeat();
    }
  }

  @override
  void dispose() {
    _light.dispose();
    _bloom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_light, _bloom]),
            builder: (context, _) => CustomPaint(
              painter: _HorizonLight(
                background: background,
                dark: dark,
                phase: _light.value * 2 * math.pi,
                bloom: Curves.easeOutCubic.transform(_bloom.value),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _HorizonLight extends CustomPainter {
  const _HorizonLight({
    required this.background,
    required this.dark,
    required this.phase,
    required this.bloom,
  });

  static const colors = MembershipHorizon.palette;
  final Color background;
  final bool dark;
  final double phase;
  final double bloom;

  @override
  void paint(Canvas canvas, Size size) {
    if (bloom == 0) return;
    final radius = size.width * 0.76;
    final center = Offset(size.width / 2, size.height * 0.23 + radius);
    final circle = Rect.fromCircle(center: center, radius: radius);
    Color tint(int i, double strength) {
      final source = HSLColor.fromColor(colors[i % colors.length]);
      final color = dark
          ? source.toColor()
          : source.withSaturation(source.saturation * 0.6).toColor();
      return Color.lerp(background, color, strength * bloom)!;
    }

    final strength = dark ? 0.48 : 0.24;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // The light expands from below the screen, without moving any content.
    final scale = 0.78 + 0.22 * bloom;
    canvas.translate(
      size.width / 2,
      size.height + size.height * 0.2 * (1 - bloom),
    );
    canvas.scale(scale);
    canvas.translate(-size.width / 2, -size.height);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32)
        ..shader = RadialGradient(
          center: Alignment(math.sin(phase) * 0.06, -0.92),
          radius: 0.78,
          colors: [
            tint(0, strength),
            tint(1, strength * 0.55),
            tint(1, strength * 0.06),
          ],
          stops: const [0, 0.50, 1],
        ).createShader(circle),
    );
    // A broad inner reflection changes gently without moving the silhouette.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32)
        ..shader = RadialGradient(
          center: Alignment(0.12 + math.sin(phase) * 0.06, -0.88),
          radius: 0.48,
          colors: [
            colors.last.withValues(alpha: (dark ? 0.09 : 0.04) * bloom),
            colors.last.withValues(alpha: 0),
          ],
        ).createShader(circle),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HorizonLight old) =>
      phase != old.phase ||
      bloom != old.bloom ||
      background != old.background ||
      dark != old.dark;
}
