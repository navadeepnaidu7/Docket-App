import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/haptics/haptic_service.dart';
import '../../core/motion/entry_reveal.dart';
import '../../core/motion/smooth_curves.dart';
import '../../core/sound/sound_service.dart';
import 'bounce_tap.dart';

class SaveCompletionContent {
  static const String loadingTitle = 'Saving to your wallet';
  static const String loadingDescription = 'Encrypting and storing on your device.';
  static const String successTitle = "You're all set";
  static const String successDescription = 'Your document is securely stored in your wallet.';
}

/// Standard post-save celebration for any wallet item (passport, ID, pass, etc.).
/// Call after persisting the item; pops [navigatorPopCount] routes when finished.
Future<void> showWalletSaveCelebration(
  BuildContext context, {
  int navigatorPopCount = 2,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: false,
    pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
      final Color bg = Theme.of(context).scaffoldBackgroundColor;
      return Scaffold(
        backgroundColor: bg,
        body: CompletionCelebration(
          loadingTitle: SaveCompletionContent.loadingTitle,
          loadingDescription: SaveCompletionContent.loadingDescription,
          successTitle: SaveCompletionContent.successTitle,
          successDescription: SaveCompletionContent.successDescription,
          autoCompleteAfterSuccess: const Duration(milliseconds: 800),
          onComplete: () {
            final NavigatorState navigator = Navigator.of(context);
            for (int i = 0; i < navigatorPopCount; i++) {
              if (!navigator.canPop()) break;
              navigator.pop();
            }
          },
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class CompletionCelebration extends StatefulWidget {
  const CompletionCelebration({
    super.key,
    required this.loadingTitle,
    required this.loadingDescription,
    required this.successTitle,
    required this.successDescription,
    required this.onComplete,
    this.actionLabel,
    this.autoCompleteAfterSuccess,
    this.loadingDelay = const Duration(milliseconds: 1400),
  });

  final String loadingTitle;
  final String loadingDescription;
  final String successTitle;
  final String successDescription;
  final VoidCallback onComplete;
  final String? actionLabel;
  final Duration? autoCompleteAfterSuccess;
  final Duration loadingDelay;

  @override
  State<CompletionCelebration> createState() => _CompletionCelebrationState();
}

class _CompletionCelebrationState extends State<CompletionCelebration>
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
    await Future<void>.delayed(widget.loadingDelay);
    if (!mounted) return;
    setState(() => _isCompleted = true);
    _spinController.stop();
    await HapticService.success();
    SoundService.success();
    await _successController.forward();

    final Duration? autoComplete = widget.autoCompleteAfterSuccess;
    if (autoComplete != null) {
      await Future<void>.delayed(autoComplete);
      if (mounted) _finish();
    }
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
    final String? actionLabel = widget.actionLabel;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color ink = scheme.onSurface;
    final Color primary = scheme.primary;

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
                        color: Color(0xFF30D158),
                        size: 72,
                      ),
                    )
                  : AnimatedBuilder(
                      key: const ValueKey<bool>(false),
                      animation: _spinController,
                      builder: (context, _) {
                        return CustomPaint(
                          size: const Size(72, 72),
                          painter: _DashedRingPainter(
                            rotation: _spinController.value,
                            color: ink.withValues(alpha: 0.40),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            child: Text(
              _isCompleted ? widget.successTitle : widget.loadingTitle,
              key: ValueKey<bool>(_isCompleted),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ink,
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
              _isCompleted ? widget.successDescription : widget.loadingDescription,
              key: ValueKey<String>(_isCompleted ? 'success-desc' : 'loading-desc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ink.withValues(alpha: 0.62),
                fontSize: 16,
                height: 1.45,
              ),
            ),
          ),
          const Spacer(),
          if (_isCompleted && actionLabel != null)
            EntryReveal(
              child: BounceTap(
                onTap: _finish,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    actionLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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
  _DashedRingPainter({required this.rotation, required this.color});
  final double rotation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
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
  bool shouldRepaint(covariant _DashedRingPainter old) =>
      old.rotation != rotation || old.color != color;
}