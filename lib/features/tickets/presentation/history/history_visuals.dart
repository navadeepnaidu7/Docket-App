import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../domain/movie_pass_models.dart';
import '../../domain/pass_catalog.dart';
import '../../domain/pass_history_category.dart';
import '../../domain/ticket_models.dart';
import '../movie/movie_brand_style.dart';

/// Brand-aware colors + mark for a history strip or folder face.
@immutable
class HistoryStripLook {
  const HistoryStripLook({
    required this.gradient,
    required this.shadow,
    this.logoAsset,
    this.logoTint,
    this.glyph,
  });

  final List<Color> gradient;
  final Color shadow;
  final String? logoAsset;
  final Color? logoTint;

  /// Fallback monogram when no brand asset is available.
  final HistoryGlyphKind? glyph;

  /// Per-pass look: movies keep BMS / District / universal chrome even when expired.
  static HistoryStripLook forItem(WalletPassItem item) {
    return switch (item) {
      TrainPassItem(:final ticket) => forTrain(ticket),
      MoviePassItem(:final pass) => forMovie(pass),
    };
  }

  static HistoryStripLook forTrain(TrainPass ticket) {
    // IRCTC-forward rail palette (mint + deep pine), not generic navy.
    const Color deep = Color(0xFF0B3D2E);
    const Color mid = Color(0xFF127A4F);
    const Color mint = Color(0xFF1FBF75);
    final String op = ticket.operator.toLowerCase();
    if (op.contains('irctc') || op.contains('indian')) {
      return const HistoryStripLook(
        gradient: <Color>[mint, mid, deep],
        shadow: mint,
        glyph: HistoryGlyphKind.train,
      );
    }
    return const HistoryStripLook(
      gradient: <Color>[Color(0xFF1A4B7A), Color(0xFF0E2F4F)],
      shadow: Color(0xFF1A4B7A),
      glyph: HistoryGlyphKind.train,
    );
  }

  static HistoryStripLook forMovie(MoviePass pass) {
    // Force brand chrome on archived rows so they stay recognizable.
    final MovieBrandStyle style =
        MovieBrandStyle.forPass(pass, useBrandColors: true);
    return HistoryStripLook(
      gradient: style.bodyGradient,
      shadow: style.glow,
      logoAsset: style.logoAsset ?? style.footerLogoAsset,
      logoTint: style.logoTint ?? Colors.white,
      glyph: HistoryGlyphKind.movie,
    );
  }

  static HistoryStripLook forCategory(PassHistoryCategory category) {
    return switch (category) {
      PassHistoryCategory.train => const HistoryStripLook(
          gradient: <Color>[Color(0xFF1FBF75), Color(0xFF0B3D2E)],
          shadow: Color(0xFF1FBF75),
          glyph: HistoryGlyphKind.train,
        ),
      PassHistoryCategory.movie => const HistoryStripLook(
          gradient: <Color>[Color(0xFFE22636), Color(0xFF6B42F6)],
          shadow: Color(0xFFE22636),
          glyph: HistoryGlyphKind.movie,
        ),
      PassHistoryCategory.flight => const HistoryStripLook(
          gradient: <Color>[Color(0xFF38BDF8), Color(0xFF0E4C81)],
          shadow: Color(0xFF38BDF8),
          glyph: HistoryGlyphKind.flight,
        ),
      PassHistoryCategory.event => const HistoryStripLook(
          gradient: <Color>[Color(0xFFF59E0B), Color(0xFF9A3412)],
          shadow: Color(0xFFF59E0B),
          glyph: HistoryGlyphKind.event,
        ),
      PassHistoryCategory.bus => const HistoryStripLook(
          gradient: <Color>[Color(0xFF2DD4BF), Color(0xFF115E59)],
          shadow: Color(0xFF2DD4BF),
          glyph: HistoryGlyphKind.bus,
        ),
      PassHistoryCategory.other => const HistoryStripLook(
          gradient: <Color>[Color(0xFF818CF8), Color(0xFF3730A3)],
          shadow: Color(0xFF818CF8),
          glyph: HistoryGlyphKind.other,
        ),
    };
  }
}

enum HistoryGlyphKind { train, movie, flight, event, bus, other }

/// Brand logo or a custom-drawn glyph (never stock Material icons).
class HistoryBrandMark extends StatelessWidget {
  const HistoryBrandMark({
    super.key,
    required this.look,
    this.size = 22,
  });

  final HistoryStripLook look;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String? asset = look.logoAsset;
    if (asset != null) {
      return SvgPicture.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: look.logoTint == null
            ? null
            : ColorFilter.mode(look.logoTint!, BlendMode.srcIn),
      );
    }
    return CustomPaint(
      size: Size.square(size),
      painter: _HistoryGlyphPainter(
        kind: look.glyph ?? HistoryGlyphKind.other,
        color: Colors.white.withValues(alpha: 0.95),
      ),
    );
  }
}

/// Category folder glyph — bespoke line marks, not Material icons.
class HistoryCategoryMark extends StatelessWidget {
  const HistoryCategoryMark({
    super.key,
    required this.category,
    this.size = 16,
    this.color = Colors.white,
  });

  final PassHistoryCategory category;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Movies folder uses a soft dual-brand cue (BMS mark) when space allows.
    if (category == PassHistoryCategory.movie) {
      return SvgPicture.asset(
        AppAssets.bookMyShowLogo,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return CustomPaint(
      size: Size.square(size),
      painter: _HistoryGlyphPainter(
        kind: switch (category) {
          PassHistoryCategory.train => HistoryGlyphKind.train,
          PassHistoryCategory.movie => HistoryGlyphKind.movie,
          PassHistoryCategory.flight => HistoryGlyphKind.flight,
          PassHistoryCategory.event => HistoryGlyphKind.event,
          PassHistoryCategory.bus => HistoryGlyphKind.bus,
          PassHistoryCategory.other => HistoryGlyphKind.other,
        },
        color: color,
      ),
    );
  }
}

class _HistoryGlyphPainter extends CustomPainter {
  _HistoryGlyphPainter({required this.kind, required this.color});

  final HistoryGlyphKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, size.shortestSide * 0.09)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double s = size.shortestSide;
    final Offset o = Offset((size.width - s) / 2, (size.height - s) / 2);

    switch (kind) {
      case HistoryGlyphKind.train:
        _paintTrain(canvas, o, s, stroke, fill);
      case HistoryGlyphKind.movie:
        _paintTicket(canvas, o, s, stroke);
      case HistoryGlyphKind.flight:
        _paintFlight(canvas, o, s, stroke, fill);
      case HistoryGlyphKind.event:
        _paintEvent(canvas, o, s, stroke);
      case HistoryGlyphKind.bus:
        _paintBus(canvas, o, s, stroke, fill);
      case HistoryGlyphKind.other:
        _paintFolder(canvas, o, s, stroke);
    }
  }

  void _paintTrain(
    Canvas canvas,
    Offset o,
    double s,
    Paint stroke,
    Paint fill,
  ) {
    final RRect body = RRect.fromRectAndRadius(
      Rect.fromLTWH(o.dx + s * 0.12, o.dy + s * 0.28, s * 0.76, s * 0.42),
      Radius.circular(s * 0.12),
    );
    canvas.drawRRect(body, stroke);
    // Cab window
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(o.dx + s * 0.52, o.dy + s * 0.36, s * 0.24, s * 0.16),
        Radius.circular(s * 0.04),
      ),
      stroke,
    );
    // Nose
    final Path nose = Path()
      ..moveTo(o.dx + s * 0.12, o.dy + s * 0.40)
      ..lineTo(o.dx + s * 0.02, o.dy + s * 0.50)
      ..lineTo(o.dx + s * 0.12, o.dy + s * 0.60);
    canvas.drawPath(nose, stroke);
    // Wheels
    canvas.drawCircle(Offset(o.dx + s * 0.30, o.dy + s * 0.78), s * 0.08, fill);
    canvas.drawCircle(Offset(o.dx + s * 0.58, o.dy + s * 0.78), s * 0.08, fill);
    // Stack
    canvas.drawLine(
      Offset(o.dx + s * 0.28, o.dy + s * 0.28),
      Offset(o.dx + s * 0.28, o.dy + s * 0.14),
      stroke,
    );
  }

  void _paintTicket(Canvas canvas, Offset o, double s, Paint stroke) {
    final RRect ticket = RRect.fromRectAndRadius(
      Rect.fromLTWH(o.dx + s * 0.14, o.dy + s * 0.18, s * 0.72, s * 0.64),
      Radius.circular(s * 0.08),
    );
    canvas.drawRRect(ticket, stroke);
    final Paint perf = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.1, s * 0.07)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(o.dx + s * 0.40, o.dy + s * 0.22),
      Offset(o.dx + s * 0.40, o.dy + s * 0.78),
      perf,
    );
    final Paint fill = Paint()..color = color;
    canvas.drawCircle(Offset(o.dx + s * 0.40, o.dy + s * 0.34), s * 0.035, fill);
    canvas.drawCircle(Offset(o.dx + s * 0.40, o.dy + s * 0.50), s * 0.035, fill);
    canvas.drawCircle(Offset(o.dx + s * 0.40, o.dy + s * 0.66), s * 0.035, fill);
  }

  void _paintFlight(
    Canvas canvas,
    Offset o,
    double s,
    Paint stroke,
    Paint fill,
  ) {
    final Path p = Path()
      ..moveTo(o.dx + s * 0.50, o.dy + s * 0.10)
      ..lineTo(o.dx + s * 0.58, o.dy + s * 0.42)
      ..lineTo(o.dx + s * 0.90, o.dy + s * 0.50)
      ..lineTo(o.dx + s * 0.58, o.dy + s * 0.54)
      ..lineTo(o.dx + s * 0.50, o.dy + s * 0.90)
      ..lineTo(o.dx + s * 0.42, o.dy + s * 0.54)
      ..lineTo(o.dx + s * 0.10, o.dy + s * 0.50)
      ..lineTo(o.dx + s * 0.42, o.dy + s * 0.42)
      ..close();
    canvas.drawPath(p, fill);
  }

  void _paintEvent(Canvas canvas, Offset o, double s, Paint stroke) {
    final RRect body = RRect.fromRectAndRadius(
      Rect.fromLTWH(o.dx + s * 0.16, o.dy + s * 0.22, s * 0.68, s * 0.56),
      Radius.circular(s * 0.10),
    );
    canvas.drawRRect(body, stroke);
    canvas.drawLine(
      Offset(o.dx + s * 0.16, o.dy + s * 0.40),
      Offset(o.dx + s * 0.84, o.dy + s * 0.40),
      stroke,
    );
    canvas.drawLine(
      Offset(o.dx + s * 0.34, o.dy + s * 0.14),
      Offset(o.dx + s * 0.34, o.dy + s * 0.30),
      stroke,
    );
    canvas.drawLine(
      Offset(o.dx + s * 0.66, o.dy + s * 0.14),
      Offset(o.dx + s * 0.66, o.dy + s * 0.30),
      stroke,
    );
  }

  void _paintBus(
    Canvas canvas,
    Offset o,
    double s,
    Paint stroke,
    Paint fill,
  ) {
    final RRect body = RRect.fromRectAndRadius(
      Rect.fromLTWH(o.dx + s * 0.12, o.dy + s * 0.26, s * 0.76, s * 0.42),
      Radius.circular(s * 0.10),
    );
    canvas.drawRRect(body, stroke);
    canvas.drawLine(
      Offset(o.dx + s * 0.12, o.dy + s * 0.42),
      Offset(o.dx + s * 0.88, o.dy + s * 0.42),
      stroke,
    );
    canvas.drawCircle(Offset(o.dx + s * 0.30, o.dy + s * 0.78), s * 0.08, fill);
    canvas.drawCircle(Offset(o.dx + s * 0.70, o.dy + s * 0.78), s * 0.08, fill);
  }

  void _paintFolder(Canvas canvas, Offset o, double s, Paint stroke) {
    final Path p = Path()
      ..moveTo(o.dx + s * 0.12, o.dy + s * 0.34)
      ..lineTo(o.dx + s * 0.12, o.dy + s * 0.78)
      ..lineTo(o.dx + s * 0.88, o.dy + s * 0.78)
      ..lineTo(o.dx + s * 0.88, o.dy + s * 0.40)
      ..lineTo(o.dx + s * 0.48, o.dy + s * 0.40)
      ..lineTo(o.dx + s * 0.40, o.dy + s * 0.28)
      ..lineTo(o.dx + s * 0.12, o.dy + s * 0.28)
      ..close();
    canvas.drawPath(p, stroke);
  }

  @override
  bool shouldRepaint(covariant _HistoryGlyphPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
