import 'package:flutter/material.dart';

class CustomIdCardIcon extends StatelessWidget {
  const CustomIdCardIcon({
    super.key,
    required this.color,
    required this.width,
    required this.height,
  });
  
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: CustomIdCardPainter(color: color),
      ),
    );
  }
}

class CustomIdCardPainter extends CustomPainter {
  CustomIdCardPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Draw card background (filled rounded rect) matching the given size
    final double cardW = w;
    final double cardH = h;
    final double cardX = 0;
    final double cardY = 0;

    // Use saveLayer to allow BlendMode.clear cutouts
    canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint());

    final Paint cardPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final RRect cardRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardX, cardY, cardW, cardH),
      Radius.circular(cardH * 0.20),
    );
    canvas.drawRRect(cardRRect, cardPaint);

    // 2. Setup clear paint for cutouts
    final Paint clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.fill;

    // 3. Cutout the avatar circle on the left
    final double avatarRadius = cardH * 0.28;
    final double avatarCenterX = cardX + cardW * 0.28;
    final double avatarCenterY = cardY + cardH * 0.44;
    canvas.drawCircle(Offset(avatarCenterX, avatarCenterY), avatarRadius, clearPaint);

    // 4. Draw avatar silhouette inside the cutout circle (using original color)
    // Head: circle
    final double headRadius = avatarRadius * 0.38;
    final double headCenterX = avatarCenterX;
    final double headCenterY = avatarCenterY - avatarRadius * 0.2;
    canvas.drawCircle(Offset(headCenterX, headCenterY), headRadius, cardPaint);

    // Shoulders: bottom circle cutout
    final double shoulderRadius = avatarRadius * 0.75;
    final double shoulderCenterX = avatarCenterX;
    final double shoulderCenterY = avatarCenterY + avatarRadius * 1.05;
    canvas.drawCircle(Offset(shoulderCenterX, shoulderCenterY), shoulderRadius, cardPaint);

    // 5. Cutout lines
    final double lineThickness = cardH * 0.09;
    final double lineRadius = lineThickness / 2;

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
  }

  @override
  bool shouldRepaint(covariant CustomIdCardPainter oldDelegate) =>
      oldDelegate.color != color;
}
