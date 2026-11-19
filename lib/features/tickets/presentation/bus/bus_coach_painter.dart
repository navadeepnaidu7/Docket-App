import 'package:flutter/material.dart';

/// Flat side-profile coach, facing the direction of travel (right), drawn
/// tone on tone as the bus face's watermark.
///
/// Authored on a 120 x 50 grid and scaled to the paint size. A painter rather
/// than an SVG asset because every colour comes from the pass palette, and the
/// tyres need a ring in the surface colour to read as separate from the body.
class BusCoachPainter extends CustomPainter {
  const BusCoachPainter({
    required this.body,
    required this.shade,
    required this.surface,
  });

  /// Body and hubs.
  final Color body;

  /// Windows, door and tyres.
  final Color shade;

  /// The card surface, for the gap ring around each tyre.
  final Color surface;

  static const double gridWidth = 120;
  static const double gridHeight = 50;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / gridWidth, size.height / gridHeight);

    final Path hull = Path()
      ..moveTo(7, 3)
      ..lineTo(98, 3)
      ..cubicTo(106, 3, 110, 7, 112, 13)
      ..lineTo(117, 29)
      ..cubicTo(118, 33, 118, 35, 118, 37)
      ..lineTo(118, 40)
      ..cubicTo(118, 42, 117, 43, 115, 43)
      ..lineTo(4, 43)
      ..cubicTo(2, 43, 1, 42, 1, 40)
      ..lineTo(1, 9)
      ..cubicTo(1, 5, 3, 3, 7, 3)
      ..close();
    canvas.drawPath(hull, Paint()..color = body);

    final Paint shadePaint = Paint()..color = shade;
    final Path windows = Path()
      ..addRect(const Rect.fromLTWH(7, 9, 16, 14))
      ..addRect(const Rect.fromLTWH(27, 9, 18, 14))
      ..addRect(const Rect.fromLTWH(49, 9, 18, 14))
      ..addRect(const Rect.fromLTWH(71, 9, 18, 14))
      ..moveTo(93, 9)
      ..lineTo(102, 9)
      ..cubicTo(105, 9, 106, 10, 107, 12)
      ..lineTo(110.5, 23)
      ..lineTo(93, 23)
      ..close();
    canvas.drawPath(windows, shadePaint);
    canvas.drawRect(
      const Rect.fromLTWH(93, 26, 7, 13),
      Paint()..color = shade.withValues(alpha: shade.a * 0.55),
    );

    final Paint ring = Paint()
      ..color = surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final Paint hub = Paint()..color = body;
    for (final Offset c in const <Offset>[Offset(25, 43), Offset(96, 43)]) {
      // The ring is painted opaque in the surface colour, so it has to go
      // down before the translucent tyre, or the tyre would show it through.
      canvas.drawCircle(c, 7, ring);
      canvas.drawCircle(c, 7 - 1.5, shadePaint);
      canvas.drawCircle(c, 2.5, hub);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BusCoachPainter old) =>
      old.body != body || old.shade != shade || old.surface != surface;
}
