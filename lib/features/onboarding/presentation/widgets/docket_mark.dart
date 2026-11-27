import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../onboarding_palette.dart';

/// Geometry of the Docket door on the 1024 icon grid (see
/// tool/design_src/docket_icon/layers.html). Everything here is in grid
/// units; [DocketMarkPainter] scales it to the box it is given.
abstract final class DocketMarkGeometry {
  /// Door bounds on the grid: x 262-786, y 232-792.
  static const Rect door = Rect.fromLTRB(262, 232, 786, 792);

  /// Centre of the lock, which sits right of the door's middle.
  static const Offset lock = Offset(624, 512);

  static const double wellRadius = 72;
  static const double cylinderRadius = 58;
  static const double haloRadius = 112;

  /// Door width over height, for sizing a box around it.
  static const double aspect = 524 / 560;

  /// The door outline in grid units.
  static Path doorPath() {
    return Path()
      ..moveTo(262, 300)
      ..cubicTo(262, 262, 292, 232, 330, 232)
      ..lineTo(500, 232)
      ..cubicTo(680, 232, 786, 340, 786, 512)
      ..cubicTo(786, 684, 680, 792, 500, 792)
      ..lineTo(330, 792)
      ..cubicTo(292, 792, 262, 762, 262, 724)
      ..close();
  }

  /// The door outline mapped into a box of [size] whose width spans the door.
  static Path doorPathIn(Size size) {
    final double s = size.width / door.width;
    final Matrix4 m = Matrix4.identity()
      ..scaleByDouble(s, s, 1, 1)
      ..translateByDouble(-door.left, -door.top, 0, 1);
    return doorPath().transform(m.storage);
  }

  /// Lock centre inside a box of [size] whose width spans the door.
  static Offset lockIn(Size size) {
    final double s = size.width / door.width;
    return Offset((lock.dx - door.left) * s, (lock.dy - door.top) * s);
  }
}

/// The porcelain door and amber lock from the app icon, drawn live so each
/// part can move on its own.
///
/// [slotAngle] turns the key slot (0 is upright, the locked pose).
/// [lockScale] grows the lock from nothing. [doorOpacity] fades the porcelain
/// while the door turns into a window during the welcome transition.
class DocketMark extends StatelessWidget {
  const DocketMark({
    super.key,
    required this.width,
    this.slotAngle = 0,
    this.lockScale = 1,
    this.doorOpacity = 1,
    this.lockOpacity = 1,
    this.shadow = 1,
  });

  final double width;
  final double slotAngle;
  final double lockScale;
  final double doorOpacity;
  final double lockOpacity;
  final double shadow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width / DocketMarkGeometry.aspect,
      child: CustomPaint(
        painter: DocketMarkPainter(
          slotAngle: slotAngle,
          lockScale: lockScale,
          doorOpacity: doorOpacity,
          lockOpacity: lockOpacity,
          shadow: shadow,
        ),
      ),
    );
  }
}

class DocketMarkPainter extends CustomPainter {
  DocketMarkPainter({
    this.slotAngle = 0,
    this.lockScale = 1,
    this.doorOpacity = 1,
    this.lockOpacity = 1,
    this.shadow = 1,
  });

  final double slotAngle;
  final double lockScale;
  final double doorOpacity;
  final double lockOpacity;
  final double shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / DocketMarkGeometry.door.width;
    canvas.save();
    canvas.scale(s);
    canvas.translate(
      -DocketMarkGeometry.door.left,
      -DocketMarkGeometry.door.top,
    );
    // Blur radii are authored in grid units, so they scale with the mark.
    _paintDoor(canvas);
    _paintLock(canvas);
    canvas.restore();
  }

  void _paintDoor(Canvas canvas) {
    if (doorOpacity <= 0) return;
    final Path door = DocketMarkGeometry.doorPath();
    const Rect r = DocketMarkGeometry.door;

    if (shadow > 0) {
      final double a = shadow * doorOpacity;
      canvas.drawPath(
        door.shift(const Offset(0, 32)),
        Paint()
          ..color = OnboardingPalette.skyShade.withValues(alpha: 0.38 * a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
      );
      canvas.drawPath(
        door.shift(const Offset(0, 6)),
        Paint()
          ..color = OnboardingPalette.skyShade.withValues(alpha: 0.22 * a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    canvas.drawPath(
      door,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.84),
          radius: 1.3,
          colors: <Color>[
            OnboardingPalette.porcelain.withValues(alpha: doorOpacity),
            OnboardingPalette.porcelainMid.withValues(alpha: doorOpacity),
            OnboardingPalette.porcelainLo.withValues(alpha: doorOpacity),
          ],
          stops: const <double>[0, 0.52, 1],
        ).createShader(r),
    );

    // Lit rim: brighter at the top and bottom edges, like the icon.
    canvas.save();
    canvas.clipPath(door);
    canvas.drawPath(
      door,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withValues(alpha: doorOpacity),
            Colors.white.withValues(alpha: 0.35 * doorOpacity),
            Colors.white.withValues(alpha: doorOpacity),
          ],
          stops: const <double>[0, 0.55, 1],
        ).createShader(r),
    );
    canvas.restore();
  }

  void _paintLock(Canvas canvas) {
    if (lockScale <= 0 || lockOpacity <= 0) return;
    const Offset c = DocketMarkGeometry.lock;
    final double o = lockOpacity.clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(lockScale);

    // Warm halo the lock throws onto the porcelain.
    canvas.drawCircle(
      Offset.zero,
      DocketMarkGeometry.haloRadius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            OnboardingPalette.sun.withValues(alpha: 0.16 * o),
            OnboardingPalette.sun.withValues(alpha: 0),
          ],
          stops: const <double>[0.3, 1],
        ).createShader(
          Rect.fromCircle(
            center: Offset.zero,
            radius: DocketMarkGeometry.haloRadius,
          ),
        ),
    );

    // Recessed well.
    const Rect well = Rect.fromLTRB(-72, -74, 72, 70);
    canvas.drawOval(
      well,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            OnboardingPalette.wellTop.withValues(alpha: o),
            OnboardingPalette.porcelain.withValues(alpha: o),
          ],
        ).createShader(well),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(well));
    canvas.drawCircle(
      const Offset(0, -64),
      40,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.10 * o)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.restore();

    // Cylinder, with the shadow it casts into the well.
    canvas.drawCircle(
      const Offset(0, 8),
      DocketMarkGeometry.cylinderRadius,
      Paint()
        ..color = OnboardingPalette.sunLo.withValues(alpha: 0.45 * o)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    const Rect cyl = Rect.fromLTRB(-58, -56, 58, 60);
    canvas.drawOval(
      cyl,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.16, -0.28),
          radius: 0.72,
          colors: <Color>[
            OnboardingPalette.sunHi.withValues(alpha: o),
            OnboardingPalette.sun.withValues(alpha: o),
            OnboardingPalette.sunLo.withValues(alpha: o),
          ],
          stops: const <double>[0, 0.45, 1],
        ).createShader(cyl),
    );

    // Specular arc across the upper left.
    canvas.drawArc(
      const Rect.fromLTRB(-46, -44, 46, 48),
      math.pi + 0.18,
      1.62,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.75 * o),
    );

    // Key slot.
    canvas.translate(0, 3);
    canvas.rotate(slotAngle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-8, -25, 8, 25),
        const Radius.circular(8),
      ),
      Paint()..color = OnboardingPalette.slot.withValues(alpha: 0.62 * o),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(DocketMarkPainter old) =>
      old.slotAngle != slotAngle ||
      old.lockScale != lockScale ||
      old.doorOpacity != doorOpacity ||
      old.lockOpacity != lockOpacity ||
      old.shadow != shadow;
}
