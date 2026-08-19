import 'package:flutter/material.dart';

/// The small code square printed on a pass face.
///
/// Decorative, not scannable. The pattern is the fixed 7x7 grid from the train
/// design export and encodes nothing; the real boarding code lives behind
/// [onTap] on a detail screen, which is why a glance card leaves this inert
/// rather than inviting a scan that would fail at a gate.
///
/// Shared by the train and bus faces. Every dimension is a ratio of [size], so
/// the two stay identical at whatever scale their canvas gives them — the
/// alternative was a second copy of the pattern and its painter drifting
/// against the first.
class PassCodeBlock extends StatelessWidget {
  const PassCodeBlock({
    super.key,
    required this.size,
    required this.ink,
    required this.borderColor,
    this.onTap,
  });

  /// Side of the square. The export drew it at 69.
  final double size;

  /// Colour of the modules.
  final Color ink;

  final Color borderColor;

  /// Non-null makes the block tappable — detail screens only.
  final VoidCallback? onTap;

  /// Ratios taken from the export's 69dp block: 7.5 inset, 8 pitch, 6 cell,
  /// 11.5 corner radius.
  static const double _insetRatio = 7.5 / 69;
  static const double _pitchRatio = 8 / 69;
  static const double _cellRatio = 6 / 69;
  static const double _radiusRatio = 11.5 / 69;

  static const int modules = 7;

  @override
  Widget build(BuildContext context) {
    final Widget block = SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(size * _radiusRatio),
              border: Border.all(color: borderColor),
            ),
          ),
          CustomPaint(
            painter: _PassCodePainter(
              color: ink,
              inset: size * _insetRatio,
              pitch: size * _pitchRatio,
              cell: size * _cellRatio,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return block;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: block,
    );
  }
}

class _PassCodePainter extends CustomPainter {
  const _PassCodePainter({
    required this.color,
    required this.inset,
    required this.pitch,
    required this.cell,
  });

  final Color color;
  final double inset;
  final double pitch;
  final double cell;

  /// Verbatim from the export's 7x7 rect grid.
  static const List<List<int>> _pattern = <List<int>>[
    <int>[1, 1, 1, 0, 1, 1, 1],
    <int>[1, 0, 1, 1, 0, 0, 1],
    <int>[1, 1, 1, 0, 1, 1, 1],
    <int>[0, 0, 0, 1, 0, 1, 0],
    <int>[1, 1, 0, 0, 1, 0, 1],
    <int>[1, 0, 1, 1, 0, 1, 1],
    <int>[1, 1, 1, 0, 1, 0, 1],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    for (int r = 0; r < PassCodeBlock.modules; r++) {
      for (int c = 0; c < PassCodeBlock.modules; c++) {
        if (_pattern[r][c] == 0) continue;
        canvas.drawRect(
          Rect.fromLTWH(inset + c * pitch, inset + r * pitch, cell, cell),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PassCodePainter old) =>
      old.color != color ||
      old.inset != inset ||
      old.pitch != pitch ||
      old.cell != cell;
}

/// A dashed rule. Used for the tear line and route connectors on pass faces.
class PassDashedRule extends StatelessWidget {
  const PassDashedRule({
    super.key,
    required this.color,
    this.strokeWidth = 1.5,
    this.dash = 6,
    this.gap = 4,
    this.vertical = false,
  });

  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;

  /// Runs top-to-bottom instead of left-to-right.
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: PassDashedRulePainter(
        color: color,
        strokeWidth: strokeWidth,
        dash: dash,
        gap: gap,
        vertical: vertical,
      ),
    );
  }
}

class PassDashedRulePainter extends CustomPainter {
  const PassDashedRulePainter({
    required this.color,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
    this.vertical = false,
  });

  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;
  final bool vertical;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final double extent = vertical ? size.height : size.width;
    final double cross = (vertical ? size.width : size.height) / 2;

    double pos = 0;
    while (pos < extent) {
      final double end = (pos + dash).clamp(0, extent);
      canvas.drawLine(
        vertical ? Offset(cross, pos) : Offset(pos, cross),
        vertical ? Offset(cross, end) : Offset(end, cross),
        paint,
      );
      pos += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant PassDashedRulePainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap ||
      old.vertical != vertical;
}
