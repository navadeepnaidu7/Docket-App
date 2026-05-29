import 'package:flutter/material.dart';

// A custom easeOutQuint curve — matches Apple's spring-like deceleration.
class _EaseOutQuint extends Curve {
  const _EaseOutQuint();
  @override
  double transformInternal(double t) {
    final double u = 1 - t;
    return 1 - u * u * u * u * u;
  }
}

const Curve easeOutQuint = _EaseOutQuint();

class EntryReveal extends StatefulWidget {
  const EntryReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 480),
    this.curve = easeOutQuint,
    this.slideY = 20,
    this.enabled,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final double slideY;
  final bool? enabled;

  @override
  State<EntryReveal> createState() => _EntryRevealState();
}

class _EntryRevealState extends State<EntryReveal>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    if (!(widget.enabled ?? true)) return;

    final Duration total = widget.delay + widget.duration;
    final int totalMs = total.inMilliseconds == 0 ? 1 : total.inMilliseconds;
    final double start = widget.delay.inMilliseconds / totalMs;

    _controller = AnimationController(vsync: this, duration: total);
    _animation = CurvedAnimation(
      parent: _controller!,
      curve: Interval(start, 1.0, curve: widget.curve),
    );
    _controller!.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!(widget.enabled ?? true)) return widget.child;

    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double v = _animation.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, widget.slideY * (1 - v)),
            child: child,
          ),
        );
      },
    );
  }
}
