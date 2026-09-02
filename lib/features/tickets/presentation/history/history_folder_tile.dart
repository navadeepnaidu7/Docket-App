import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/bounce_tap.dart';
import '../../domain/history_folder.dart';
import '../../domain/pass_history_category.dart';
import 'history_visuals.dart';

/// One category folder in the archive grid.
///
/// A paper object, not a hole: stacked sheet behind, sculpted fill, top lip
/// catching light, a tinted mark well. Spec in `docs/features/archive-folders.md`.
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
  static const double aspectRatio = 0.90;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final _FolderPalette palette = _FolderPalette.of(scheme, folder.category);

    return Semantics(
      button: true,
      label: '${folder.category.label}, ${folder.countLabel}',
      child: BounceTap(
        onTap: () {
          HapticService.select();
          onTap();
        },
        scaleFactor: 0.96,
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _FolderPainter(palette: palette),
              child: ClipPath(
                clipper: const _FolderClipper(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: _FolderShape.tabHeight),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Space.x4,
                          Space.x3,
                          Space.x4,
                          Space.x4,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Hero(
                                  tag:
                                      'history-category-${folder.category.name}',
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: HistoryCategoryWell(
                                      category: folder.category,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                _OpenAffordance(
                                  color: palette.chrome,
                                  fill: palette.wellFill,
                                  edge: palette.wellEdge,
                                ),
                              ],
                            ),
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: _FolderCopy(folder: folder),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Keep copy inside the folder; the painter draws the
                    // backing sheet in this strip.
                    const SizedBox(height: _FolderShape.stackReveal),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Count then title. Scales down instead of overflowing at large text sizes.
class _FolderCopy extends StatelessWidget {
  const _FolderCopy({required this.folder});

  final HistoryFolderSummary folder;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  folder.countLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.15,
                    height: 1.2,
                    color: AppTokens.tertiaryLabel(scheme),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  folder.category.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.45,
                    height: 1.15,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OpenAffordance extends StatelessWidget {
  const _OpenAffordance({
    required this.color,
    required this.fill,
    required this.edge,
  });

  final Color color;
  final Color fill;
  final Color edge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: Border.all(color: edge, width: 0.5),
        ),
        child: Center(
          child: Icon(Icons.arrow_outward_rounded, size: 14, color: color),
        ),
      ),
    );
  }
}

/// Theme-aware paints for one folder. Computed once in [build], handed to
/// the painter so [CustomPainter] never reads [Theme].
class _FolderPalette {
  const _FolderPalette({
    required this.fillTop,
    required this.fillBottom,
    required this.sheet,
    required this.edge,
    required this.rim,
    required this.pocket,
    required this.shadow,
    required this.chrome,
    required this.wellFill,
    required this.wellEdge,
  });

  final Color fillTop;
  final Color fillBottom;
  final Color sheet;
  final Color edge;
  final Color rim;
  final Color pocket;
  final Color? shadow;
  final Color chrome;
  final Color wellFill;
  final Color wellEdge;

  factory _FolderPalette.of(ColorScheme scheme, PassHistoryCategory category) {
    final Brightness brightness = scheme.brightness;
    final bool isDark = brightness == Brightness.dark;
    final Color elevated = AppTheme.elevated(brightness);
    final Color accent = HistoryCategoryMark.mutedAccent(category, brightness);

    final Color fillTop = Color.lerp(
      Color.lerp(elevated, Colors.white, isDark ? 0.05 : 0.0)!,
      accent,
      isDark ? 0.11 : 0.08,
    )!;
    final Color fillBottom = Color.lerp(
      elevated,
      isDark ? Colors.black : accent,
      isDark ? 0.22 : 0.06,
    )!;

    return _FolderPalette(
      fillTop: fillTop,
      fillBottom: fillBottom,
      sheet: Color.lerp(
        isDark ? elevated : AppTheme.surface(brightness),
        isDark ? Colors.black : accent,
        isDark ? 0.38 : 0.10,
      )!,
      edge: isDark
          ? scheme.onSurface.withValues(alpha: 0.10)
          : AppTokens.hairline(scheme),
      rim: isDark
          ? Colors.white.withValues(alpha: 0.16)
          : Colors.white.withValues(alpha: 0.82),
      pocket: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
      shadow: isDark ? null : Colors.black.withValues(alpha: 0.08),
      chrome: HistoryCategoryMark.chromeOf(scheme),
      wellFill: scheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.05),
      wellEdge: scheme.onSurface.withValues(alpha: isDark ? 0.12 : 0.08),
    );
  }
}

/// Folder silhouette geometry. Clip and stroke share this path so they cannot
/// drift apart. The path sits short of the cell bottom so a backing sheet
/// can peek out.
abstract final class _FolderShape {
  static const double tabHeight = 18;
  static const double tabWidthFraction = 0.36;
  static const double bodyRadius = AppTheme.radiusCard;
  static const double tabRadius = 9;
  static const double joinRadius = 8;
  static const double inset = 1;
  static const double stackReveal = 7;

  static Path pathFor(Size size) {
    final double left = inset;
    final double top = inset;
    final double right = size.width - inset;
    final double bottom = size.height - inset - stackReveal;
    final double innerW = right - left;
    final double innerH = bottom - top;

    final double tabH = math.min(tabHeight, innerH * 0.16);
    final double tabW = left + innerW * tabWidthFraction;
    final double tr = math.min(tabRadius, tabH * 0.48);
    final double jr = math.min(joinRadius, tabH * 0.42);
    final double br = math.min(bodyRadius, (innerH - tabH) * 0.5);

    return Path()
      ..moveTo(left, top + tr)
      ..quadraticBezierTo(left, top, left + tr, top)
      ..lineTo(tabW - tr, top)
      ..quadraticBezierTo(tabW, top, tabW, top + tr)
      ..lineTo(tabW, top + tabH - jr)
      ..quadraticBezierTo(tabW, top + tabH, tabW + jr, top + tabH)
      ..lineTo(right - br, top + tabH)
      ..quadraticBezierTo(right, top + tabH, right, top + tabH + br)
      ..lineTo(right, bottom - br)
      ..quadraticBezierTo(right, bottom, right - br, bottom)
      ..lineTo(left + br, bottom)
      ..quadraticBezierTo(left, bottom, left, bottom - br)
      ..close();
  }

  static double tabHFor(Size size) {
    final double innerH = size.height - inset * 2 - stackReveal;
    return math.min(tabHeight, innerH * 0.16);
  }
}

class _FolderClipper extends CustomClipper<Path> {
  const _FolderClipper();

  @override
  Path getClip(Size size) => _FolderShape.pathFor(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _FolderPainter extends CustomPainter {
  _FolderPainter({required this.palette});

  final _FolderPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = _FolderShape.pathFor(size);
    final Rect bounds = path.getBounds();
    final double tabH = _FolderShape.tabHFor(size);
    final double br = math.min(
      _FolderShape.bodyRadius,
      (bounds.height - tabH) * 0.5,
    );

    final RRect sheet = RRect.fromLTRBR(
      bounds.left + 5,
      bounds.top + tabH + 3,
      bounds.right - 5,
      size.height - _FolderShape.inset,
      Radius.circular(br * 0.92),
    );

    if (palette.shadow != null) {
      final Paint shadowPaint = Paint()
        ..color = palette.shadow!
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas
        ..save()
        ..translate(0, 4)
        ..drawPath(path, shadowPaint)
        ..restore();
    }

    canvas.drawRRect(sheet, Paint()..color = palette.sheet);
    canvas.drawRRect(
      sheet,
      Paint()
        ..color = palette.edge.withValues(alpha: palette.edge.a * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    canvas.save();
    canvas.clipPath(path);

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.fillTop, palette.fillBottom],
        ).createShader(bounds),
    );

    // Light catching the top lip — the same trick as SquircleTile.
    canvas.drawRect(
      Rect.fromLTWH(bounds.left, bounds.top, bounds.width, 16),
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                palette.rim.withValues(alpha: palette.rim.a * 0.55),
                palette.rim.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromLTWH(bounds.left, bounds.top, bounds.width, 16),
            ),
    );

    // Pocket crease: the body recedes under the tab.
    final double creaseTop = bounds.top + tabH;
    canvas.drawRect(
      Rect.fromLTWH(bounds.left, creaseTop, bounds.width, 12),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.pocket, palette.pocket.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(bounds.left, creaseTop, bounds.width, 12)),
    );

    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.rim, palette.edge],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(covariant _FolderPainter old) =>
      old.palette.fillTop != palette.fillTop ||
      old.palette.fillBottom != palette.fillBottom ||
      old.palette.sheet != palette.sheet ||
      old.palette.edge != palette.edge ||
      old.palette.rim != palette.rim ||
      old.palette.pocket != palette.pocket ||
      old.palette.shadow != palette.shadow;
}
