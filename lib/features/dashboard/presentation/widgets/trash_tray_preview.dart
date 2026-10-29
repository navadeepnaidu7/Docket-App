import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// A kept ID lifting out of a frosted wastebasket, ready to be restored.
class TrashTrayPreview extends StatefulWidget {
  const TrashTrayPreview({super.key});

  @override
  State<TrashTrayPreview> createState() => _TrashTrayPreviewState();
}

class _TrashTrayPreviewState extends State<TrashTrayPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox(
      width: 220,
      height: 164,
      child: CustomPaint(
        painter: _TrashBasketPainter(
          motion: _ctrl,
          scheme: Theme.of(context).colorScheme,
        ),
      ),
    ),
  );
}

class _TrashBasketPainter extends CustomPainter {
  _TrashBasketPainter({required this.motion, required this.scheme})
    : super(repaint: motion);

  final Animation<double> motion;
  final ColorScheme scheme;

  static const Color _teal = Color(0xFF2A9D8F);
  static const Color _blue = Color(0xFF4C7CFF);

  bool get _dark => scheme.brightness == Brightness.dark;

  static double _ramp(double t, double start, double end) => Curves
      .easeInOutSine
      .transform(((t - start) / (end - start)).clamp(0.0, 1.0));

  Color _tint(Color color) =>
      _dark ? Color.lerp(color, Colors.white, 0.30)! : color;

  Color _surface(Color color, double strength, {bool lower = false}) =>
      Color.alphaBlend(
        color.withValues(alpha: strength),
        _dark
            ? (lower ? scheme.surface : scheme.surfaceContainerHighest)
            : Colors.white.withValues(alpha: lower ? 0.78 : 0.94),
      );

  void _roundRect(Canvas canvas, Rect rect, double radius, Color color) =>
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        Paint()..color = color,
      );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 220, size.height / 164);
    final double t = motion.value;
    final double lift = 1 - _ramp(t, 0.16, 0.40) + _ramp(t, 0.66, 0.90);
    final Color rim = _tint(_teal);

    // A soft contact shadow grounds the basket without a surrounding glow.
    canvas.drawOval(
      const Rect.fromLTWH(69, 150, 94, 10),
      Paint()
        ..color = (_dark ? Colors.black : _teal).withValues(
          alpha: _dark ? 0.32 : 0.12,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final Path back = Path()
      ..moveTo(51, 85)
      ..lineTo(63, 141)
      ..quadraticBezierTo(66, 154, 81, 154)
      ..lineTo(147, 154)
      ..quadraticBezierTo(162, 154, 165, 141)
      ..lineTo(177, 85)
      ..close();
    canvas.drawPath(back, Paint()..color = _surface(_teal, 0.15));

    // The recessed mouth remains visible behind the document.
    const Rect opening = Rect.fromLTWH(50, 76, 128, 20);
    canvas.drawOval(
      opening,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _surface(_teal, _dark ? 0.08 : 0.19, lower: true),
            _surface(_teal, _dark ? 0.22 : 0.10),
          ],
        ).createShader(opening),
    );
    canvas.drawArc(
      opening,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = rim.withValues(alpha: _dark ? 0.40 : 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    _paintDocument(canvas, lift);

    // Tapered sides and recessed ribs make this a basket, rather than a tray.
    final Path front = Path()
      ..moveTo(51, 85)
      ..cubicTo(77, 98, 151, 98, 177, 85)
      ..lineTo(165, 141)
      ..quadraticBezierTo(162, 154, 147, 154)
      ..lineTo(81, 154)
      ..quadraticBezierTo(66, 154, 63, 141)
      ..close();
    canvas.drawPath(
      front,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _surface(_teal, _dark ? 0.24 : 0.15),
            _surface(_teal, _dark ? 0.12 : 0.08, lower: true),
          ],
        ).createShader(const Rect.fromLTWH(51, 85, 126, 69)),
    );
    canvas.drawPath(
      front,
      Paint()
        ..color = rim.withValues(alpha: _dark ? 0.46 : 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    for (final double x in [92.0, 114.0, 136.0]) {
      final double inward = (114 - x) * 0.12;
      final Path rib = Path()
        ..moveTo(x, 112)
        ..lineTo(x + inward, 137);
      canvas.drawPath(
        rib.shift(const Offset(1, 0)),
        Paint()
          ..color = Colors.white.withValues(alpha: _dark ? 0.07 : 0.64)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        rib,
        Paint()
          ..color = rim.withValues(alpha: _dark ? 0.22 : 0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  void _paintDocument(Canvas canvas, double lift) {
    canvas.save();
    canvas.translate(116, lerpDouble(104, 77, lift)!);
    canvas.rotate(lerpDouble(-0.10, -0.16, lift)!);
    const Rect bounds = Rect.fromLTWH(-46, -62, 92, 62);
    final RRect card = RRect.fromRectAndRadius(
      bounds,
      const Radius.circular(9),
    );
    final Color tint = _tint(_blue);
    canvas.drawRRect(
      card.shift(const Offset(0, 4)),
      Paint()
        ..color = (_dark ? Colors.black : _blue).withValues(
          alpha: _dark ? 0.20 : 0.10,
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + 3 * lift),
    );
    canvas.drawRRect(
      card,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _surface(_blue, _dark ? 0.37 : 0.16),
            _surface(_blue, _dark ? 0.18 : 0.05),
          ],
        ).createShader(bounds),
    );
    canvas.drawRRect(
      card,
      Paint()
        ..color = tint.withValues(alpha: _dark ? 0.62 : 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    _roundRect(
      canvas,
      const Rect.fromLTWH(-33, -48, 19, 22),
      4,
      tint.withValues(alpha: _dark ? 0.46 : 0.20),
    );
    final Color mark = tint.withValues(alpha: _dark ? 0.80 : 0.50);
    canvas.drawCircle(const Offset(-23.5, -40), 3.1, Paint()..color = mark);
    _roundRect(canvas, const Rect.fromLTWH(-30, -34, 13, 5), 2.5, mark);
    _roundRect(canvas, const Rect.fromLTWH(-5, -45, 35, 3.5), 1.75, mark);
    _roundRect(
      canvas,
      const Rect.fromLTWH(-5, -34, 24, 3.5),
      1.75,
      mark.withValues(alpha: _dark ? 0.60 : 0.32),
    );
    _roundRect(
      canvas,
      const Rect.fromLTWH(-32, -15, 47, 3.5),
      1.75,
      mark.withValues(alpha: _dark ? 0.54 : 0.28),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrashBasketPainter oldDelegate) =>
      oldDelegate.scheme != scheme || oldDelegate.motion != motion;
}
