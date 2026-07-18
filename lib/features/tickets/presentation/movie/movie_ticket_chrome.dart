import 'package:flutter/material.dart';

/// Shared ticket geometry: notches, tear line, barcode, decorative QR.
///
/// Footer height is defined in one place so [TicketShapeClipper] notches
/// stay aligned with the dashed tear without hand-recomputing pads.
abstract final class MovieTicketMetrics {
  MovieTicketMetrics._();

  /// Vertical scale for glance wallet face (product-tuned).
  static const double glanceTallScale = 1.35;

  /// Width factor vs pass stack (product-tuned).
  static const double glanceWidthFactor = 0.96;

  static const double cornerR = 24;
  static const double notchR = 10;

  static const double tearHeight = 20;
  static const double barcodeHeight = 40;
  static const double footerPadTop = 8;
  static const double footerPadBottom = 14;
  static const double footerIdGap = 6;
  static const double footerIdLine = 14;

  /// Full stub under the tear (barcode + id + pads).
  static double footerBodyHeight({required double scale}) =>
      footerPadTop * scale +
      barcodeHeight * scale +
      footerIdGap * scale +
      footerIdLine +
      footerPadBottom * scale;

  /// Tear row + stub — used for notch placement from the bottom.
  static double footerStackHeight({required double scale}) =>
      tearHeight * scale + footerBodyHeight(scale: scale);

  /// Distance from ticket bottom to notch center (middle of tear row).
  static double notchFromBottom({required double scale}) =>
      footerBodyHeight(scale: scale) + (tearHeight * scale) / 2;

  /// Detail + QR stub (booking id + compact barcode | QR tile).
  static const double detailQrTile = 72;
  static const double detailQrBarcode = 32;
  /// max(QR tile, id line + gap + barcode) — keep column ≤ this.
  static const double detailQrContentH = detailQrTile;
  static const double detailQrFooterBody =
      footerPadTop + detailQrContentH + footerPadBottom;

  static double notchFromBottomDetailQr() =>
      detailQrFooterBody + tearHeight / 2;
}

/// Rounded ticket with side semicircle cutouts (real clip, no painted fill).
class TicketShapeClipper extends CustomClipper<Path> {
  const TicketShapeClipper({
    this.cornerR = MovieTicketMetrics.cornerR,
    this.notchR = MovieTicketMetrics.notchR,
    required this.notchFromBottom,
  });

  final double cornerR;
  final double notchR;
  final double notchFromBottom;

  @override
  Path getClip(Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cy =
        (h - notchFromBottom).clamp(cornerR + notchR, h - cornerR - notchR);

    return Path()
      ..moveTo(cornerR, 0)
      ..lineTo(w - cornerR, 0)
      ..arcToPoint(Offset(w, cornerR), radius: Radius.circular(cornerR))
      ..lineTo(w, cy - notchR)
      ..arcToPoint(
        Offset(w, cy + notchR),
        radius: Radius.circular(notchR),
        clockwise: false,
      )
      ..lineTo(w, h - cornerR)
      ..arcToPoint(Offset(w - cornerR, h), radius: Radius.circular(cornerR))
      ..lineTo(cornerR, h)
      ..arcToPoint(Offset(0, h - cornerR), radius: Radius.circular(cornerR))
      ..lineTo(0, cy + notchR)
      ..arcToPoint(
        Offset(0, cy - notchR),
        radius: Radius.circular(notchR),
        clockwise: false,
      )
      ..lineTo(0, cornerR)
      ..arcToPoint(Offset(cornerR, 0), radius: Radius.circular(cornerR))
      ..close();
  }

  @override
  bool shouldReclip(covariant TicketShapeClipper old) =>
      old.cornerR != cornerR ||
      old.notchR != notchR ||
      old.notchFromBottom != notchFromBottom;
}

class TicketDashPainter extends CustomPainter {
  const TicketDashPainter({this.notchR = MovieTicketMetrics.notchR});

  final double notchR;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final double inset = notchR + 8;
    double x = inset;
    final double y = size.height / 2;
    while (x < size.width - inset) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), dash);
      x += 10;
    }
  }

  @override
  bool shouldRepaint(covariant TicketDashPainter old) => old.notchR != notchR;
}

class TicketBarcodePainter extends CustomPainter {
  const TicketBarcodePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = Colors.white.withValues(alpha: 0.90);
    const List<double> widths = <double>[
      1.5, 1, 2.6, 1, 1, 3, 1.5, 1, 2.1, 1, 1.5, 2.6, 1, 3, 1, 1.5, 1, 2.1, 1,
      2.6, 1, 1, 3, 1.5, 1, 2.1, 1.5, 1, 1, 2.6, 1, 1.5, 3, 1, 2.1, 1, 1.5, 1,
      2.6, 1, 2.1, 1, 1, 3, 1.5, 2.6, 1, 1, 2.1, 1.5,
    ];
    double x = 0;
    int i = 0;
    while (x < size.width) {
      final double w = widths[i % widths.length];
      if (i.isEven) {
        canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      }
      x += w + 1.15;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Decorative QR (not scannable).
class TicketQrPainter extends CustomPainter {
  const TicketQrPainter({this.color = const Color(0xFF111113)});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..color = color;
    const int n = 13;
    final double cell = size.width / n;

    void finder(int ox, int oy) {
      for (int y = 0; y < 3; y++) {
        for (int x = 0; x < 3; x++) {
          if (x == 0 || x == 2 || y == 0 || y == 2 || (x == 1 && y == 1)) {
            canvas.drawRect(
              Rect.fromLTWH((ox + x) * cell, (oy + y) * cell, cell, cell),
              p,
            );
          }
        }
      }
    }

    finder(0, 0);
    finder(n - 3, 0);
    finder(0, n - 3);

    int seed = 97;
    for (int y = 0; y < n; y++) {
      for (int x = 0; x < n; x++) {
        final bool inFinder = (x < 4 && y < 4) ||
            (x >= n - 4 && y < 4) ||
            (x < 4 && y >= n - 4);
        if (inFinder) continue;
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        if (seed % 3 != 0) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell * 0.9, cell * 0.9),
            p,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant TicketQrPainter old) => old.color != color;
}

class TicketBarcodeStrip extends StatelessWidget {
  const TicketBarcodeStrip({super.key, this.height = 40});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: const CustomPaint(painter: TicketBarcodePainter()),
    );
  }
}

class TicketQrTile extends StatelessWidget {
  const TicketQrTile({
    super.key,
    required this.size,
    required this.accent,
  });

  final double size;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const CustomPaint(painter: TicketQrPainter()),
    );
  }
}

class TicketTearLine extends StatelessWidget {
  const TicketTearLine({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: const CustomPaint(painter: TicketDashPainter()),
    );
  }
}
