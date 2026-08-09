import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/bounce_tap.dart';
import '../../domain/history_folder.dart';
import 'history_folder_thumbs.dart';
import 'history_visuals.dart';

/// One category folder in the archive grid.
///
/// Paper body in theme tokens with the category accent confined to the tab, and
/// preview chips tucked behind the front lip so the folder shows what it holds.
class HistoryFolderTile extends StatelessWidget {
  const HistoryFolderTile({
    super.key,
    required this.folder,
    required this.onTap,
  });

  final HistoryFolderSummary folder;
  final VoidCallback onTap;

  /// Grid cell proportion. The grid delegate is the only other consumer — keep
  /// this the single source of truth so the two cannot drift.
  static const double aspectRatio = 0.86;

  static const double _cornerRadius = 16;
  static const double _minTabHeight = 18;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Brightness brightness = theme.brightness;
    final bool isDark = brightness == Brightness.dark;

    Color accent = HistoryStripLook.forCategory(folder.category).gradient.first;
    if (isDark) {
      // Keep the saturated category colors from glowing against near-black.
      accent = Color.lerp(accent, AppTheme.elevated(Brightness.dark), 0.15)!;
    }

    final Color back = Color.lerp(AppTheme.surface(brightness), accent, 0.10)!;
    final Color edge = AppTokens.hairline(scheme);

    return BounceTap(
      onTap: () {
        HapticService.select();
        onTap();
      },
      scaleFactor: 0.97,
      child: Semantics(
        button: true,
        label: '${folder.category.label}, ${folder.countLabel}',
        child: RepaintBoundary(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double h = constraints.maxHeight;
              final double tabHeight = math.max(_minTabHeight, h * 0.14);
              final double frontTop = h * 0.42;

              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  CustomPaint(
                    painter: _FolderBackPainter(
                      body: back,
                      accent: accent,
                      edge: edge,
                      shadow: Colors.black.withValues(
                        alpha: isDark ? 0.45 : 0.16,
                      ),
                      tabHeight: tabHeight,
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    top: tabHeight + 8,
                    // Chips run past the lip; the front panel crops them, which
                    // is what makes them read as tucked inside.
                    bottom: h - frontTop - h * 0.10,
                    child: ClipRect(
                      child: ExcludeSemantics(
                        child: HistoryFolderThumbs(items: folder.items),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: frontTop,
                    bottom: 0,
                    child: _FolderFront(
                      folder: folder,
                      fill: AppTheme.elevated(brightness),
                      edge: edge,
                      isDark: isDark,
                    ),
                  ),
                  // The tab glyph rides above the back panel it sits on.
                  Positioned(
                    left: 14,
                    top: 0,
                    height: tabHeight,
                    child: Center(
                      child: HistoryCategoryMark(
                        category: folder.category,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The front lip: paper panel carrying the label block.
class _FolderFront extends StatelessWidget {
  const _FolderFront({
    required this.folder,
    required this.fill,
    required this.edge,
    required this.isDark,
  });

  final HistoryFolderSummary folder;
  final Color fill;
  final Color edge;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // At large text scales the third line pushes the block out of the panel.
    final bool showLastAdded = folder.lastAddedLabel != null &&
        MediaQuery.textScalerOf(context).scale(12) <= 14.5;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(HistoryFolderTile._cornerRadius),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Drawn as a child rather than a BoxDecoration border: a one-sided
          // border cannot be combined with a borderRadius.
          SizedBox(height: 0.5, child: ColoredBox(color: edge)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Text(
                    folder.category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      color: scheme.onSurface,
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
                      color: AppTokens.secondaryLabel(scheme),
                    ),
                  ),
                  if (showLastAdded) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      folder.lastAddedLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTokens.tertiaryLabel(scheme),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Folder silhouette: body panel plus the accented tab.
class _FolderBackPainter extends CustomPainter {
  _FolderBackPainter({
    required this.body,
    required this.accent,
    required this.edge,
    required this.shadow,
    required this.tabHeight,
  });

  final Color body;
  final Color accent;
  final Color edge;
  final Color shadow;
  final double tabHeight;

  /// Horizontal run of the diagonal between tab and body.
  static const double _slant = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double tabW = w * 0.44;
    final Path path = _folderPath(w, h, tabW);

    canvas.drawShadow(path, shadow, 6, true);
    canvas.drawPath(path, Paint()..color = body);

    // Accent stays on the tab so the body reads as paper.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, tabW + _slant, tabHeight),
      Paint()..color = accent,
    );
    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  Path _folderPath(double w, double h, double tabW) {
    const double r = HistoryFolderTile._cornerRadius;
    const double tabR = 6;
    final double tabH = tabHeight;

    return Path()
      ..moveTo(r, 0)
      ..lineTo(tabW - tabR, 0)
      ..quadraticBezierTo(tabW, 0, tabW + _slant * 0.5, tabH * 0.55)
      ..quadraticBezierTo(tabW + _slant, tabH, tabW + _slant + tabR, tabH)
      ..lineTo(w - r, tabH)
      ..quadraticBezierTo(w, tabH, w, tabH + r)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(r, h)
      ..quadraticBezierTo(0, h, 0, h - r)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _FolderBackPainter old) =>
      old.body != body ||
      old.accent != accent ||
      old.edge != edge ||
      old.shadow != shadow ||
      old.tabHeight != tabHeight;
}
