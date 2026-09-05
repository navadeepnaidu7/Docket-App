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
/// Three planes of paper rather than one shape with a notch: a tinted back
/// panel carrying the tab, sheet edges peeking out of it, and a near-white
/// front pocket holding the mark and the name. Spec in
/// `docs/features/archive-folders.md`.
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
  ///
  /// Square. Taller cells leave a hole between the mark and the name that no
  /// amount of type can fill, and a folder is a landscape object anyway.
  static const double aspectRatio = 1.0;

  /// How full the folder looks. Not a number to read — a thickness to feel, so
  /// a folder of twenty passes sits fatter than one holding a single ticket.
  static int sheetsFor(int count) {
    if (count <= 1) return 1;
    if (count <= 4) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
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
              painter: _FolderPainter(
                palette: palette,
                sheets: sheetsFor(folder.count),
              ),
              // Metrics come from the real cell size, so the pocket the copy
              // sits in is the pocket the painter drew — at any scale.
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final _FolderMetrics metrics = _FolderMetrics.of(
                    constraints.biggest,
                  );
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      Space.x4,
                      // A floor, not a position: the block is bottom-anchored,
                      // this only stops it climbing over the paper stack.
                      metrics.pocketTop + Space.x2,
                      Space.x4,
                      14,
                    ),
                    // Mark and name read as one block sitting on the floor of
                    // the pocket. Splitting them to opposite corners leaves a
                    // hole in the middle that no amount of type can fill.
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Hero(
                            tag: 'history-category-${folder.category.name}',
                            child: Material(
                              type: MaterialType.transparency,
                              child: HistoryCategoryWell(
                                category: folder.category,
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.x3),
                          Flexible(child: _FolderCopy(folder: folder)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Name then count, the way a folder is labelled everywhere else.
/// Scales down instead of overflowing at large text sizes.
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
                const SizedBox(height: 4),
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
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Theme-aware paints for one folder. Computed once in [build], handed to
/// the painter so [CustomPainter] never reads [Theme].
class _FolderPalette {
  const _FolderPalette({
    required this.panelTop,
    required this.panelBottom,
    required this.faceTop,
    required this.faceBottom,
    required this.paper,
    required this.paperEdge,
    required this.sheetTint,
    required this.cast,
    required this.rim,
    required this.edge,
    required this.shadow,
  });

  /// Back panel — the folder's own colour, seen through the tab and the strip
  /// the paper sits in.
  final Color panelTop;
  final Color panelBottom;

  /// Front pocket. Stays near the surface colour: this is the plane the eye
  /// reads text off.
  final Color faceTop;
  final Color faceBottom;

  final Color paper;
  final Color paperEdge;
  final double sheetTint;

  /// Shadow the pocket throws back onto the paper.
  final Color cast;

  final Color rim;
  final Color edge;

  /// Drop shadow under the whole folder, or null in dark mode where a cast
  /// shadow on a dark ground only reads as mud.
  final Color? shadow;

  factory _FolderPalette.of(ColorScheme scheme, PassHistoryCategory category) {
    final Brightness brightness = scheme.brightness;
    final bool isDark = brightness == Brightness.dark;
    final Color elevated = AppTheme.elevated(brightness);
    final Color accent = HistoryCategoryMark.mutedAccent(category, brightness);

    // The panel carries most of the category colour. It shows as a tab and a
    // 14px shelf, so it can hold a real tint where a full-face wash could not —
    // and the name still outranks it, because the name sits on the white part.
    final Color panelBase = isDark
        ? Color.lerp(elevated, Colors.black, 0.12)!
        : elevated;

    return _FolderPalette(
      panelTop: Color.lerp(panelBase, accent, isDark ? 0.32 : 0.26)!,
      panelBottom: Color.lerp(panelBase, accent, isDark ? 0.44 : 0.38)!,
      faceTop: isDark ? Color.lerp(elevated, Colors.white, 0.05)! : elevated,
      faceBottom: Color.lerp(elevated, accent, isDark ? 0.16 : 0.06)!,
      // Paper is the brightest thing on the tile. Against a tinted panel that
      // is what makes the stack read as sheets rather than as more folder.
      paper: isDark ? Color.lerp(elevated, Colors.white, 0.32)! : elevated,
      // How far each sheet behind the front one is pulled toward the panel.
      // Near zero in dark mode, where any darkening swallows the stack whole.
      sheetTint: isDark ? 0.14 : 0.30,
      paperEdge: isDark
          ? Colors.white.withValues(alpha: 0.14)
          : Colors.black.withValues(alpha: 0.07),
      cast: Colors.black.withValues(alpha: isDark ? 0.30 : 0.13),
      rim: isDark
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.white.withValues(alpha: 0.85),
      edge: isDark
          ? scheme.onSurface.withValues(alpha: 0.12)
          : AppTokens.hairline(scheme),
      shadow: isDark ? null : Colors.black.withValues(alpha: 0.09),
    );
  }
}

/// Folder geometry for one cell. The painter and the content padding both read
/// it, so the copy can never land outside the pocket it appears to sit in.
class _FolderMetrics {
  const _FolderMetrics._({
    required this.silhouette,
    required this.pocket,
    required this.shelf,
    required this.pocketTop,
    required this.sheetStep,
  });

  /// Outer edge: tab plus body.
  final Path silhouette;

  /// The front pocket, running the full width down to the bottom.
  final RRect pocket;

  /// Where the tab ends and the body's own top edge begins.
  final double shelf;

  /// Top of the pocket.
  final double pocketTop;

  /// Vertical offset between consecutive sheet edges.
  final double sheetStep;

  static const double _tabHeight = 19;
  static const double _tabWidthFraction = 0.40;
  static const double _sheetBand = 14;
  static const double _bodyRadius = AppTheme.radiusCard;
  static const double _tabRadius = 8;
  static const double _joinRadius = 7;
  static const double _pocketRadius = 12;

  /// Horizontal inset of the frontmost sheet. Each sheet behind it is
  /// [sheetInsetStep] narrower on both sides.
  static const double sheetInset = 9;
  static const double sheetInsetStep = 5;

  static _FolderMetrics of(Size size) {
    // Constraints can be unbounded during an intrinsic pass; fall back to the
    // cell the grid actually hands out rather than painting a NaN path.
    final double w = size.width.isFinite ? size.width : 168;
    final double h = size.height.isFinite
        ? size.height
        : w / HistoryFolderTile.aspectRatio;

    const double half = 0.5;
    const double l = half;
    const double t = half;
    final double r = math.max(l + 2, w - half);
    final double b = math.max(t + 2, h - half);

    final double tabH = math.min(_tabHeight, (b - t) * 0.14);
    final double band = math.min(_sheetBand, (b - t) * 0.10);
    final double tabW = l + (r - l) * _tabWidthFraction;
    final double tr = math.min(_tabRadius, tabH * 0.45);
    final double jr = math.min(_joinRadius, tabH * 0.40);
    final double br = math.min(
      _bodyRadius,
      math.min((b - t - tabH) * 0.5, (r - l) * 0.5),
    );

    final Path silhouette = Path()
      ..moveTo(l, t + tr)
      ..quadraticBezierTo(l, t, l + tr, t)
      ..lineTo(tabW - tr, t)
      ..quadraticBezierTo(tabW, t, tabW, t + tr)
      ..lineTo(tabW, t + tabH - jr)
      ..quadraticBezierTo(tabW, t + tabH, tabW + jr, t + tabH)
      ..lineTo(r - br, t + tabH)
      ..quadraticBezierTo(r, t + tabH, r, t + tabH + br)
      ..lineTo(r, b - br)
      ..quadraticBezierTo(r, b, r - br, b)
      ..lineTo(l + br, b)
      ..quadraticBezierTo(l, b, l, b - br)
      ..close();

    final double pocketTop = t + tabH + band;
    final double pr = math.min(_pocketRadius, (b - pocketTop) * 0.35);

    return _FolderMetrics._(
      silhouette: silhouette,
      pocket: RRect.fromLTRBAndCorners(
        l,
        pocketTop,
        r,
        b,
        topLeft: Radius.circular(pr),
        topRight: Radius.circular(pr),
        bottomLeft: Radius.circular(br),
        bottomRight: Radius.circular(br),
      ),
      shelf: t + tabH,
      pocketTop: pocketTop,
      // Three edges have to fit inside the band with air left above the top one.
      sheetStep: band / 3.8,
    );
  }
}

class _FolderPainter extends CustomPainter {
  _FolderPainter({required this.palette, required this.sheets});

  final _FolderPalette palette;
  final int sheets;

  @override
  void paint(Canvas canvas, Size size) {
    final _FolderMetrics m = _FolderMetrics.of(size);
    final Rect bounds = Offset.zero & size;

    _paintDropShadow(canvas, m);

    canvas.save();
    canvas.clipPath(m.silhouette);

    // Back panel.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.panelTop, palette.panelBottom],
        ).createShader(bounds),
    );

    // Light catching the tab's top lip — the same trick as SquircleTile — and
    // again, fainter, on the body's own top edge to the right of the tab. The
    // shelf highlight has to stay under the tab's or the tab reads as detached.
    _paintLip(canvas, bounds.left, 0, bounds.width, 8, 0.40);
    _paintLip(canvas, bounds.left, m.shelf, bounds.width, 9, 0.30);

    _paintSheets(canvas, m, size);

    // The pocket stands proud of the paper, so it throws a shadow back onto it.
    final Rect cast = Rect.fromLTRB(
      bounds.left,
      m.pocketTop - 7,
      bounds.right,
      m.pocketTop,
    );
    canvas.drawRect(
      cast,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.cast.withValues(alpha: 0), palette.cast],
        ).createShader(cast),
    );

    // Front pocket.
    final Rect faceRect = m.pocket.outerRect;
    canvas.drawRRect(
      m.pocket,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.faceTop, palette.faceBottom],
        ).createShader(faceRect),
    );

    // Rim on the pocket's top edge only. Stroking all the way round would
    // double up against the silhouette's own sides.
    canvas.drawRRect(
      m.pocket.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[palette.rim, palette.rim.withValues(alpha: 0)],
            ).createShader(
              Rect.fromLTWH(faceRect.left, faceRect.top, faceRect.width, 24),
            ),
    );

    canvas.restore();

    canvas.drawPath(
      m.silhouette,
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

  void _paintDropShadow(Canvas canvas, _FolderMetrics m) {
    final Color? shadow = palette.shadow;
    if (shadow == null) return;

    // Two layers: a wide ambient one and a tight contact one. A single blur
    // reads as fog; the pair reads as an object resting on the sheet.
    canvas
      ..save()
      ..translate(0, 5)
      ..drawPath(
        m.silhouette,
        Paint()
          ..color = shadow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      )
      ..restore()
      ..save()
      ..translate(0, 1)
      ..drawPath(
        m.silhouette,
        Paint()
          ..color = shadow.withValues(alpha: shadow.a * 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      )
      ..restore();
  }

  void _paintLip(
    Canvas canvas,
    double left,
    double top,
    double width,
    double height,
    double strength,
  ) {
    final Rect lip = Rect.fromLTWH(left, top, width, height);
    canvas.drawRect(
      lip,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            palette.rim.withValues(alpha: palette.rim.a * strength),
            palette.rim.withValues(alpha: 0),
          ],
        ).createShader(lip),
    );
  }

  /// Sheet edges peeking out of the panel, back to front: each one lower,
  /// wider and a shade brighter than the one behind it.
  void _paintSheets(Canvas canvas, _FolderMetrics m, Size size) {
    final Paint edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = palette.paperEdge;

    for (int j = sheets - 1; j >= 0; j--) {
      final double inset =
          _FolderMetrics.sheetInset + j * _FolderMetrics.sheetInsetStep;
      final RRect sheet = RRect.fromLTRBR(
        inset,
        m.pocketTop - (j + 1) * m.sheetStep,
        size.width - inset,
        // Runs on under the pocket; only the top edge is ever visible.
        m.pocketTop + 10,
        const Radius.circular(5),
      );

      // Each sheet shades the sliver of the one behind it. Drawn as the sheet's
      // own silhouette lifted upward, so only the part above its top edge
      // survives the opaque fill that follows — the rest is covered.
      canvas
        ..save()
        ..translate(0, -2)
        ..drawRRect(
          sheet,
          Paint()
            ..color = palette.cast
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
        )
        ..restore()
        ..drawRRect(
          sheet,
          Paint()
            ..color = Color.lerp(
              palette.paper,
              palette.panelBottom,
              j * palette.sheetTint,
            )!,
        )
        ..drawRRect(sheet.deflate(0.25), edge);
    }
  }

  @override
  bool shouldRepaint(covariant _FolderPainter old) =>
      old.sheets != sheets ||
      old.palette.panelTop != palette.panelTop ||
      old.palette.panelBottom != palette.panelBottom ||
      old.palette.faceTop != palette.faceTop ||
      old.palette.faceBottom != palette.faceBottom ||
      old.palette.paper != palette.paper ||
      old.palette.paperEdge != palette.paperEdge ||
      old.palette.sheetTint != palette.sheetTint ||
      old.palette.cast != palette.cast ||
      old.palette.rim != palette.rim ||
      old.palette.edge != palette.edge ||
      old.palette.shadow != palette.shadow;
}
