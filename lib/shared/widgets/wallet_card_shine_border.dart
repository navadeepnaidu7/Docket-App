import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Experimental Apple-style iridescent border after the card rests post-swipe.
class WalletCardShineBorder extends StatefulWidget {
  const WalletCardShineBorder({
    super.key,
    required this.child,
    required this.enabled,
    required this.isActive,
    this.borderRadius = 24,
    this.idleDelay = const Duration(milliseconds: 3500),
  });

  final Widget child;
  final bool enabled;
  final bool isActive;
  final double borderRadius;
  final Duration idleDelay;

  @override
  State<WalletCardShineBorder> createState() => _WalletCardShineBorderState();
}

class _WalletCardShineBorderState extends State<WalletCardShineBorder>
    with TickerProviderStateMixin {
  Timer? _idleTimer;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  Ticker? _sweepTicker;
  Duration _sweepElapsed = Duration.zero;
  static const Duration _sweepPeriod = Duration(milliseconds: 4800);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOutCubic);
    _scheduleIfNeeded();
  }

  @override
  void didUpdateWidget(WalletCardShineBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.isActive != widget.isActive) {
      _scheduleIfNeeded();
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _stopSweep();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _startSweep() {
    if (_sweepTicker != null) return;
    _sweepTicker = createTicker((Duration elapsed) {
      _sweepElapsed = elapsed;
      if (mounted && _fadeAnim.value > 0.001) {
        setState(() {});
      }
    })..start();
  }

  void _stopSweep() {
    _sweepTicker?.dispose();
    _sweepTicker = null;
    _sweepElapsed = Duration.zero;
  }

  double get _sweepProgress {
    final double ms = _sweepElapsed.inMicroseconds / 1000.0;
    final double periodMs = _sweepPeriod.inMilliseconds.toDouble();
    return (ms % periodMs) / periodMs;
  }

  void _scheduleIfNeeded() {
    _idleTimer?.cancel();
    _fadeCtrl.reverse();
    _stopSweep();

    if (!widget.enabled || !widget.isActive) return;

    // Spin up the sweep early so motion is already smooth when the border fades in.
    _startSweep();

    _idleTimer = Timer(widget.idleDelay, () {
      if (!mounted || !widget.enabled || !widget.isActive) return;
      _fadeCtrl.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnim,
      builder: (context, child) {
        final double opacity = _fadeAnim.value;
        if (opacity <= 0.001) return child!;

        return CustomPaint(
          foregroundPainter: _AppleShineBorderPainter(
            progress: _sweepProgress,
            opacity: opacity,
            borderRadius: widget.borderRadius,
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _AppleShineBorderPainter extends CustomPainter {
  _AppleShineBorderPainter({
    required this.progress,
    required this.opacity,
    required this.borderRadius,
    required this.isDark,
  });

  final double progress;
  final double opacity;
  final double borderRadius;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    // Slight outset so the ring sits on the card edge, not hidden underneath.
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1.0, size.height - 1.0),
      Radius.circular(borderRadius + 0.5),
    );

    final Rect shaderRect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * 1.35,
      height: size.height * 1.35,
    );
    final double angle = progress * math.pi * 2;
    final double v = opacity.clamp(0.0, 1.0);

    Shader buildShader(double layerIntensity) {
      final double a = layerIntensity * v;
      final Color highlight = Colors.white;
      final Color ice = const Color(0xFFD4ECFF);
      final Color sky = const Color(0xFF5EB8FF);
      final Color appleBlue = const Color(0xFF32A8FF);
      final Color baseTint = isDark
          ? const Color(0xFF8EC8FF)
          : const Color(0xFF4DA3FF);

      return SweepGradient(
        center: Alignment.center,
        colors: [
          baseTint.withValues(alpha: 0.143 * a),
          ice.withValues(alpha: 0.325 * a),
          sky.withValues(alpha: 0.507 * a),
          appleBlue.withValues(alpha: 0.553 * a),
          highlight.withValues(alpha: 0.65 * a),
          appleBlue.withValues(alpha: 0.533 * a),
          sky.withValues(alpha: 0.468 * a),
          ice.withValues(alpha: 0.312 * a),
          baseTint.withValues(alpha: 0.13 * a),
          baseTint.withValues(alpha: 0.143 * a),
        ],
        stops: const [
          0.0,
          0.14,
          0.30,
          0.42,
          0.50,
          0.58,
          0.70,
          0.86,
          0.96,
          1.0,
        ],
        transform: GradientRotation(angle),
      ).createShader(shaderRect);
    }

    // Soft constant edge so the card always has a visible rim when active.
    final Paint baseRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = (isDark ? const Color(0xFF8EC8FF) : const Color(0xFF5EB8FF))
          .withValues(alpha: 0.182 * v);
    canvas.drawRRect(rrect, baseRingPaint);

    final Paint outerGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..shader = buildShader(0.72)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(rrect, outerGlowPaint);

    final Paint glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.9
      ..shader = buildShader(0.88)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.25);
    canvas.drawRRect(rrect, glowPaint);

    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.82
      ..shader = buildShader(1.0);
    canvas.drawRRect(rrect, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _AppleShineBorderPainter old) =>
      old.progress != progress ||
      old.opacity != opacity ||
      old.borderRadius != borderRadius ||
      old.isDark != isDark;
}