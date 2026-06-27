import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/onboarding_content.dart';
import '../../../../core/motion/entry_reveal.dart';
import '../../../../core/motion/smooth_curves.dart';
import '../../../../shared/widgets/bounce_tap.dart';

class CompletionStep extends StatefulWidget {
  const CompletionStep({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<CompletionStep> createState() => _CompletionStepState();
}

class _CompletionStepState extends State<CompletionStep>
    with TickerProviderStateMixin {
  late final AnimationController _spinController;
  late final AnimationController _successController;
  bool _isCompleted = false;
  bool _hasCompleted = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _successController = AnimationController(
      vsync: this,
      duration: bouncyDuration,
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _isCompleted = true);
    _spinController.stop();
    _successController.forward();
  }

  void _finish() {
    if (_hasCompleted) return;
    _hasCompleted = true;
    widget.onComplete();
  }

  @override
  void dispose() {
    _spinController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(42, 80, 42, 32),
      child: Column(
        children: <Widget>[
          const Spacer(),
          EntryReveal(
            delay: const Duration(milliseconds: 400),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              transitionBuilder: (Widget child, Animation<double> animation) {
                final bool entering = child.key == const ValueKey<bool>(true);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0, entering ? 0.08 : -0.12),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _isCompleted
                  ? ScaleTransition(
                      key: const ValueKey<bool>(true),
                      scale: CurvedAnimation(parent: _successController, curve: bouncyCurve),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF22C55E),
                        size: 72,
                      ),
                    )
                  : AnimatedBuilder(
                      key: const ValueKey<bool>(false),
                      animation: _spinController,
                      builder: (context, _) {
                        return CustomPaint(
                          size: const Size(72, 72),
                          painter: _DashedRingPainter(rotation: _spinController.value),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            child: Text(
              _isCompleted
                  ? OnboardingContent.completionSuccessTitle
                  : OnboardingContent.completionLoadingTitle,
              key: ValueKey<bool>(_isCompleted),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            child: Text(
              _isCompleted
                  ? OnboardingContent.completionSuccessDescription
                  : OnboardingContent.completionLoadingDescription,
              key: ValueKey<String>(_isCompleted ? 'success-desc' : 'loading-desc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.58),
                fontSize: 16,
                height: 1.45,
              ),
            ),
          ),
          const Spacer(),
          if (_isCompleted)
            EntryReveal(
              child: BounceTap(
                onTap: _finish,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Enter SlickPort',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  _DashedRingPainter({required this.rotation});
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 4;
    const int segments = 12;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * math.pi * 2);
    canvas.translate(-center.dx, -center.dy);

    for (int i = 0; i < segments; i++) {
      if (i.isEven) continue;
      final double start = (i / segments) * math.pi * 2;
      final double sweep = (math.pi * 2) / segments * 0.55;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter old) => old.rotation != rotation;
}