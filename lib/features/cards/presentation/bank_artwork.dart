import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/card_surface.dart';

enum CardMotif {
  contours,
  rings,
  facets,
  ribbons,
  folds,
  flutes,
  rays,
  diagonals,
  arches,
  weave,
  fan,
}

class BankArtwork {
  const BankArtwork(this.motif, this.accent);
  final CardMotif motif;
  final Color accent;
}

/// Explicit art directions, independent of network and stored record order.
/// These are Docket compositions, not replicas of official card products.
const Map<String, BankArtwork> bankArtwork = {
  'hdfc': BankArtwork(CardMotif.contours, Color(0xFFE53B45)),
  'icici': BankArtwork(CardMotif.ribbons, Color(0xFFFFB45F)),
  'sbi': BankArtwork(CardMotif.rings, Color(0xFF5BD1F4)),
  'axis': BankArtwork(CardMotif.facets, Color(0xFFF18DA6)),
  'kotak': BankArtwork(CardMotif.ribbons, Color(0xFF598BCA)),
  'pnb': BankArtwork(CardMotif.rays, Color(0xFFDDB66C)),
  'bob': BankArtwork(CardMotif.arches, Color(0xFFFFC17B)),
  'canara': BankArtwork(CardMotif.folds, Color(0xFFFFCE45)),
  'ubi': BankArtwork(CardMotif.weave, Color(0xFFEC5366)),
  'idfc': BankArtwork(CardMotif.flutes, Color(0xFFD5A391)),
  'indus': BankArtwork(CardMotif.rays, Color(0xFFCEA476)),
  'yes': BankArtwork(CardMotif.fan, Color(0xFFEC5461)),
  'federal': BankArtwork(CardMotif.fan, Color(0xFFE3B951)),
  'rbl': BankArtwork(CardMotif.diagonals, Color(0xFFEC5566)),
  'hsbc': BankArtwork(CardMotif.facets, Color(0xFFE54654)),
  'standard': BankArtwork(CardMotif.ribbons, Color(0xFF77D79B)),
  'citi': BankArtwork(CardMotif.arches, Color(0xFFF36C77)),
  'chase': BankArtwork(CardMotif.facets, Color(0xFF58A6E0)),
  'boa': BankArtwork(CardMotif.weave, Color(0xFFEA626D)),
  'wells': BankArtwork(CardMotif.flutes, Color(0xFFE4BC69)),
  'barclays': BankArtwork(CardMotif.ribbons, Color(0xFF6CDAEC)),
  'deutsche': BankArtwork(CardMotif.diagonals, Color(0xFF85ADE7)),
  'dbs': BankArtwork(CardMotif.weave, Color(0xFFD5A88C)),
};

/// Art is painted statically. Fades reserve quiet areas for the header/footer.
void paintBankArtwork(
  Canvas canvas,
  Size size,
  CardSurfaceStyle surface,
  String? issuerId,
  int variant,
) {
  final art =
      bankArtwork[issuerId] ?? BankArtwork(CardMotif.ribbons, surface.ink);
  final bounds = Offset.zero & size;
  final shift = (variant % 3) * 7.0;
  final fill = Paint()
    ..color = surface.ink.withValues(alpha: surface.light ? .13 : .15);
  final accent = Paint()
    ..color = art.accent.withValues(alpha: surface.light ? .65 : .65);
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = surface.ink.withValues(alpha: surface.light ? .22 : .25);
  Path polygon(List<Offset> points) => Path()..addPolygon(points, true);

  canvas.saveLayer(bounds, Paint());
  canvas.translate(shift, 0);
  switch (art.motif) {
    case CardMotif.contours:
      for (int i = 0; i < 14; i++) {
        final x = 228 + i * 15.0;
        final path = Path()
          ..moveTo(x, -30)
          ..cubicTo(x + 85, 56, x - 38, 175, x + 80, 310);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = i == 5 ? 18 : 1.1
            ..color = i == 5
                ? art.accent.withValues(alpha: .4)
                : surface.ink.withValues(alpha: .19),
        );
      }
    case CardMotif.rings:
      for (int i = 0; i < 7; i++) {
        canvas.drawCircle(
          const Offset(392, 146),
          39 + i * 24.0,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = i == 3 ? 15 : 7
            ..color = i == 3
                ? art.accent.withValues(alpha: .65)
                : surface.ink.withValues(alpha: .13),
        );
        canvas.drawCircle(const Offset(392, 146), 48 + i * 24.0, line);
      }
    case CardMotif.facets:
      canvas.drawPath(
        polygon(const [
          Offset(365, -20),
          Offset(455, 10),
          Offset(276, 277),
          Offset(235, 244),
        ]),
        fill,
      );
      canvas.drawPath(
        polygon(const [
          Offset(438, -15),
          Offset(498, 108),
          Offset(344, 265),
          Offset(305, 226),
        ]),
        accent,
      );
      canvas.drawPath(
        polygon(const [Offset(456, 122), Offset(470, 277), Offset(279, 302)]),
        fill,
      );
      canvas.drawLine(const Offset(253, 268), const Offset(443, -18), line);
    case CardMotif.ribbons:
      for (int i = 0; i < 4; i++) {
        final x = 245 + i * 49.0;
        final path = Path()
          ..moveTo(x, -30)
          ..cubicTo(x - 90, 90, x + 65, 154, x - 2, 310);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = i == 2 ? 25 : 38
            ..color = i == 2
                ? art.accent.withValues(alpha: .58)
                : surface.ink.withValues(alpha: .1),
        );
        canvas.drawPath(path, line);
      }
    case CardMotif.folds:
      for (int i = 0; i < 3; i++) {
        final x = 224 + i * 57.0;
        final path = Path()
          ..moveTo(x, -25)
          ..cubicTo(x + 130, 65, x - 50, 185, x + 40, 305)
          ..lineTo(x + 75, 305)
          ..cubicTo(x - 10, 176, x + 171, 65, x + 40, -25)
          ..close();
        canvas.drawPath(path, i == 1 ? accent : fill);
        canvas.drawPath(
          Path()
            ..moveTo(x + 40, -25)
            ..cubicTo(x + 171, 65, x - 10, 176, x + 75, 305),
          line,
        );
      }
    case CardMotif.flutes:
      for (int i = 0; i < 10; i++) {
        final x = 215 + i * 25.0;
        final path = Path()
          ..moveTo(x, -20)
          ..cubicTo(x - 22, 80, x + 22, 196, x + 8, 300);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = i == 5 ? 14 : 8
            ..color = i == 5
                ? art.accent.withValues(alpha: .55)
                : surface.ink.withValues(alpha: .12),
        );
        canvas.drawPath(path, line);
      }
    case CardMotif.rays:
      const center = Offset(438, 235);
      for (int i = 0; i < 14; i++) {
        final angle = math.pi + i * math.pi / 26;
        final end = center + Offset(math.cos(angle), math.sin(angle)) * 330;
        canvas.drawLine(
          center,
          end,
          Paint()
            ..strokeWidth = i == 6 ? 20 : 5
            ..color = i == 6
                ? art.accent.withValues(alpha: .65)
                : surface.ink.withValues(alpha: .13),
        );
      }

    case CardMotif.diagonals:
      for (int i = 0; i < 16; i++) {
        final x = 160 + i * 20.0;
        canvas.drawLine(
          Offset(x, 300),
          Offset(x + 170, -25),
          Paint()
            ..strokeWidth = i == 7 ? 12 : 2
            ..color = i == 7
                ? art.accent.withValues(alpha: .6)
                : surface.ink.withValues(alpha: .16),
        );
      }
    case CardMotif.arches:
      for (int i = 0; i < 6; i++) {
        final rect = Rect.fromCenter(
          center: const Offset(383, 268),
          width: 130 + i * 66.0,
          height: 220 + i * 66.0,
        );
        canvas.drawArc(
          rect,
          math.pi,
          math.pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = i == 3 ? 12 : 6
            ..color = i == 3
                ? art.accent.withValues(alpha: .7)
                : surface.ink.withValues(alpha: .16),
        );
        canvas.drawArc(rect.inflate(7), math.pi, math.pi, false, line);
      }
    case CardMotif.weave:
      for (int i = 0; i < 6; i++) {
        final y = i * 41.0 - 20;
        final path = Path()
          ..moveTo(184, y)
          ..lineTo(300, y + 34)
          ..lineTo(462, y - 8);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = i == 3 ? 14 : 23
            ..color = i == 3
                ? art.accent.withValues(alpha: .7)
                : surface.ink.withValues(alpha: .13),
        );
        canvas.drawPath(path, line);
      }

    case CardMotif.fan:
      for (int i = 0; i < 10; i++) {
        final x = 170 + i * 27.0;
        final path = Path()
          ..moveTo(x, 300)
          ..quadraticBezierTo(175 + i * 18.0, 75, 480, 32 + i * 18.0);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = i == 4 ? 17 : 7
            ..color = i == 4
                ? art.accent.withValues(alpha: .6)
                : surface.ink.withValues(alpha: .13),
        );
      }
  }
  canvas.translate(-shift, 0);
  // Keep number text and both footer fields readable across every motif.
  canvas.drawRect(
    bounds,
    Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          Colors.transparent,
          Colors.white,
          Colors.white,
        ],
        stops: [0, .4, .68, 1],
      ).createShader(bounds),
  );
  canvas.drawRect(
    bounds,
    Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0, .3, .65, .88],
      ).createShader(bounds),
  );
  canvas.restore();
}
