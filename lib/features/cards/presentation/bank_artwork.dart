import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/card_surface.dart';

enum CardMotif { sweep, orbit, fold, arch, lens, cut }

class BankArtwork {
  const BankArtwork(this.motif, this.accent, {this.offset = 0, this.angle = 0});
  final CardMotif motif;
  final Color accent;
  final double offset;
  final double angle;
}

/// Original Docket compositions. Existing issuer palettes and accents are kept.
const Map<String, BankArtwork> bankArtwork = {
  'hdfc': BankArtwork(CardMotif.sweep, Color(0xFFE53B45)),
  'icici': BankArtwork(CardMotif.lens, Color(0xFFFFB45F), angle: -.12),
  'sbi': BankArtwork(CardMotif.orbit, Color(0xFF5BD1F4)),
  'axis': BankArtwork(CardMotif.fold, Color(0xFFF18DA6), offset: -12),
  'kotak': BankArtwork(CardMotif.arch, Color(0xFF598BCA), angle: .13),
  'pnb': BankArtwork(CardMotif.arch, Color(0xFFDDB66C), offset: 15),
  'bob': BankArtwork(CardMotif.lens, Color(0xFFFFC17B), offset: -12, angle: .3),
  'canara': BankArtwork(CardMotif.fold, Color(0xFFFFCE45), angle: -.1),
  'ubi': BankArtwork(CardMotif.cut, Color(0xFFEC5366), offset: -8),
  'idfc': BankArtwork(
    CardMotif.arch,
    Color(0xFFD5A391),
    offset: -12,
    angle: -.15,
  ),
  'indus': BankArtwork(CardMotif.lens, Color(0xFFCEA476), angle: .2),
  'yes': BankArtwork(CardMotif.cut, Color(0xFFEC5461), angle: -.15),
  'federal': BankArtwork(
    CardMotif.orbit,
    Color(0xFFE3B951),
    offset: 18,
    angle: .3,
  ),
  'rbl': BankArtwork(CardMotif.fold, Color(0xFFEC5566), offset: 16),
  'hsbc': BankArtwork(CardMotif.cut, Color(0xFFE54654), offset: 18),
  'standard': BankArtwork(CardMotif.sweep, Color(0xFF77D79B), angle: -.12),
  'citi': BankArtwork(
    CardMotif.orbit,
    Color(0xFFF36C77),
    offset: -6,
    angle: -.25,
  ),
  'chase': BankArtwork(CardMotif.fold, Color(0xFF58A6E0), angle: .15),
  'boa': BankArtwork(CardMotif.cut, Color(0xFFEA626D), angle: .12),
  'wells': BankArtwork(CardMotif.arch, Color(0xFFE4BC69), angle: .1),
  'barclays': BankArtwork(CardMotif.lens, Color(0xFF6CDAEC), offset: 8),
  'deutsche': BankArtwork(CardMotif.cut, Color(0xFF85ADE7), offset: -16),
  'dbs': BankArtwork(CardMotif.sweep, Color(0xFFD5A88C), offset: 10, angle: .1),
};

/// Static relief, painted on the face's 440 × 277 canvas. No blur passes,
/// external art assets, per-frame noise generation or animated decoration.
void paintBankArtwork(
  Canvas canvas,
  Size size,
  CardSurfaceStyle surface,
  String? issuerId,
  int variant,
) {
  final art =
      bankArtwork[issuerId] ?? BankArtwork(CardMotif.sweep, surface.ink);
  canvas.save();
  canvas.scale(size.width / 440, size.height / 277);
  canvas.clipRect(const Rect.fromLTWH(0, 0, 440, 277));
  canvas.translate(art.offset + variant % 3 * 5, 0);
  canvas.translate(380, 150);
  canvas.rotate(art.angle);
  canvas.translate(-380, -150);
  final relief = _Relief(canvas, surface, art.accent);
  switch (art.motif) {
    case CardMotif.sweep:
      final body = Path()
        ..moveTo(389, -45)
        ..cubicTo(479, 25, 235, 73, 272, 171)
        ..cubicTo(293, 229, 409, 234, 492, 226)
        ..lineTo(525, 300)
        ..cubicTo(506, 226, 346, 176, 373, 116)
        ..cubicTo(390, 74, 532, 30, 482, -45)
        ..close();
      relief.solid(body, const Rect.fromLTWH(265, 0, 220, 277));
      // A single inlaid seam follows the turn of the material.
      final seam = Path()
        ..moveTo(398, -32)
        ..cubicTo(466, 31, 254, 81, 286, 167)
        ..cubicTo(308, 222, 423, 222, 504, 214);
      relief.inlay(seam, 5);
      relief.edge(
        Path()
          ..moveTo(389, -45)
          ..cubicTo(479, 25, 235, 73, 272, 171)
          ..cubicTo(293, 229, 409, 234, 492, 226),
      );
    case CardMotif.orbit:
      final outer = Path()..addOval(const Rect.fromLTWH(273, 14, 302, 302));
      final inner = Path()..addOval(const Rect.fromLTWH(318, 59, 212, 212));
      final ring = Path.combine(PathOperation.difference, outer, inner);
      relief.solid(ring, const Rect.fromLTWH(273, 14, 302, 302));
      relief.edge(outer);
      relief.edge(inner, strength: .13);
      canvas.drawArc(
        const Rect.fromLTWH(290, 31, 268, 268),
        math.pi * .83,
        math.pi * .61,
        false,
        relief.accentStroke(4),
      );
      // An inset disk gives the opening depth, without a bullseye of rings.
      canvas.drawOval(
        const Rect.fromLTWH(333, 74, 182, 182),
        Paint()..color = surface.ink.withValues(alpha: .025),
      );
    case CardMotif.fold:
      final back = Path()
        ..moveTo(384, -35)
        ..cubicTo(371, 48, 302, 125, 294, 211)
        ..quadraticBezierTo(287, 245, 323, 264)
        ..lineTo(500, 310)
        ..lineTo(524, 63)
        ..close();
      relief.solid(back, const Rect.fromLTWH(271, 0, 240, 277), reverse: true);
      final front = Path()
        ..moveTo(376, -35)
        ..cubicTo(376, 50, 284, 125, 281, 208)
        ..quadraticBezierTo(280, 225, 306, 230)
        ..lineTo(346, 238)
        ..quadraticBezierTo(324, 225, 326, 211)
        ..cubicTo(334, 136, 423, 80, 424, 5)
        ..close();
      relief.solid(front, const Rect.fromLTWH(271, 0, 154, 277));
      final join = Path()
        ..moveTo(414, 1)
        ..cubicTo(414, 80, 324, 136, 316, 211)
        ..quadraticBezierTo(314, 225, 336, 235)
        ..lineTo(346, 238)
        ..quadraticBezierTo(324, 225, 326, 211)
        ..cubicTo(334, 136, 423, 80, 424, 5)
        ..close();
      relief.accentFill(join, .48);
      relief.edge(
        Path()
          ..moveTo(376, -35)
          ..cubicTo(376, 50, 284, 125, 281, 208)
          ..quadraticBezierTo(280, 225, 306, 230),
      );
    case CardMotif.arch:
      final outer = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(270, 68, 282, 354),
            const Radius.circular(141),
          ),
        );
      final inner = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(310, 108, 202, 340),
            const Radius.circular(101),
          ),
        );
      final arch = Path.combine(PathOperation.difference, outer, inner);
      relief.solid(arch, const Rect.fromLTWH(270, 68, 282, 280));
      relief.edge(outer);
      relief.edge(inner, strength: .12);
      final seam = Path()
        ..moveTo(292, 320)
        ..lineTo(292, 209)
        ..cubicTo(292, 52, 530, 52, 530, 209);
      relief.inlay(seam, 3);
    case CardMotif.lens:
      canvas.save();
      canvas.translate(402, 154);
      canvas.rotate(-.45);
      canvas.translate(-402, -154);
      final lens = Path()
        ..moveTo(258, 154)
        ..cubicTo(323, 53, 479, 44, 554, 154)
        ..cubicTo(487, 249, 329, 253, 258, 154)
        ..close();
      relief.solid(lens, const Rect.fromLTWH(258, 68, 296, 175));
      relief.edge(lens);
      canvas.save();
      canvas.clipPath(lens);
      // Fine intaglio is contained inside one form, not spread across the face.
      for (int i = 0; i < 7; i++) {
        canvas.drawPath(
          Path()
            ..moveTo(255, 174 + i * 9)
            ..quadraticBezierTo(405, 89 + i * 12, 559, 181 + i * 9),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .6
            ..color = surface.ink.withValues(alpha: .11),
        );
      }
      canvas.restore();
      relief.inlay(
        Path()
          ..moveTo(258, 154)
          ..cubicTo(323, 53, 479, 44, 554, 154),
        3,
      );
      canvas.restore();
    case CardMotif.cut:
      final upper = Path()
        ..moveTo(249, 118)
        ..lineTo(454, -51)
        ..lineTo(532, 47)
        ..lineTo(327, 216)
        ..close();
      final lower = Path()
        ..moveTo(308, 211)
        ..lineTo(513, 42)
        ..lineTo(547, 137)
        ..lineTo(374, 280)
        ..close();
      relief.solid(upper, const Rect.fromLTWH(249, 0, 245, 220));
      relief.solid(
        lower,
        const Rect.fromLTWH(308, 42, 239, 238),
        reverse: true,
      );
      relief.accentFill(
        Path()
          ..moveTo(308, 211)
          ..lineTo(513, 42)
          ..lineTo(518, 55)
          ..lineTo(320, 220)
          ..close(),
        .48,
      );
      relief.edge(
        Path()
          ..moveTo(249, 118)
          ..lineTo(454, -51),
      );
  }
  canvas.restore();
}

/// Shared lighting keeps the six silhouettes part of one material collection.
class _Relief {
  const _Relief(this.canvas, this.surface, this.accent);
  final Canvas canvas;
  final CardSurfaceStyle surface;
  final Color accent;

  void solid(Path path, Rect bounds, {bool reverse = false}) {
    canvas.drawPath(
      path.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: surface.light ? .07 : .14),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: reverse ? Alignment.bottomLeft : Alignment.topLeft,
          end: reverse ? Alignment.topRight : Alignment.bottomRight,
          colors: [
            Color.lerp(
              surface.background,
              Colors.white,
              surface.light ? .55 : .26,
            )!,
            Color.lerp(
              surface.background,
              Colors.white,
              surface.light ? .04 : .09,
            )!,
            Color.lerp(
              surface.background,
              Colors.black,
              surface.light ? .09 : .17,
            )!,
            Color.lerp(
              surface.background,
              Colors.white,
              surface.light ? .18 : .16,
            )!,
          ],
          stops: const [0, .32, .65, 1],
        ).createShader(bounds),
    );
  }

  void edge(Path path, {double strength = .28}) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = surface.ink.withValues(alpha: strength),
    );
  }

  Paint accentStroke(double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..color = accent.withValues(alpha: surface.light ? .6 : .58);

  void inlay(Path path, double width) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 2
        ..color = Colors.black.withValues(alpha: .12),
    );
    canvas.drawPath(path, accentStroke(width));
  }

  void accentFill(Path path, double strength) {
    canvas.drawPath(path, Paint()..color = accent.withValues(alpha: strength));
  }
}
