import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Empty-state artwork for Trash: a glass tray holding one card, while a
/// second card rises out of it and settles back in.
///
/// The story is the view's promise — removed documents are kept, and come
/// back out whole — told in the glass material and palette of Home's
/// [EmptyDocsPreview] and Manage's [ManageOrderPreview].
class TrashTrayPreview extends StatefulWidget {
  const TrashTrayPreview({super.key});

  @override
  State<TrashTrayPreview> createState() => _TrashTrayPreviewState();
}

class _TrashTrayPreviewState extends State<TrashTrayPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4400),
  );

  static const double _cardWidth = 136;
  static const double _cardHeight = 86;

  /// Card top when lifted clear of the tray, and when resting inside it.
  static const double _outY = 4;
  static const double _inY = 56;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion rests on the lifted frame: card out, tray visible.
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

  static double _ramp(double t, double a, double b) =>
      Curves.easeInOutCubic.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (BuildContext context, _) {
        final double t = _ctrl.value;
        // Out, sink, rest inside, rise, rest out.
        final double sink = _ramp(t, 0.18, 0.42) - _ramp(t, 0.62, 0.86);

        return SizedBox(
          width: 220,
          height: 164,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              // Tray back wall.
              Positioned(
                left: 18,
                right: 18,
                top: 74,
                height: 84,
                child: _Glass(
                  radius: 22,
                  tint: const Color(0xFF2A9D8F),
                  fill: 0.26,
                  tintAlpha: 0.10,
                ),
              ),
              // The card that stays: already kept.
              Positioned(
                left: (220 - _cardWidth) / 2 - 10,
                top: 64,
                child: Transform.rotate(
                  angle: 0.06,
                  child: const _GhostCard(
                    color: Color(0xFF7C5CBF),
                    alpha: 0.50,
                    width: _cardWidth,
                    height: _cardHeight,
                  ),
                ),
              ),
              // The card that comes and goes.
              Positioned(
                left: (220 - _cardWidth) / 2 + 6,
                top: lerpDouble(_outY, _inY, sink),
                child: Transform.rotate(
                  angle: lerpDouble(-0.07, -0.01, sink)!,
                  child: _GhostCard(
                    color: const Color(0xFF4C7CFF),
                    alpha: 0.72,
                    width: _cardWidth,
                    height: _cardHeight,
                    lift: 1 - sink,
                  ),
                ),
              ),
              // Tray front lip, over both cards.
              Positioned(
                left: 18,
                right: 18,
                top: 102,
                height: 56,
                child: _Glass(
                  radius: 20,
                  tint: const Color(0xFF2A9D8F),
                  fill: 0.62,
                  tintAlpha: 0.12,
                  child: Align(
                    alignment: const Alignment(0, -0.45),
                    child: Container(
                      width: 38,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A9D8F).withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({
    required this.radius,
    required this.tint,
    required this.fill,
    required this.tintAlpha,
    this.child,
  });

  final double radius;
  final Color tint;
  final double fill;
  final double tintAlpha;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              tint.withValues(alpha: tintAlpha),
              Colors.white.withValues(alpha: fill),
            ),
            Colors.white.withValues(alpha: fill * 0.7),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tint.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A document card with nothing on it: photo block and three text bars, the
/// same anatomy as Home's ghost cards at a smaller size.
class _GhostCard extends StatelessWidget {
  const _GhostCard({
    required this.color,
    required this.alpha,
    required this.width,
    required this.height,
    this.lift = 0,
  });

  final Color color;
  final double alpha;
  final double width;
  final double height;

  /// 0 resting in the tray, 1 held clear of it.
  final double lift;

  @override
  Widget build(BuildContext context) {
    final Color mark = color.withValues(alpha: 0.18 * alpha);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              color.withValues(alpha: 0.16 * alpha),
              Colors.white.withValues(alpha: 0.66),
            ),
            Colors.white.withValues(alpha: 0.48),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: (0.10 + 0.14 * lift) * alpha),
            blurRadius: 14 + 14 * lift,
            offset: Offset(0, 6 + 8 * lift),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32,
            height: 24,
            decoration: BoxDecoration(
              color: mark,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          const Spacer(),
          for (int i = 0; i < 2; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 6),
            Container(
              width: i == 0 ? 76 : 48,
              height: 5,
              decoration: BoxDecoration(
                color: mark,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
