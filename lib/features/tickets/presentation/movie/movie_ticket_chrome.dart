import 'package:flutter/material.dart';

/// Shared ticket geometry: notches and the dashed tear line.
///
/// This file used to own the procedural code art too — a seeded 13x13 grid and
/// a hand-tuned bar pattern. Both are gone: a pass draws its real code through
/// `PassCodeView` or draws none at all, because a user cannot tell decorative
/// code art from the real thing until a scanner rejects it.
/// See `docs/features/ticket-code-extraction.md`.
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

  /// Standard one-sheet poster ratio (width / height), which is what TMDB
  /// serves — a `w500` poster is 500x750.
  ///
  /// The detail screen sizes the hero by this so the art is shown whole. The
  /// glance card deliberately does not: a full-height poster there would push
  /// the ticket's actual information off a card that has to read at a glance,
  /// so it keeps a fixed-height crop.
  static const double posterAspect = 2 / 3;

  static const double tearHeight = 20;
  static const double footerPadTop = 8;
  static const double footerPadBottom = 14;
  static const double footerIdGap = 6;
  static const double footerIdLine = 14;

  /// Brand-logo / e-ticket stub under the tear (shared for notch alignment).
  static double footerBodyHeight({required bool detail, required double scale}) =>
      (detail ? 82.0 : 64.0) * scale;

  /// Tear row + stub — used for notch placement from the bottom.
  static double footerStackHeight({required bool detail, required double scale}) =>
      tearHeight * scale + footerBodyHeight(detail: detail, scale: scale);

  /// Distance from ticket bottom to notch center (middle of tear row).
  static double notchFromBottom({required bool detail, required double scale}) =>
      footerBodyHeight(detail: detail, scale: scale) + (tearHeight * scale) / 2;
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
