import 'package:flutter/material.dart';

/// Flat side-profile airliner facing the direction of travel (right), drawn
/// tone on tone as the flight face's watermark — the bus coach's counterpart.
///
/// Authored on a 120 x 50 grid and scaled to the paint size.
class FlightAircraftPainter extends CustomPainter {
  const FlightAircraftPainter({required this.body, required this.shade});

  /// Fuselage and fin.
  final Color body;

  /// Windows, wing, engine.
  final Color shade;

  static const double gridWidth = 120;
  static const double gridHeight = 50;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / gridWidth, size.height / gridHeight);
    final Paint bodyPaint = Paint()..color = body;
    final Paint shadePaint = Paint()..color = shade;

    // Fin first, so the fuselage overlaps its root.
    final Path fin = Path()
      ..moveTo(9, 25)
      ..lineTo(3, 6)
      ..cubicTo(3, 5, 4, 4, 5, 4)
      ..lineTo(9, 4)
      ..cubicTo(10, 4, 11, 5, 12, 6)
      ..lineTo(28, 23)
      ..close();
    canvas.drawPath(fin, bodyPaint);

    final Path fuselage = Path()
      ..moveTo(16, 22)
      ..lineTo(100, 22)
      ..cubicTo(110, 22, 118, 26, 118, 30)
      ..cubicTo(118, 33, 113, 36, 104, 36)
      ..lineTo(24, 36)
      ..cubicTo(16, 36, 9, 32, 5, 27)
      ..cubicTo(4, 25, 6, 22, 16, 22)
      ..close();
    canvas.drawPath(fuselage, bodyPaint);

    // Tailplane, a sliver across the rear fuselage.
    final Path tailplane = Path()
      ..moveTo(6, 27)
      ..lineTo(22, 27)
      ..lineTo(12, 30.5)
      ..lineTo(7, 30.5)
      ..close();
    canvas.drawPath(tailplane, shadePaint);

    // Cabin windows and the cockpit.
    for (double x = 28; x <= 92; x += 5) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 25.5, 2.4, 3),
          const Radius.circular(1.2),
        ),
        shadePaint,
      );
    }
    final Path cockpit = Path()
      ..moveTo(104, 25)
      ..lineTo(110, 25)
      ..lineTo(114, 28.5)
      ..lineTo(104, 28.5)
      ..close();
    canvas.drawPath(cockpit, shadePaint);

    // Wing, swept back below the fuselage, with its engine.
    final Path wing = Path()
      ..moveTo(50, 33)
      ..lineTo(74, 33)
      ..lineTo(60, 47)
      ..cubicTo(59, 48, 58, 48, 57, 48)
      ..lineTo(53, 48)
      ..close();
    canvas.drawPath(wing, shadePaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(60, 37, 17, 6.5),
        const Radius.circular(3.25),
      ),
      shadePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FlightAircraftPainter old) =>
      old.body != body || old.shade != shade;
}

/// A top-view airliner pointing right, on a 12 x 12 box: the glyph that
/// rides the flight path on the face and the progress bar on Updates.
Path flightGlyphPath() {
  return Path()
    ..moveTo(12, 6)
    ..cubicTo(12, 6.8, 11.2, 7, 10.4, 7)
    ..lineTo(7.4, 7)
    ..lineTo(4.4, 11.6)
    ..lineTo(3.2, 11.6)
    ..lineTo(4.8, 7)
    ..lineTo(2.2, 7)
    ..lineTo(1.2, 8.6)
    ..lineTo(0.3, 8.6)
    ..lineTo(0.9, 6)
    ..lineTo(0.3, 3.4)
    ..lineTo(1.2, 3.4)
    ..lineTo(2.2, 5)
    ..lineTo(4.8, 5)
    ..lineTo(3.2, 0.4)
    ..lineTo(4.4, 0.4)
    ..lineTo(7.4, 5)
    ..lineTo(10.4, 5)
    ..cubicTo(11.2, 5, 12, 5.2, 12, 6)
    ..close();
}
