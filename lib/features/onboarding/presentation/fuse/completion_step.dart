import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
          if (_isCompleted) ...[
            EntryReveal(
              child: _GoogleSignInButton(
                onSuccess: _finish,
              ),
            ),
            const SizedBox(height: 12),
            EntryReveal(
              delay: const Duration(milliseconds: 150),
              child: BounceTap(
                onTap: _finish,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Enter SlickPort',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.6),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
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

enum _GoogleButtonState { idle, morphing, loading, success }

class _GoogleSignInButton extends StatefulWidget {
  const _GoogleSignInButton({required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton>
    with SingleTickerProviderStateMixin {
  _GoogleButtonState _state = _GoogleButtonState.idle;
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_state != _GoogleButtonState.idle) return;

    setState(() => _state = _GoogleButtonState.morphing);

    // Morph transition duration is 300ms
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _state = _GoogleButtonState.loading);
      _spinController.repeat();

      // Simulate authentication loading for 1500ms
      Future<void>.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        _spinController.stop();
        setState(() => _state = _GoogleButtonState.success);
        HapticFeedback.mediumImpact();

        // Show checkmark for 800ms before navigating
        Future<void>.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          widget.onSuccess();
        });
      });
    });
  }

  Widget _buildContent() {
    switch (_state) {
      case _GoogleButtonState.idle:
      case _GoogleButtonState.morphing:
        return Row(
          key: const ValueKey<String>('idle-content'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CustomPaint(
              size: const Size(20, 20),
              painter: const _GoogleLogoPainter(),
            ),
            const SizedBox(width: 12),
            const Text(
              'Sign in with Google',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        );
      case _GoogleButtonState.loading:
        return Center(
          key: const ValueKey<String>('loading-content'),
          child: RotationTransition(
            turns: _spinController,
            child: CustomPaint(
              size: const Size(24, 24),
              painter: const _GoogleLoaderPainter(),
            ),
          ),
        );
      case _GoogleButtonState.success:
        return Center(
          key: const ValueKey<String>('success-content'),
          child: const Icon(
            Icons.check_rounded,
            color: Color(0xFF34A853),
            size: 28,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = _state == _GoogleButtonState.idle;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double targetWidth = isWide ? constraints.maxWidth : 56.0;

        return BounceTap(
          onTap: _state == _GoogleButtonState.idle ? _handleTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            width: targetWidth,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.12),
                width: 1.5,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildContent(),
            ),
          ),
        );
      },
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double r = w / 2;
    final Offset center = Offset(w / 2, h / 2);
    final double strokeWidth = w * 0.23;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final Rect rect = Rect.fromCircle(center: center, radius: r - strokeWidth / 2);

    // Red: Top arc
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.4, 1.6, false, paint);

    // Yellow: Left arc
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -3.7, 1.3, false, paint);

    // Green: Bottom arc
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.5, 2.1, false, paint);

    // Blue: Right arc
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -1.0, 1.5, false, paint);

    // Blue horizontal bar
    final Paint barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final double barLeft = w / 2;
    final double barRight = w - strokeWidth / 2;
    final double barTop = h / 2 - strokeWidth / 2;
    final double barBottom = h / 2 + strokeWidth / 2;
    canvas.drawRect(
      Rect.fromLTRB(barLeft, barTop, barRight, barBottom),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoogleLoaderPainter extends CustomPainter {
  const _GoogleLoaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Colorful segmented Google loading ring
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, 0.0, 1.2, false, paint);

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 1.5, 1.2, false, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 3.0, 1.2, false, paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 4.5, 1.2, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}