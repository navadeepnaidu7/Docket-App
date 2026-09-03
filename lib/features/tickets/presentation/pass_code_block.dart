import 'package:flutter/material.dart';

import '../domain/pass_code.dart';
import 'pass_code_view.dart';

/// The small code square printed on a pass face.
///
/// Draws the pass's **real** code, scaled into the square the train design
/// export drew. It used to paint a fixed 7x7 grid that encoded nothing, on the
/// theory that a glance card only needs to look like a ticket. That is exactly
/// the trap: a user cannot tell decorative code art from the real thing, and
/// finds out at a turnstile. A pass with no code omits this widget entirely —
/// see `docs/features/ticket-code-extraction.md`.
///
/// [onTap] opens the full-screen view, where the code is big enough to scan
/// from; at this size it is identification, not a scanning target.
///
/// Used by the train face. Every dimension is a ratio of [size], so it stays
/// proportional at whatever scale its canvas gives it. Kept as a shared widget
/// rather than folded back into the train file because the code square and the
/// dashed rule are pass chrome, not train chrome — the bus face happens not to
/// use them, since its brand header carries the identity instead.
class PassCodeBlock extends StatelessWidget {
  const PassCodeBlock({
    super.key,
    required this.size,
    required this.code,
    required this.borderColor,
    this.onTap,
  });

  /// Side of the square. The export drew it at 69.
  final double size;

  /// The code to draw. Callers omit the whole widget when the pass has none.
  final PassCode code;

  final Color borderColor;

  /// Non-null makes the block tappable — detail screens only.
  final VoidCallback? onTap;

  /// Ratios taken from the export's 69dp block: 7.5 inset, 11.5 corner radius.
  static const double _insetRatio = 7.5 / 69;
  static const double _radiusRatio = 11.5 / 69;

  @override
  Widget build(BuildContext context) {
    final double inset = size * _insetRatio;
    final Widget block = SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * _radiusRatio),
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: EdgeInsets.all(inset),
          child: Center(
            child: PassCodeView(code: code, width: size - inset * 2),
          ),
        ),
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
