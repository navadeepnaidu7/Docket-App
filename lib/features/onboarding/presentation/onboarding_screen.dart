import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../dashboard/presentation/dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  double _page = 0;

  static const List<_OnboardingStep> _steps = <_OnboardingStep>[
    _OnboardingStep(
      eyebrow: 'SlickPort',
      title: 'Your passport, staged like a private pass.',
      body:
          'Capture identity details into a refined local workspace built for clarity and speed.',
      icon: Icons.auto_awesome_rounded,
      primary: Color(0xFF0B1B34),
      accent: Color(0xFFC9A760),
      secondary: Color(0xFF2F9B9B),
    ),
    _OnboardingStep(
      eyebrow: 'MRZ capture',
      title: 'Aim once. Let the scan line find the signal.',
      body:
          'The camera flow is shaped around the machine readable zone, ready for OCR integration.',
      icon: Icons.document_scanner_rounded,
      primary: Color(0xFF111F36),
      accent: Color(0xFFD3B77A),
      secondary: Color(0xFF5FA7A0),
    ),
    _OnboardingStep(
      eyebrow: 'Chip ready',
      title: 'A calm NFC moment for verified identity.',
      body:
          'MRZ-derived access keys prepare the secure chip read while sensitive data stays offline.',
      icon: Icons.nfc_rounded,
      primary: Color(0xFF0E1A2D),
      accent: Color(0xFF3DC7B3),
      secondary: Color(0xFFD7B25A),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_handlePageChange);
  }

  @override
  void dispose() {
    _pageController
      ..removeListener(_handlePageChange)
      ..dispose();
    super.dispose();
  }

  void _handlePageChange() {
    setState(() {
      _page = _pageController.page ?? 0;
    });
  }

  Future<void> _continue() async {
    final int current = _page.round();
    if (current < _steps.length - 1) {
      _pageController.animateToPage(
        current + 1,
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 760),
        reverseTransitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, _, _) => const DashboardScreen(),
        transitionsBuilder: (_, Animation<double> animation, _, Widget child) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int activeIndex = _page.round().clamp(0, _steps.length - 1).toInt();
    final _OnboardingStep activeStep = _steps[activeIndex];

    return Scaffold(
      backgroundColor: activeStep.primary,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.28,
            colors: <Color>[
              activeStep.accent.withValues(alpha: 0.46),
              activeStep.primary,
              const Color(0xFF05070C),
            ],
            stops: const <double>[0, 0.46, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _TopBar(progress: (_page + 1) / _steps.length),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _steps.length,
                  itemBuilder: (BuildContext context, int index) {
                    final double delta = (_page - index)
                        .clamp(-1.0, 1.0)
                        .toDouble();
                    return _OnboardingPage(
                      step: _steps[index],
                      delta: delta,
                      pageIndex: index,
                    );
                  },
                ),
              ),
              _BottomControls(
                activeIndex: activeIndex,
                stepCount: _steps.length,
                isLast: activeIndex == _steps.length - 1,
                onContinue: _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: const Icon(Icons.credit_card_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1).toDouble(),
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.step,
    required this.delta,
    required this.pageIndex,
  });

  final _OnboardingStep step;
  final double delta;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    final double textOffset = 34 * delta;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double visualHeight = math.min(
            constraints.maxHeight * 0.48,
            360,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: visualHeight,
                child: _PassportStage(
                  step: step,
                  delta: delta,
                  pageIndex: pageIndex,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Transform.translate(
                  offset: Offset(textOffset, 0),
                  child: Opacity(
                    opacity: (1 - delta.abs() * 0.35)
                        .clamp(0.0, 1.0)
                        .toDouble(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _Eyebrow(step: step),
                        const SizedBox(height: 12),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              width: MediaQuery.sizeOf(context).width - 44,
                              child: Text(
                                step.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 35,
                                  height: 1.02,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          step.body,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 16,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PassportStage extends StatelessWidget {
  const _PassportStage({
    required this.step,
    required this.delta,
    required this.pageIndex,
  });

  final _OnboardingStep step;
  final double delta;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double rotation = -0.14 + (delta * -0.08);
        final double lift = 18 * delta.abs();
        final double bookHeight = math.min(constraints.maxHeight * 0.9, 315);
        final double bookWidth = bookHeight * 0.78;

        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned(
              top: 16 + lift,
              left: 8,
              right: 8,
              child: _GlassHalo(color: step.secondary),
            ),
            Positioned(
              top: 28,
              left: 16 + (delta * 26),
              child: _FloatingToken(
                icon: step.icon,
                color: step.accent,
                label: step.eyebrow,
              ),
            ),
            Positioned(
              right: 16 - (delta * 28),
              bottom: 30,
              child: _NfcRing(color: step.secondary, visible: pageIndex == 2),
            ),
            Transform.translate(
              offset: Offset(delta * -34, lift),
              child: Transform.rotate(
                angle: rotation,
                child: _PassportBook(
                  step: step,
                  pageIndex: pageIndex,
                  width: bookWidth,
                  height: bookHeight,
                ),
              ),
            ),
            Positioned(
              left: 32,
              right: 32,
              bottom: 22,
              child: _ScanBeam(color: step.accent, active: pageIndex == 1),
            ),
          ],
        );
      },
    );
  }
}

class _GlassHalo extends StatelessWidget {
  const _GlassHalo({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        height: 230,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(48),
          color: color.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

class _PassportBook extends StatelessWidget {
  const _PassportBook({
    required this.step,
    required this.pageIndex,
    required this.width,
    required this.height,
  });

  final _OnboardingStep step;
  final int pageIndex;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 24,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Icon(step.icon, color: Colors.white, size: 30),
                    _StatusPill(text: pageIndex == 2 ? 'BAC' : 'MRZ'),
                  ],
                ),
                const Spacer(),
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutCubic,
                    child: Icon(
                      pageIndex == 2
                          ? Icons.fingerprint_rounded
                          : Icons.public_rounded,
                      key: ValueKey<int>(pageIndex),
                      color: step.accent,
                      size: math.min(height * 0.22, 72),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  height: math.min(height * 0.18, 56),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      _DataLine(widthFactor: 0.92),
                      _DataLine(widthFactor: 0.74),
                      _DataLine(widthFactor: 0.84),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DataLine extends StatelessWidget {
  const _DataLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 3.5,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _FloatingToken extends StatelessWidget {
  const _FloatingToken({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _NfcRing extends StatelessWidget {
  const _NfcRing({required this.color, required this.visible});

  final Color color;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: visible ? 1.0 : 0.75,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.22,
        duration: const Duration(milliseconds: 420),
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.82), width: 2),
          ),
          child: Center(
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.52),
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanBeam extends StatelessWidget {
  const _ScanBeam({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: active ? 1.0 : 0.22,
      duration: const Duration(milliseconds: 360),
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: <BoxShadow>[
            BoxShadow(color: color.withValues(alpha: 0.66), blurRadius: 18),
          ],
          gradient: LinearGradient(
            colors: <Color>[
              Colors.transparent,
              color,
              Colors.white,
              color,
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.step});

  final _OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: step.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: step.accent.withValues(alpha: 0.28)),
      ),
      child: Text(
        step.eyebrow,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.activeIndex,
    required this.stepCount,
    required this.isLast,
    required this.onContinue,
  });

  final int activeIndex;
  final int stepCount;
  final bool isLast;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
      child: Row(
        children: <Widget>[
          Row(
            children: List<Widget>.generate(stepCount, (int index) {
              final bool active = index == activeIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                width: active ? 28 : 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: active ? 0.95 : 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
          const Spacer(),
          FilledButton(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF07111F),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: Text(
                isLast ? 'Enter SlickPort' : 'Continue',
                key: ValueKey<bool>(isLast),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.icon,
    required this.primary,
    required this.accent,
    required this.secondary,
  });

  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
  final Color primary;
  final Color accent;
  final Color secondary;
}
