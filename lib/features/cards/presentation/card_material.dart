import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/card_surface.dart';
import 'bank_artwork.dart';

/// Diffuse light within satin. This layer alone repaints on the ambient clock.
class CardMaterial extends CustomPainter {
  CardMaterial(
    this.surface, {
    this.issuerId,
    this.variant = 0,
    this.time = kAlwaysDismissedAnimation,
    this.entrance = kAlwaysDismissedAnimation,
    this.horizontal = kAlwaysDismissedAnimation,
    this.vertical = kAlwaysDismissedAnimation,
    this.contact = kAlwaysDismissedAnimation,
  }) : super(
         repaint: Listenable.merge([
           time,
           entrance,
           horizontal,
           vertical,
           contact,
         ]),
       );

  final CardSurfaceStyle surface;
  final String? issuerId;
  final int variant;
  final Animation<double> time;
  final Animation<double> entrance;
  final Animation<double> horizontal;
  final Animation<double> vertical;
  final Animation<double> contact;

  // Study palettes. Other banks inherit their saved base and familiar accent.
  (Color, Color, Color) get _lights => switch (issuerId) {
    'canara' => (
      const Color(0xFF3484AA),
      const Color(0xFFD5B35C),
      const Color(0xFF39B9BA),
    ),
    'hdfc' => (
      const Color(0xFF3D63AC),
      const Color(0xFFB95779),
      const Color(0xFF548FB6),
    ),
    'sbi' => (
      const Color(0xFF2C78D9),
      const Color(0xFF3BCFDC),
      const Color(0xFF2B329B),
    ),
    _ => (
      Color.lerp(surface.background, Colors.white, .28)!,
      bankArtwork[issuerId]?.accent ?? const Color(0xFFB0BBC8),
      Color.lerp(
        surface.background,
        bankArtwork[issuerId]?.accent ?? Colors.white,
        .35,
      )!,
    ),
  };

  static final ui.Vertices _grain = _makeGrain();

  static ui.Vertices _makeGrain() {
    final random = math.Random(41);
    final points = <Offset>[];
    for (var i = 0; i < 1100; i++) {
      final x = random.nextDouble() * 440;
      final y = random.nextDouble() * 277;
      points.addAll([Offset(x, y), Offset(x + .55, y), Offset(x, y + .55)]);
    }
    return ui.Vertices(ui.VertexMode.triangles, points);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final base = surface.background;
    final (a, b, c) = _lights;
    final seconds = time.value * 720;
    final amount = entrance.value;
    double wave(double period, [double phase = 0]) =>
        math.sin(seconds / period * math.pi * 2 + phase) * amount;

    canvas.drawRect(bounds, Paint()..color = base);
    void light(
      Color color,
      Offset center,
      double radius,
      double opacity, {
      double flatten = .8,
      double angle = 0,
    }) {
      canvas.save();
      canvas.clipRect(bounds);
      canvas.translate(center.dx * size.width, center.dy * size.height);
      canvas.rotate(angle);
      canvas.scale(radius * size.width, radius * size.height * flatten);
      canvas.drawPaint(
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            1,
            [
              color.withValues(alpha: opacity),
              color.withValues(alpha: opacity * .48),
              color.withValues(alpha: 0),
            ],
            const [0, .42, 1],
          ),
      );
      canvas.restore();
    }

    // Broad overlapping pools, without hard outlines or recognizable motifs.
    final pearl = surface.light;
    light(
      a,
      Offset(.27 + wave(20) * .19, .28 + wave(20, 1.2) * .19),
      .96,
      pearl ? .13 : .92,
    );
    light(
      b,
      Offset(.86 + wave(16, .8) * .20, .59 + wave(16, 2.1) * .24),
      .85,
      pearl ? .17 : .66,
      flatten: .46,
      angle: -.42 + wave(16) * .14,
    );
    light(
      c,
      Offset(.52 + wave(24, 2) * .26, 1.05 + wave(24, .6) * .22),
      .92,
      pearl ? .10 : .46,
      flatten: .42,
      angle: .32 + wave(24) * .18,
    );
    light(
      Colors.white,
      Offset(.32 + wave(18, .7) * .25, .35 + wave(18, 2.2) * .22),
      1.02,
      pearl ? .25 : .105,
      flatten: .35,
      angle: -.4 + wave(18) * .14,
    );
    final touch = contact.value.clamp(0.0, 1.0);
    if (touch > .001) {
      light(
        pearl ? Colors.white : const Color(0xFFF9EED9),
        Offset(.5 + horizontal.value * .48, .5 + vertical.value * .48),
        .92,
        touch * (pearl ? .26 : .25),
      );
    }

    // Shading follows the light to protect the stationary header and footer.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: pearl
              ? const [
                  Color(0x75FFFFFF),
                  Color(0x18FFFFFF),
                  Color(0x00FFFFFF),
                  Color(0x00FFFFFF),
                  Color(0x20FFFFFF),
                  Color(0x50FFFFFF),
                ]
              : const [
                  Color(0x99001124),
                  Color(0x24001124),
                  Color(0x00001124),
                  Color(0x00001326),
                  Color(0x40001326),
                  Color(0x77001326),
                ],
          stops: const [0, .30, .45, .55, .75, 1],
        ).createShader(bounds),
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(pearl ? 0x14FFFFFF : 0x24001020),
            const Color(0x00001020),
          ],
          stops: const [0, .7],
        ).createShader(bounds),
    );

    // Grain is generated once. No blur or saveLayer pass is needed.
    canvas.save();
    canvas.scale(size.width / 440, size.height / 277);
    canvas.drawVertices(
      _grain,
      BlendMode.srcOver,
      Paint()..color = surface.ink.withValues(alpha: .045),
    );
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.deflate(.6), const Radius.circular(23.4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: pearl ? .8 : .35),
            Colors.white.withValues(alpha: .08),
            Colors.black.withValues(alpha: .16),
            Colors.white.withValues(alpha: .17),
          ],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(CardMaterial oldDelegate) =>
      oldDelegate.surface != surface ||
      oldDelegate.issuerId != issuerId ||
      oldDelegate.variant != variant ||
      oldDelegate.time != time ||
      oldDelegate.entrance != entrance ||
      oldDelegate.horizontal != horizontal ||
      oldDelegate.vertical != vertical ||
      oldDelegate.contact != contact;
}
