import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

/// Carousel position readout for the IDs rail.
///
/// Deliberately carries no implicit animation. This is rebuilt from an
/// [AnimatedBuilder] on a live [PageController], so [page] already arrives
/// every frame; wrapping that in a 200ms AnimatedContainer/AnimatedPositioned
/// retargeted a tween that never finished, so the indicator lagged the finger
/// and re-ran layout on every drag frame. Size and opacity are derived
/// straight from [page], and the scroll pill moves under a paint-only
/// [Transform].
class DotIndicator extends StatelessWidget {
  const DotIndicator({super.key, required this.count, required this.page});
  final int count;
  final double page;

  static const int _dotThreshold = 5;
  static const double _trackH = 48.0;
  static const double _thickness = 4.0;

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1C1C1E);

    if (count <= _dotThreshold) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(count, (int i) {
          final double distance = (page - i).abs().clamp(0.0, 1.0);
          final double size = lerpDouble(10, 6, distance)!;
          final double opacity = lerpDouble(1.0, 0.25, distance)!;
          return Container(
            width: size,
            height: size,
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: ink.withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          );
        }),
      );
    }

    final double pillH = (_trackH / count).clamp(6.0, _trackH * 0.5);
    final double offset =
        (page / (count - 1)).clamp(0.0, 1.0) * (_trackH - pillH);

    return SizedBox(
      width: _thickness,
      height: _trackH,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(_thickness / 2),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Transform.translate(
              offset: Offset(0, offset),
              child: Container(
                width: _thickness,
                height: pillH,
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.60),
                  borderRadius: BorderRadius.circular(_thickness / 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
