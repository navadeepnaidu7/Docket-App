import 'dart:math' as math;
import 'package:flutter/material.dart';

class DotGlobeWidget extends StatefulWidget {
  const DotGlobeWidget({
    super.key,
    this.size = 200.0,
    this.isDark = true,
  });

  final double size;
  final bool isDark;

  @override
  State<DotGlobeWidget> createState() => _DotGlobeWidgetState();
}

class _DotGlobeWidgetState extends State<DotGlobeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  double _manualAngleX = 0.25; // Tilt angle
  double _manualAngleY = 0.0;  // Longitude angle
  Offset? _lastPanOffset;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _lastPanOffset = details.localPosition;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_lastPanOffset == null) return;
    final Offset delta = details.localPosition - _lastPanOffset!;
    _lastPanOffset = details.localPosition;

    setState(() {
      _manualAngleY += delta.dx * 0.008;
      _manualAngleX = (_manualAngleX - delta.dy * 0.008).clamp(-0.8, 0.8);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      child: AnimatedBuilder(
        animation: _rotationController,
        builder: (BuildContext context, Widget? child) {
          final double autoAngleY = _rotationController.value * math.pi * 2;
          final double totalAngleY = autoAngleY + _manualAngleY;

          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: DotGlobePainter(
              angleY: totalAngleY,
              angleX: _manualAngleX,
              isDark: widget.isDark,
            ),
          );
        },
      ),
    );
  }
}

class DotGlobePainter extends CustomPainter {
  DotGlobePainter({
    required this.angleY,
    required this.angleX,
    required this.isDark,
  });

  final double angleY;
  final double angleX;
  final bool isDark;

  static final List<_SpherePoint> _points = _generateSpherePoints(1200);

  static List<_SpherePoint> _generateSpherePoints(int count) {
    final List<_SpherePoint> list = <_SpherePoint>[];
    final double phi = (1 + math.sqrt(5)) / 2; // Golden ratio

    for (int i = 0; i < count; i++) {
      final double y = 1 - (i / (count - 1)) * 2; // y from 1 to -1
      final double radiusAtY = math.sqrt(1 - y * y);
      final double theta = 2 * math.pi * i / phi;

      final double x = math.cos(theta) * radiusAtY;
      final double z = math.sin(theta) * radiusAtY;

      // Density pattern to emulate continents / dot map density
      final double noise = math.sin(x * 4.5) * math.cos(y * 4.5) * math.sin(z * 4.5);
      final bool isLand = noise > -0.15;

      list.add(_SpherePoint(x: x, y: y, z: z, isLand: isLand));
    }
    return list;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = math.min(size.width, size.height) * 0.44;
    final Offset center = Offset(size.width / 2, size.height / 2);

    final Color dotColor = isDark
        ? const Color(0xFFF2F2F7)
        : const Color(0xFF1C1C1E);
    final Color rimColor = isDark
        ? const Color(0xFF5E5CE6).withValues(alpha: 0.18)
        : const Color(0xFF2F6FED).withValues(alpha: 0.12);

    // Draw sphere background shadow & subtle rim
    final Paint sphereBg = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          isDark ? const Color(0xFF1C1C1E) : const Color(0xFFD1D1D6),
          isDark ? const Color(0xFF0F0F12) : const Color(0xFFB0B0B5),
        ],
        stops: const <double>[0.0, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sphereBg);

    final Paint rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = rimColor;
    canvas.drawCircle(center, radius, rimPaint);

    final double cosY = math.cos(angleY);
    final double sinY = math.sin(angleY);
    final double cosX = math.cos(angleX);
    final double sinX = math.sin(angleX);

    for (final _SpherePoint pt in _points) {
      if (!pt.isLand) continue;

      // Rotate around Y-axis (longitude)
      final double x1 = pt.x * cosY - pt.z * sinY;
      final double z1 = pt.x * sinY + pt.z * cosY;

      // Rotate around X-axis (latitude tilt)
      final double y2 = pt.y * cosX - z1 * sinX;
      final double z2 = pt.y * sinX + z1 * cosX;

      // Only draw dots on front facing hemisphere
      if (z2 <= -0.05) continue;

      final double px = center.dx + x1 * radius;
      final double py = center.dy + y2 * radius;

      // Depth lighting calculation
      final double zNorm = (z2 + 1.0) / 2.0; // 0..1
      final double dotRadius = (0.7 + zNorm * 1.3).clamp(0.5, 2.2);
      final double opacity = (0.25 + zNorm * 0.75).clamp(0.1, 1.0);

      final Paint p = Paint()
        ..color = dotColor.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(px, py), dotRadius, p);
    }
  }

  @override
  bool shouldRepaint(covariant DotGlobePainter oldDelegate) {
    return oldDelegate.angleY != angleY ||
        oldDelegate.angleX != angleX ||
        oldDelegate.isDark != isDark;
  }
}

class _SpherePoint {
  const _SpherePoint({
    required this.x,
    required this.y,
    required this.z,
    required this.isLand,
  });

  final double x;
  final double y;
  final double z;
  final bool isLand;
}
