import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/bounce_tap.dart';

enum AttachmentAddTileVariant { hero, strip }

/// Dashed rounded placeholder tile for adding new attachments.
///
/// Supports two visual layouts:
/// - [AttachmentAddTileVariant.hero]: Large dashed card with "+" and "add image/pdf" caption.
/// - [AttachmentAddTileVariant.strip]: Small dashed 54x56 thumbnail tile with a centered "+".
class AttachmentAddTile extends StatelessWidget {
  const AttachmentAddTile({
    super.key,
    required this.onTap,
    this.variant = AttachmentAddTileVariant.hero,
    this.height,
  });

  final VoidCallback onTap;
  final AttachmentAddTileVariant variant;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accentColor = AppTheme.accentOf(brightness);
    final isHero = variant == AttachmentAddTileVariant.hero;
    final borderRadius = isHero ? AppTheme.radiusCard : AppTheme.radiusControl;

    final tileChild = CustomPaint(
      painter: DashedRRectPainter(
        color: accentColor,
        borderRadius: borderRadius,
        strokeWidth: 1.5,
        dashLength: 6.0,
        gapLength: 5.0,
      ),
      child: Container(
        width: isHero ? double.infinity : 56.0,
        height: isHero ? (height ?? 216.0) : 54.0,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: isHero
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: 36,
                    color: accentColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'add image/pdf',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.ink(brightness).withValues(alpha: 0.60),
                    ),
                  ),
                ],
              )
            : Center(
                child: Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: accentColor,
                ),
              ),
      ),
    );

    return BounceTap(
      onTap: onTap,
      child: tileChild,
    );
  }
}

/// CustomPainter for drawing a dashed rounded rectangle outline.
class DashedRRectPainter extends CustomPainter {
  const DashedRRectPainter({
    required this.color,
    required this.borderRadius,
    this.strokeWidth = 1.5,
    this.dashLength = 6.0,
    this.gapLength = 5.0,
  });

  final Color color;
  final double borderRadius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final dashPath = Path();

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double len = (distance + dashLength < metric.length)
            ? dashLength
            : metric.length - distance;
        dashPath.addPath(
          metric.extractPath(distance, distance + len),
          Offset.zero,
        );
        distance += dashLength + gapLength;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength;
  }
}
