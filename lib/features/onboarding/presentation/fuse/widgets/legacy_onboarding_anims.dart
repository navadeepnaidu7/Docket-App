import 'dart:math' as math;

import 'package:flutter/material.dart';

class LegacyOnboardingIllustration extends StatelessWidget {
  const LegacyOnboardingIllustration({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return switch (index) {
      0 => const WalletOnboardingAnim(delta: 0),
      1 => const ScannerOnboardingAnim(delta: 0),
      2 => const NfcOnboardingAnim(delta: 0),
      _ => const PassesOnboardingAnim(),
    };
  }
}

class WalletOnboardingAnim extends StatefulWidget {
  const WalletOnboardingAnim({super.key, this.delta = 0});
  final double delta;

  @override
  State<WalletOnboardingAnim> createState() => _WalletOnboardingAnimState();
}

class _WalletOnboardingAnimState extends State<WalletOnboardingAnim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _slideAnim = Tween<double>(begin: -140.0, end: -15.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double lift = 14 * widget.delta.abs();
    final double rotation = -0.10 + (widget.delta * -0.06);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardH = constraints.maxHeight * 0.76;
        final cardW = cardH * 1.586;

        return Center(
          child: SizedBox(
            width: cardW,
            height: cardH + 20,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: cardH * 0.72,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.04),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _slideAnim,
                  builder: (context, child) {
                    return Positioned(
                      top: _slideAnim.value + lift,
                      left: 12,
                      right: 12,
                      height: cardH * 0.88,
                      child: Transform.rotate(angle: rotation, child: child),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF0F2C59), Color(0xFF1B3A6B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Icon(Icons.public_rounded, color: Color(0xFFD3B77A), size: 18),
                              SizedBox(width: 16, height: 10),
                            ],
                          ),
                          SizedBox(height: 10),
                          Text(
                            'PASSPORT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: cardH * 0.64,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.06),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ScannerOnboardingAnim extends StatefulWidget {
  const ScannerOnboardingAnim({super.key, this.delta = 0});
  final double delta;

  @override
  State<ScannerOnboardingAnim> createState() => _ScannerOnboardingAnimState();
}

class _ScannerOnboardingAnimState extends State<ScannerOnboardingAnim>
    with TickerProviderStateMixin {
  late final AnimationController _slideController;
  late final AnimationController _scanController;
  late final Animation<double> _slideAnim;
  late final Animation<double> _laserAnim;

  int _revealedFields = 0;
  bool _scanComplete = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnim = Tween<double>(begin: 160, end: 0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _laserAnim = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(tween: Tween<double>(begin: 0.05, end: 0.95), weight: 40),
      TweenSequenceItem<double>(tween: Tween<double>(begin: 0.95, end: 0.05), weight: 35),
      TweenSequenceItem<double>(tween: Tween<double>(begin: 0.05, end: 0.95), weight: 25),
    ]).animate(CurvedAnimation(parent: _scanController, curve: Curves.easeInOutSine));

    _slideController.forward().then((_) {
      if (mounted) _scanController.forward();
    });

    _scanController.addListener(() {
      final double val = _scanController.value;
      if (!mounted) return;
      setState(() {
        if (val > 0.20 && _revealedFields < 1) _revealedFields = 1;
        if (val > 0.50 && _revealedFields < 2) _revealedFields = 2;
        if (val > 0.80 && _revealedFields < 3) _revealedFields = 3;
        if (_scanController.isCompleted) _scanComplete = true;
      });
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardH = constraints.maxHeight * 0.72;
        final double cardW = cardH * 1.586;

        return Center(
          child: SizedBox(
            width: cardW,
            height: cardH,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: <Widget>[
                AnimatedBuilder(
                  animation: _slideAnim,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _slideAnim.value),
                      child: child,
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _revealFieldWidget('SURNAME', 'KUMAR', _revealedFields >= 1),
                        const Spacer(),
                        _revealFieldWidget('NATIONALITY', 'INDIAN', _revealedFields >= 3),
                      ],
                    ),
                  ),
                ),
                if (_slideController.isCompleted && !_scanComplete)
                  AnimatedBuilder(
                    animation: _laserAnim,
                    builder: (context, child) {
                      return Positioned(
                        top: _laserAnim.value * (cardH - 14) + 7,
                        left: 8,
                        right: 8,
                        child: child!,
                      );
                    },
                    child: Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F9B9B),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _revealFieldWidget(String label, String value, bool revealed) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 240),
      crossFadeState: revealed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild: Container(
        width: 50,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      secondChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: TextStyle(color: Colors.black.withValues(alpha: 0.4), fontSize: 7)),
          Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class NfcOnboardingAnim extends StatefulWidget {
  const NfcOnboardingAnim({super.key, this.delta = 0});
  final double delta;

  @override
  State<NfcOnboardingAnim> createState() => _NfcOnboardingAnimState();
}

class _NfcOnboardingAnimState extends State<NfcOnboardingAnim>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _progressController;
  late final Animation<double> _progressAnim;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _progressAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOutCubic),
    );
    _progressController.forward();
    _progressController.addListener(() {
      if (_progressController.isCompleted && mounted) {
        setState(() => _isVerified = true);
        _pulseController.stop();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 180,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned(
              bottom: 0,
              child: Container(
                width: 120,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                ),
              ),
            ),
            if (!_isVerified)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return CustomPaint(
                    size: const Size(90, 50),
                    painter: _NfcWavePainter(progress: _pulseController.value),
                  );
                },
              ),
            Positioned(
              top: 0,
              child: Container(
                width: 90,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: AnimatedBuilder(
                  animation: _progressAnim,
                  builder: (context, _) {
                    return Center(
                      child: _isVerified
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF3DC7B3), size: 28)
                          : Text(
                              '${(_progressAnim.value * 100).toInt()}%',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PassesOnboardingAnim extends StatefulWidget {
  const PassesOnboardingAnim({super.key});

  @override
  State<PassesOnboardingAnim> createState() => _PassesOnboardingAnimState();
}

class _PassesOnboardingAnimState extends State<PassesOnboardingAnim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 220,
        height: 110,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _TicketProgressPainter(progress: _controller.value),
              child: child,
            );
          },
          child: Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0B2A4A),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.topLeft,
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'RAJDHANI EXPRESS',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'NDLS → MMCT',
                    style: TextStyle(color: Colors.white70, fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NfcWavePainter extends CustomPainter {
  _NfcWavePainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF3DC7B3).withValues(alpha: 1 - progress)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double cx = size.width / 2;
    final double radius = 8 + progress * 30;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, 0), radius: radius),
      math.pi * 0.25,
      math.pi * 0.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _NfcWavePainter old) => old.progress != progress;
}

class _TicketProgressPainter extends CustomPainter {
  _TicketProgressPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF60A5FA)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final double y = size.height - 10;
    final double startX = 12;
    final double endX = size.width - 12;
    final double currentX = startX + (endX - startX) * progress;

    canvas.drawLine(Offset(startX, y), Offset(endX, y), paint..color = Colors.black.withValues(alpha: 0.08));
    canvas.drawLine(Offset(startX, y), Offset(currentX, y), paint..color = const Color(0xFF60A5FA));
  }

  @override
  bool shouldRepaint(covariant _TicketProgressPainter old) => old.progress != progress;
}