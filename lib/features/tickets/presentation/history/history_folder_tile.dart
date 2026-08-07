import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../shared/widgets/bounce_tap.dart';
import '../../domain/history_folder.dart';
import '../../domain/pass_history_category.dart';

/// Rich folder tile for the history categories grid.
///
/// Custom-painted folder chrome (tab + body + sheen) so each category can
/// recolor without shipping per-type bitmaps.
class HistoryFolderTile extends StatelessWidget {
  const HistoryFolderTile({
    super.key,
    required this.folder,
    required this.onTap,
    this.heroTag,
  });

  final HistoryFolderSummary folder;
  final VoidCallback onTap;

  /// Optional Hero tag shared with the category header.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool isDark = brightness == Brightness.dark;
    final PassHistoryCategory category = folder.category;

    final Color face = category.folderFace(brightness);
    final Color body = category.folderBody(brightness);
    final Color ink = isDark ? Colors.white : Colors.white;
    final Color muted = ink.withValues(alpha: 0.78);

    Widget chrome = _FolderChrome(
      face: face,
      body: body,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 28, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.22),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(
                  category.icon,
                  size: 15,
                  color: ink.withValues(alpha: 0.95),
                ),
              ),
            ),
            const Spacer(),
            Text(
              category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              folder.countLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: muted,
              ),
            ),
            if (folder.lastAddedLabel != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                folder.lastAddedLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: muted.withValues(alpha: 0.85),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (heroTag != null) {
      chrome = Hero(
        tag: heroTag!,
        child: Material(
          type: MaterialType.transparency,
          child: chrome,
        ),
      );
    }

    return BounceTap(
      onTap: () {
        HapticService.select();
        onTap();
      },
      scaleFactor: 0.96,
      child: chrome,
    );
  }
}

class _FolderChrome extends StatelessWidget {
  const _FolderChrome({
    required this.face,
    required this.body,
    required this.child,
  });

  final Color face;
  final Color body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.92,
      child: CustomPaint(
        painter: _FolderPainter(face: face, body: body),
        child: child,
      ),
    );
  }
}

class _FolderPainter extends CustomPainter {
  _FolderPainter({required this.face, required this.body});

  final Color face;
  final Color body;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double r = 16;
    final double tabH = h * 0.14;
    final double tabW = w * 0.42;

    // Soft drop shadow
    final Path shadowPath = _folderPath(w, h, r, tabH, tabW);
    canvas.drawShadow(shadowPath, Colors.black.withValues(alpha: 0.28), 10, true);

    // Body fill (slightly deeper)
    final Paint bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[face, body],
      ).createShader(Offset.zero & size);

    canvas.drawPath(_folderPath(w, h, r, tabH, tabW), bodyPaint);

    // Top sheen on the main panel
    final Rect sheenRect = Rect.fromLTWH(0, tabH * 0.55, w, h - tabH * 0.55);
    final Paint sheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.45],
      ).createShader(sheenRect);
    canvas.save();
    canvas.clipPath(_folderPath(w, h, r, tabH, tabW));
    canvas.drawRect(sheenRect, sheen);
    canvas.restore();

    // Subtle inner highlight along the tab edge
    final Paint edge = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(_folderPath(w, h, r, tabH, tabW), edge);
  }

  Path _folderPath(
    double w,
    double h,
    double r,
    double tabH,
    double tabW,
  ) {
    final double tabR = lerpDouble(8, r, 0.35)!;
    final Path path = Path();

    // Start at bottom-left of tab join
    path.moveTo(0, tabH + r);
    path.quadraticBezierTo(0, tabH, r, tabH);

    // Into tab neck then tab top
    path.lineTo(tabW - tabR, tabH);
    path.quadraticBezierTo(tabW, tabH, tabW + 4, tabH * 0.55);
    path.quadraticBezierTo(tabW + 8, 0, tabW + 8 + tabR, 0);
    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w, r);
    path.lineTo(w, h - r);
    path.quadraticBezierTo(w, h, w - r, h);
    path.lineTo(r, h);
    path.quadraticBezierTo(0, h, 0, h - r);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _FolderPainter oldDelegate) =>
      oldDelegate.face != face || oldDelegate.body != body;
}
