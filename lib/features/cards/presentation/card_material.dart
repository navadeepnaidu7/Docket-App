import 'package:flutter/material.dart';
import '../domain/card_surface.dart';
import 'bank_artwork.dart';

/// Static, resolution-independent engraving. No per-frame texture generation.
class CardMaterial extends CustomPainter {
  const CardMaterial(this.surface, {this.issuerId, this.variant = 0});
  final String? issuerId;
  final int variant;
  final CardSurfaceStyle surface;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Color base = surface.background;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, Colors.white, surface.light ? .08 : .16)!,
            base,
            Color.lerp(base, Colors.black, .12)!,
            Color.lerp(base, Colors.white, .06)!,
          ],
          stops: const [0, .35, .78, 1],
        ).createShader(bounds),
    );

    paintBankArtwork(canvas, size, surface, issuerId, variant);
    // Fine horizontal tooling is quiet enough to disappear at thumbnail scale.
    final Paint brushed = Paint()
      ..color = surface.ink.withValues(alpha: .018)
      ..strokeWidth = .45;
    for (double y = 1; y < size.height; y += 2.4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), brushed);
    }
    final RRect edge = RRect.fromRectAndRadius(
      bounds.deflate(.7),
      const Radius.circular(23.3),
    );
    canvas.drawRRect(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .7),
            Colors.white.withValues(alpha: .12),
            Colors.black.withValues(alpha: .3),
            Colors.white.withValues(alpha: .2),
          ],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(CardMaterial oldDelegate) =>
      oldDelegate.surface != surface ||
      oldDelegate.issuerId != issuerId ||
      oldDelegate.variant != variant;
}
