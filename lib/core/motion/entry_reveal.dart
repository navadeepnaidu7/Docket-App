import 'package:flutter/material.dart';

class EntryReveal extends StatefulWidget {
  const EntryReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.curve = Curves.easeOutCubic,
    this.slideY = 22,
    this.scale = 0.98,
    this.enabled,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final double slideY;
  final double scale;
  final bool? enabled;

  @override
  State<EntryReveal> createState() => _EntryRevealState();
}

class _EntryRevealState extends State<EntryReveal> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    if (!(widget.enabled ?? true)) {
      return;
    }

    final Duration total = widget.delay + widget.duration;
    final int totalMs = total.inMilliseconds == 0 ? 1 : total.inMilliseconds;
    final double start = widget.delay.inMilliseconds / totalMs;

    _controller = AnimationController(vsync: this, duration: total);
    _animation = CurvedAnimation(
      parent: _controller!,
      curve: Interval(start, 1, curve: widget.curve),
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
    if (!(widget.enabled ?? true)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double value = _animation.value.clamp(0, 1);
        final double translateY = widget.slideY * (1 - value);
        final double scale = widget.scale + (1 - widget.scale) * value;

        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
    );
  }
}