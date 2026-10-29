import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Empty-state artwork for Manage: three glass rows, one of which lifts and
/// swaps places with its neighbour, then swaps back.
///
/// Home's artwork fans cards because Home shows cards. Manage shows the same
/// wallet as a list you put in order, so its artwork is that list performing
/// its one gesture — a drag — rather than the Home picture again. The glass
/// material and palette match [EmptyDocsPreview] so the two read as siblings.
class ManageOrderPreview extends StatefulWidget {
  const ManageOrderPreview({super.key});

  @override
  State<ManageOrderPreview> createState() => _ManageOrderPreviewState();
}

class _ManageOrderPreviewState extends State<ManageOrderPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  static const double _rowHeight = 40;
  static const double _gap = 10;
  static const double _slot = _rowHeight + _gap;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion keeps the resting frame; the picture still reads.
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl
        ..stop()
        ..value = 0;
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 0 before [a], 1 after [b], eased in between.
  static double _ramp(double t, double a, double b) =>
      Curves.easeInOutCubic.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (BuildContext context, _) {
        final double t = _ctrl.value;
        // Pick up, carry down, set down, rest; then the same in reverse.
        final double lift =
            _ramp(t, 0.10, 0.18) -
            _ramp(t, 0.40, 0.48) +
            _ramp(t, 0.58, 0.66) -
            _ramp(t, 0.88, 0.96);
        final double swap = _ramp(t, 0.18, 0.40) - _ramp(t, 0.66, 0.88);

        return SizedBox(
          width: 220,
          height: 164,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: <Widget>[
              // Static third row, then the neighbour, then the carried row on
              // top so it passes over rather than under.
              _positioned(
                y: 2 * _slot,
                child: const _GhostRow(color: Color(0xFF2A9D8F), alpha: 0.48),
              ),
              _positioned(
                y: lerpDouble(_slot, 0, swap)!,
                child: const _GhostRow(color: Color(0xFF7C5CBF), alpha: 0.58),
              ),
              _positioned(
                y: lerpDouble(0, _slot, swap)!,
                x: 6 * lift,
                child: _GhostRow(
                  color: const Color(0xFF4C7CFF),
                  alpha: 0.72,
                  lift: lift,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _positioned({required double y, double x = 0, required Widget child}) {
    return Positioned(
      // Centre the 150 px list vertically in the 164 px box.
      top: 7 + y,
      left: 6 + x,
      child: child,
    );
  }
}

/// One wallet row with nothing in it: mini card, two text bars, a handle.
class _GhostRow extends StatelessWidget {
  const _GhostRow({required this.color, required this.alpha, this.lift = 0});

  final Color color;
  final double alpha;

  /// 0 resting, 1 held by the finger.
  final double lift;

  @override
  Widget build(BuildContext context) {
    final Color mark = color.withValues(alpha: (0.18 + 0.10 * lift) * alpha);

    return Transform.scale(
      scale: 1 + 0.04 * lift,
      child: Container(
        width: 208,
        height: _ManageOrderPreviewState._rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color.alphaBlend(
                color.withValues(alpha: 0.14 * alpha),
                Colors.white.withValues(alpha: 0.56),
              ),
              Colors.white.withValues(alpha: 0.40),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: (0.12 + 0.16 * lift) * alpha),
              blurRadius: 14 + 14 * lift,
              offset: Offset(0, 6 + 8 * lift),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 26,
              height: 17,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    color.withValues(alpha: 0.55 * alpha),
                    color.withValues(alpha: 0.30 * alpha),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _bar(width: 62, height: 5, color: mark),
                const SizedBox(height: 5),
                _bar(width: 38, height: 4, color: mark),
              ],
            ),
            const Spacer(),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < 3; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: 3),
                  _bar(width: 12, height: 2, color: mark),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _bar({
    required double width,
    required double height,
    required Color color,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
