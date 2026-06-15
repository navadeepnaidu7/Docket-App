import 'package:flutter/material.dart';

class RollPageStack extends StatelessWidget {
  const RollPageStack({
    super.key,
    required this.delta,
    required this.child,
    required this.padding,
  });

  final double delta; // -1.0 (above) to +1.0 (below), 0.0 = current active card
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final bool isLeaving = delta < 0;
    final double absDelta = delta.abs();

    // Smooth scaling as cards leave the top stack or enter from the bottom
    final double scale = 1.0 - (absDelta * 0.12).clamp(0.0, 1.0);

    // Dynamic 3D rotation tilt
    final double tilt = delta * 0.25;

    // Parallax stacking translateY offset:
    // When leaving (moving up), it moves slower and gets covered by the incoming card.
    // When entering from below, it moves upward with a nice sweep.
    final double translateY = isLeaving
        ? -delta * MediaQuery.of(context).size.height * 0.4
        : delta * 40.0;

    final Matrix4 m = Matrix4.identity()
      ..setEntry(3, 2, 0.0015) // 3D Perspective coefficient
      ..translateByDouble(0.0, translateY, 0.0, 1.0)
      ..rotateX(tilt)
      ..scaleByDouble(scale, scale, 1.0, 1.0);

    // Fade out smoothly when the card moves out of view at the top of the stack
    final double opacity = isLeaving
        ? (1.0 - absDelta * 1.5).clamp(0.0, 1.0)
        : 1.0;

    return Padding(
      padding: padding,
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: Transform(
            transform: m,
            alignment: isLeaving ? Alignment.bottomCenter : Alignment.topCenter,
            child: child,
          ),
        ),
      ),
    );
  }
}
