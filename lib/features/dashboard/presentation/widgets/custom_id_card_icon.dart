import 'package:flutter/material.dart';

class CustomIdCardIcon extends StatelessWidget {
  const CustomIdCardIcon({
    super.key,
    required this.color,
    required this.width,
    required this.height,
    required this.selected,
  });
  
  final Color color;
  final double width;
  final double height;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: CustomIdCardPainter(color: color, selected: selected),
      ),
    );
  }
}

class CustomIdCardPainter extends CustomPainter {
  CustomIdCardPainter({required this.color, required this.selected});
  final Color color;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Draw card background matching the given size
    final double cardW = w;
    final double cardH = h;
    final double cardX = 0;
    final double cardY = 0;

    final RRect cardRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardX, cardY, cardW, cardH),
      Radius.circular(cardH * 0.20),
    );

    final double avatarRadius = cardH * 0.28;
    final double avatarCenterX = cardX + cardW * 0.28;
    final double avatarCenterY = cardY + cardH * 0.44;

    final double headRadius = avatarRadius * 0.38;
    final double headCenterX = avatarCenterX;
    final double headCenterY = avatarCenterY - avatarRadius * 0.2;

    final double shoulderRadius = avatarRadius * 0.75;
    final double shoulderCenterX = avatarCenterX;
    final double shoulderCenterY = avatarCenterY + avatarRadius * 1.05;

    final double lineThickness = cardH * 0.09;
    final double lineRadius = lineThickness / 2;

    if (selected) {
      // ─── SELECTED STATE (FILLED CARD WITH CUTOUTS) ───
      // Use saveLayer to allow BlendMode.clear cutouts
      canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint());

      final Paint cardPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      
      canvas.drawRRect(cardRRect, cardPaint);

      // Setup clear paint for cutouts
      final Paint clearPaint = Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.fill;

      // Cutout the avatar circle on the left
      canvas.drawCircle(Offset(avatarCenterX, avatarCenterY), avatarRadius, clearPaint);

      // Draw avatar silhouette inside the cutout circle (using original color)
      canvas.drawCircle(Offset(headCenterX, headCenterY), headRadius, cardPaint);

      // Shoulders: bottom circle cutout
      canvas.drawCircle(Offset(shoulderCenterX, shoulderCenterY), shoulderRadius, cardPaint);

      // Cutout lines
      // Line 1: top right short
      final RRect line1 = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          cardX + cardW * 0.54,
          cardY + cardH * 0.26,
          cardW * 0.34,
          lineThickness,
        ),
        Radius.circular(lineRadius),
      );
      canvas.drawRRect(line1, clearPaint);

      // Line 2: middle right short
      final RRect line2 = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          cardX + cardW * 0.54,
          cardY + cardH * 0.52,
          cardW * 0.34,
          lineThickness,
        ),
        Radius.circular(lineRadius),
      );
      canvas.drawRRect(line2, clearPaint);

      // Line 3: bottom long line
      final RRect line3 = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          cardX + cardW * 0.12,
          cardY + cardH * 0.78,
          cardW * 0.76,
          lineThickness,
        ),
        Radius.circular(lineRadius),
      );
      canvas.drawRRect(line3, clearPaint);

      canvas.restore();
    } else {
      // ─── UNSELECTED STATE (OUTLINE CARD & SOLID INNER DETAILS) ───
      final double strokeW = cardH * 0.085; // Proportional stroke width
      
      final Paint outlinePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round;

      final Paint fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      // Draw outer card outline
      canvas.drawRRect(cardRRect, outlinePaint);

      // Draw avatar circle outline
      canvas.drawCircle(Offset(avatarCenterX, avatarCenterY), avatarRadius, outlinePaint);

      // Draw avatar head (solid)
      canvas.drawCircle(Offset(headCenterX, headCenterY), headRadius, fillPaint);

      // Draw avatar shoulders (solid, clipped inside avatar circle inner boundary)
      canvas.save();
      final Path avatarClipPath = Path()
        ..addOval(Rect.fromCircle(
          center: Offset(avatarCenterX, avatarCenterY), 
          radius: avatarRadius - strokeW / 2,
        ));
      canvas.clipPath(avatarClipPath);
      canvas.drawCircle(Offset(shoulderCenterX, shoulderCenterY), shoulderRadius, fillPaint);
      canvas.restore();

      // Draw three text lines as solid rounded capsules
      final Paint linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineThickness
        ..strokeCap = StrokeCap.round;

      // Line 1: top right
      canvas.drawLine(
        Offset(cardX + cardW * 0.54 + lineThickness / 2, cardY + cardH * 0.26 + lineThickness / 2),
        Offset(cardX + cardW * 0.54 + cardW * 0.34 - lineThickness / 2, cardY + cardH * 0.26 + lineThickness / 2),
        linePaint,
      );

      // Line 2: middle right
      canvas.drawLine(
        Offset(cardX + cardW * 0.54 + lineThickness / 2, cardY + cardH * 0.52 + lineThickness / 2),
        Offset(cardX + cardW * 0.54 + cardW * 0.34 - lineThickness / 2, cardY + cardH * 0.52 + lineThickness / 2),
        linePaint,
      );

      // Line 3: bottom long line
      canvas.drawLine(
        Offset(cardX + cardW * 0.12 + lineThickness / 2, cardY + cardH * 0.78 + lineThickness / 2),
        Offset(cardX + cardW * 0.12 + cardW * 0.76 - lineThickness / 2, cardY + cardH * 0.78 + lineThickness / 2),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomIdCardPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.selected != selected;
}
