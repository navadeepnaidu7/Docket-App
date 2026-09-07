import 'package:flutter/material.dart';

import '../domain/pass_code.dart';

/// Lightweight code-availability indicator, deliberately not a scannable QR.
/// No payload encoding or image decoding happens on the animated pass face.
/// [onTap] opens the real code at scanning size in details. Callers omit this
/// widget when there is no code.
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

  /// The available code. Its payload is never rendered here.
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
            // Never decode images or encode a dense payload on a moving card.
            // The labelled scan icon is an affordance, not a fake QR symbol.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.document_scanner_outlined,
                  size: size * 0.38,
                  color: const Color(0xFF6B5A5E),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    onTap == null ? 'Code' : 'View code',
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      color: Color(0xFF6B5A5E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label: onTap == null
          ? 'Ticket code available in details'
          : 'View ticket code',
      button: onTap != null,
      child: onTap == null
          ? block
          : TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                fixedSize: Size.square(size),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onTap,
              child: block,
            ),
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
