import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/storage/image_payload.dart';

String formatIdDate(String d) {
  if (d.contains('-')) {
    final p = d.split('-');
    if (p.length == 3) return '${p[2]}/${p[1]}/${p[0]}';
  }
  return d;
}

/// Kept as the ID-side name for [isBase64ImagePayload], which now lives in
/// core so the passport card can share the same rule.
bool isBase64IdImage(String s) => isBase64ImagePayload(s);

// ── Full-screen image viewer ──────────────────────────────────────────────────

class IdCardFullImageViewer extends StatelessWidget {
  const IdCardFullImageViewer({super.key, required this.base64Image});
  final String base64Image;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.memory(
                    base64Decode(base64Image),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared emblem widget ───────────────────────────────────────────────────────
// Uses pre-rasterized PNGs instead of the 437 KB SVG so there is zero
// parse cost. ColorFiltered applies the tint at GPU composition time.
enum IdCardEmblemSize { watermark, header, hologram }

class IdCardEmblemPng extends StatelessWidget {
  const IdCardEmblemPng({super.key, required this.size, required this.color});
  final IdCardEmblemSize size;
  final Color color;

  String get _asset {
    switch (size) {
      case IdCardEmblemSize.watermark: return AppAssets.passportEmblemWatermark;
      case IdCardEmblemSize.header:    return AppAssets.passportEmblemHeader;
      case IdCardEmblemSize.hologram:  return AppAssets.passportEmblemHologram;
    }
  }

  double get _height {
    switch (size) {
      case IdCardEmblemSize.watermark: return 120;
      case IdCardEmblemSize.header:    return 34;
      case IdCardEmblemSize.hologram:  return 28;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: Image.asset(_asset, height: _height, fit: BoxFit.contain),
    );
  }
}

// ── Aadhaar-specific painters ─────────────────────────────────────────────────

/// Draws soft organic green curves matching the official Aadhaar card motif.
/// Set [mirrored] to true for the back card (curves from top-left).
class AadhaarGreenCurvesPainter extends CustomPainter {
  const AadhaarGreenCurvesPainter({this.mirrored = false});
  final bool mirrored;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (mirrored) {
      _drawCurve(
        canvas,
        start: Offset(0, h * 0.25),
        cp1: Offset(w * 0.3, h * 0.08),
        cp2: Offset(w * 0.55, h * 0.18),
        end: Offset(w * 0.75, 0),
        color: const Color(0x1C718B3D),
        strokeWidth: 2.5,
      );
      _drawCurve(
        canvas,
        start: Offset(0, h * 0.40),
        cp1: Offset(w * 0.25, h * 0.15),
        cp2: Offset(w * 0.48, h * 0.25),
        end: Offset(w * 0.68, 0),
        color: const Color(0x14A4C264),
        strokeWidth: 2.0,
      );
      _drawCurve(
        canvas,
        start: Offset(0, h * 0.52),
        cp1: Offset(w * 0.18, h * 0.25),
        cp2: Offset(w * 0.38, h * 0.32),
        end: Offset(w * 0.58, 0),
        color: const Color(0x10C5D99A),
        strokeWidth: 3.0,
      );
      // Subtle fill for corner
      final fillPath = Path()
        ..moveTo(0, h * 0.15)
        ..cubicTo(w * 0.15, 0, w * 0.3, h * 0.05, w * 0.5, 0)
        ..lineTo(0, 0)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = const Color(0x08718B3D)
          ..style = PaintingStyle.fill,
      );
    } else {
      _drawCurve(
        canvas,
        start: Offset(w * 0.35, h),
        cp1: Offset(w * 0.55, h * 0.65),
        cp2: Offset(w * 0.75, h * 0.80),
        end: Offset(w, h * 0.45),
        color: const Color(0x1C718B3D),
        strokeWidth: 2.5,
      );
      _drawCurve(
        canvas,
        start: Offset(w * 0.45, h),
        cp1: Offset(w * 0.60, h * 0.72),
        cp2: Offset(w * 0.78, h * 0.85),
        end: Offset(w, h * 0.55),
        color: const Color(0x14A4C264),
        strokeWidth: 2.0,
      );
      _drawCurve(
        canvas,
        start: Offset(w * 0.52, h),
        cp1: Offset(w * 0.66, h * 0.78),
        cp2: Offset(w * 0.84, h * 0.90),
        end: Offset(w, h * 0.65),
        color: const Color(0x10C5D99A),
        strokeWidth: 3.0,
      );
      // Subtle fill for corner
      final fillPath = Path()
        ..moveTo(w * 0.6, h)
        ..cubicTo(w * 0.72, h * 0.82, w * 0.86, h * 0.88, w, h * 0.72)
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = const Color(0x08718B3D)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawCurve(
    Canvas canvas, {
    required Offset start,
    required Offset cp1,
    required Offset cp2,
    required Offset end,
    required Color color,
    required double strokeWidth,
  }) {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant AadhaarGreenCurvesPainter old) =>
      old.mirrored != mirrored;
}

class AadhaarOrangeCurvesPainter extends CustomPainter {
  const AadhaarOrangeCurvesPainter({this.mirrored = false});
  final bool mirrored;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (mirrored) {
      _drawCurve(
        canvas,
        start: Offset(0, h * 0.25),
        cp1: Offset(w * 0.3, h * 0.08),
        cp2: Offset(w * 0.55, h * 0.18),
        end: Offset(w * 0.75, 0),
        color: const Color(0x1CF5A623),
        strokeWidth: 2.5,
      );
      _drawCurve(
        canvas,
        start: Offset(0, h * 0.40),
        cp1: Offset(w * 0.25, h * 0.15),
        cp2: Offset(w * 0.48, h * 0.25),
        end: Offset(w * 0.68, 0),
        color: const Color(0x14FFAB40),
        strokeWidth: 2.0,
      );
      _drawCurve(
        canvas,
        start: Offset(0, h * 0.52),
        cp1: Offset(w * 0.18, h * 0.25),
        cp2: Offset(w * 0.38, h * 0.32),
        end: Offset(w * 0.58, 0),
        color: const Color(0x10FFD180),
        strokeWidth: 3.0,
      );
      // Subtle fill for corner
      final fillPath = Path()
        ..moveTo(0, h * 0.15)
        ..cubicTo(w * 0.15, 0, w * 0.3, h * 0.05, w * 0.5, 0)
        ..lineTo(0, 0)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = const Color(0x08F5A623)
          ..style = PaintingStyle.fill,
      );
    } else {
      _drawCurve(
        canvas,
        start: Offset(w * 0.35, h),
        cp1: Offset(w * 0.55, h * 0.65),
        cp2: Offset(w * 0.75, h * 0.80),
        end: Offset(w, h * 0.45),
        color: const Color(0x1CF5A623),
        strokeWidth: 2.5,
      );
      _drawCurve(
        canvas,
        start: Offset(w * 0.45, h),
        cp1: Offset(w * 0.60, h * 0.72),
        cp2: Offset(w * 0.78, h * 0.85),
        end: Offset(w, h * 0.55),
        color: const Color(0x14FFAB40),
        strokeWidth: 2.0,
      );
      _drawCurve(
        canvas,
        start: Offset(w * 0.52, h),
        cp1: Offset(w * 0.66, h * 0.78),
        cp2: Offset(w * 0.84, h * 0.90),
        end: Offset(w, h * 0.65),
        color: const Color(0x10FFD180),
        strokeWidth: 3.0,
      );
      // Subtle fill for corner
      final fillPath = Path()
        ..moveTo(w * 0.6, h)
        ..cubicTo(w * 0.72, h * 0.82, w * 0.86, h * 0.88, w, h * 0.72)
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = const Color(0x08F5A623)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawCurve(
    Canvas canvas, {
    required Offset start,
    required Offset cp1,
    required Offset cp2,
    required Offset end,
    required Color color,
    required double strokeWidth,
  }) {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant AadhaarOrangeCurvesPainter old) =>
      old.mirrored != mirrored;
}

class IdCardSlideGradient extends GradientTransform {
  const IdCardSlideGradient(this.dx);
  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}

void showIdCardFullImage(BuildContext context, String base64Image) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (ctx, a1, a2) => IdCardFullImageViewer(base64Image: base64Image),
      transitionsBuilder: (ctx, anim, a2, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 220),
    ),
  );
}
