import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// A small piece of folded satin. Geometry and light are drawn directly;
/// it carries no controls or information and never competes with scrolling.
class MembershipRibbon extends StatefulWidget {
  const MembershipRibbon({super.key});

  @override
  State<MembershipRibbon> createState() => _MembershipRibbonState();
}

class _MembershipRibbonState extends State<MembershipRibbon>
    with TickerProviderStateMixin {
  late final _light = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );
  late final _x = AnimationController.unbounded(vsync: this);
  late final _y = AnimationController.unbounded(vsync: this);
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _light.stop();
      _x.stop();
      _y.stop();
      _x.value = _y.value = 0;
    } else if (!_light.isAnimating) {
      _light.repeat();
    }
  }

  void _release() {
    if (_reduced) return;
    const spring = SpringDescription(mass: 1, stiffness: 150, damping: 24);
    _x.animateWith(SpringSimulation(spring, _x.value, 0, _x.velocity));
    _y.animateWith(SpringSimulation(spring, _y.value, 0, _y.velocity));
  }

  @override
  void dispose() {
    _light.dispose();
    _x.dispose();
    _y.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    void follow(PointerEvent e) {
      if (_reduced) return;
      final size = (context.findRenderObject()! as RenderBox).size;
      _x.value = (e.localPosition.dx / size.width - 0.5).clamp(-0.5, 0.5);
      _y.value = (e.localPosition.dy / size.height - 0.5).clamp(-0.5, 0.5);
    }

    return RepaintBoundary(
      child: ExcludeSemantics(
        child: Listener(
          onPointerDown: follow,
          onPointerMove: follow,
          onPointerUp: (_) => _release(),
          onPointerCancel: (_) => _release(),
          child: AnimatedBuilder(
            animation: Listenable.merge([_light, _x, _y]),
            builder: (context, _) => CustomPaint(
              painter: _SatinRibbonPainter(
                phase: _light.value * math.pi * 2,
                tiltX: _x.value,
                tiltY: _y.value,
                dark: dark,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _SatinRibbonPainter extends CustomPainter {
  const _SatinRibbonPainter({
    required this.phase,
    required this.tiltX,
    required this.tiltY,
    required this.dark,
  });

  final double phase;
  final double tiltX;
  final double tiltY;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width * 0.32, size.height * 0.62);
    final center = Offset(size.width * 0.5, size.height * 0.46);
    final lift = math.sin(phase) * 2;
    final yaw = -0.32 + math.sin(phase) * 0.055 + tiltX * 0.24;
    final pitch = 0.83 + math.cos(phase) * 0.035 + tiltY * 0.16;

    // A contact shadow grounds the form without adding a visible panel.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + scale * 0.76),
        width: scale * 1.75,
        height: scale * 0.11,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: dark ? 0.24 : 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );

    (Offset, double) project(double t, double v) {
      final radius = 1 + v * math.cos(t / 2);
      final x = radius * math.cos(t);
      final y = radius * math.sin(t);
      final z = v * math.sin(t / 2);
      final a = x * math.cos(yaw) + z * math.sin(yaw);
      final b = z * math.cos(yaw) - x * math.sin(yaw);
      final py = y * math.cos(pitch) - b * math.sin(pitch);
      final depth = y * math.sin(pitch) + b * math.cos(pitch);
      // A slight diagonal keeps the form relaxed rather than emblem-like.
      const roll = -0.19;
      return (
        center +
            Offset(
              (a * math.cos(roll) - py * math.sin(roll)) * scale,
              (a * math.sin(roll) + py * math.cos(roll)) * scale + lift,
            ),
        depth,
      );
    }

    const colors = [
      Color(0xFFCFBCEB),
      Color(0xFFB4D5DD),
      Color(0xFFD0DDAF),
      Color(0xFFF0C9AD),
      Color(0xFFDAB7D1),
      Color(0xFFCFBCEB),
    ];
    const segments = 128;
    const bands = 10;
    final positions = <double>[];
    final vertexColors = <int>[];
    final depths = <double>[];
    for (var i = 0; i <= segments; i++) {
      final t = i / segments * math.pi * 2;
      final colorPos = i / segments * (colors.length - 1);
      final base = Color.lerp(
        colors[colorPos.floor()],
        colors[colorPos.ceil()],
        colorPos % 1,
      )!;
      for (var j = 0; j <= bands; j++) {
        final v = (j / bands - 0.5) * 0.54;
        final point = project(t, v);
        positions.addAll([point.$1.dx, point.$1.dy]);
        depths.add(point.$2);
        final sheen = math.pow(math.cos(v / 0.27 * math.pi / 2), 6).toDouble();
        final shade = 0.12 + 0.18 * (math.sin(t * 2 + 0.6) * 0.5 + 0.5);
        final body = Color.lerp(base, const Color(0xFF6E6380), shade)!;
        final lit = Color.lerp(
          body,
          Colors.white,
          sheen * (0.38 + 0.06 * math.sin(phase)),
        )!;
        vertexColors.add(lit.toARGB32());
      }
    }
    final faces = <({List<int> corners, double depth})>[];
    for (var i = 0; i < segments; i++) {
      for (var j = 0; j < bands; j++) {
        final a = i * (bands + 1) + j;
        final b = a + 1;
        final c = a + bands + 2;
        final d = a + bands + 1;
        faces.add((
          corners: [a, b, c, d],
          depth: (depths[a] + depths[b] + depths[c] + depths[d]) / 4,
        ));
      }
    }
    faces.sort((a, b) => a.depth.compareTo(b.depth));
    final indices = <int>[];
    for (final face in faces) {
      final q = face.corners;
      indices.addAll([q[0], q[1], q[2], q[0], q[2], q[3]]);
    }
    final mesh = ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.fromList(positions),
      colors: Int32List.fromList(vertexColors),
      indices: Uint16List.fromList(indices),
    );
    canvas.drawVertices(mesh, BlendMode.srcOver, Paint());
    mesh.dispose();
  }

  @override
  bool shouldRepaint(_SatinRibbonPainter old) =>
      phase != old.phase ||
      tiltX != old.tiltX ||
      tiltY != old.tiltY ||
      dark != old.dark;
}
