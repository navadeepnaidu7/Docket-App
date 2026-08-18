import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/motion/entry_reveal.dart';
import '../../core/theme/app_theme.dart';
import 'bounce_tap.dart';

/// A rounded-square tile with the label sitting *below* the tile, not inside it.
///
/// Used by the add menu. Either [icon] or [art] supplies the tile's contents —
/// [art] exists so the passport option can show real cover artwork where every
/// other tile shows a line glyph.
class SquircleTile extends StatelessWidget {
  const SquircleTile({
    super.key,
    required this.label,
    this.icon,
    this.iconAsset,
    this.art,
    this.sublabel,
    this.onTap,
    this.soon = false,
    this.aspectRatio = 1.0,
    this.radius = 28,
  }) : assert(
         icon != null || iconAsset != null || art != null,
         'Provide an icon, an iconAsset, or art',
       );

  final String label;
  final IconData? icon;

  /// Path to a stroked SVG glyph, tinted to the theme's ink.
  ///
  /// Preferred over [icon] for the pass grid: Material's outlined set sits at a
  /// different weight to the line icons the design calls for, and mixing the
  /// two in one grid is visible.
  final String? iconAsset;

  /// Custom tile contents, centred. Takes precedence over [icon].
  final Widget? art;

  /// Optional second line under [label] — the Documents grid uses it.
  final String? sublabel;

  final VoidCallback? onTap;

  /// Renders dimmed with a "Soon" badge and refuses taps.
  final bool soon;

  final double aspectRatio;
  final double radius;

  Widget _glyph(ColorScheme scheme) {
    if (art != null) return art!;
    final Color ink = scheme.onSurface.withValues(alpha: 0.88);
    if (iconAsset != null) {
      return SvgPicture.asset(
        iconAsset!,
        width: 34,
        height: 34,
        colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
      );
    }
    return Icon(icon, size: 34, color: ink);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    // A flat fill reads as a hole punched in the sheet. The gradient deepens
    // toward the bottom, the hairline catches the top edge like a lip, and the
    // light-mode shadow lifts the tile off the surface — together they make the
    // tile an object sitting on the sheet rather than an absence in it.
    final List<Color> fill = isDark
        ? <Color>[
            scheme.onSurface.withValues(alpha: 0.10),
            scheme.onSurface.withValues(alpha: 0.055),
          ]
        : <Color>[
            scheme.onSurface.withValues(alpha: 0.035),
            scheme.onSurface.withValues(alpha: 0.075),
          ];

    final Widget tile = AspectRatio(
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: fill,
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.white.withValues(alpha: 0.70),
            width: 0.5,
          ),
          boxShadow: isDark
              ? null
              : <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Stack(
          children: <Widget>[
            Center(child: _glyph(scheme)),
            if (soon)
              Positioned(
                top: 8,
                right: 8,
                child: _SoonBadge(isDark: isDark, scheme: scheme),
              ),
          ],
        ),
      ),
    );

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        tile,
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        if (sublabel != null) ...<Widget>[
          const SizedBox(height: 3),
          Text(
            sublabel!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTokens.secondaryLabel(scheme),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: !soon,
      onTap: soon ? null : onTap,
      label: soon ? '$label, coming soon' : label,
      child: ExcludeSemantics(
        child: BounceTap(
          onTap: soon ? null : onTap,
          scaleFactor: 0.97,
          child: Opacity(opacity: soon ? 0.48 : 1.0, child: content),
        ),
      ),
    );
  }
}

class _SoonBadge extends StatelessWidget {
  const _SoonBadge({required this.isDark, required this.scheme});

  final bool isDark;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        'Soon',
        style: TextStyle(
          color: AppTokens.secondaryLabel(scheme),
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Lays [tiles] out in fixed-width columns.
///
/// Built from Rows rather than a GridView so the whole thing measures its own
/// intrinsic height — the morph sheet animates to that height, and a scrolling
/// grid would report a viewport instead.
class SquircleTileGrid extends StatelessWidget {
  const SquircleTileGrid({
    super.key,
    required this.columns,
    required this.tiles,
    this.spacing = 12,
    this.runSpacing = 20,
    this.maxTileWidth = 148,
    this.stagger = true,
  });

  final int columns;
  final List<Widget> tiles;
  final double spacing;
  final double runSpacing;

  /// Reveals tiles on a short cascade rather than all at once.
  ///
  /// The delay is per *row*, not per tile: staggering across a row makes the
  /// eye track left-to-right and the grid feel slow, while a row at a time
  /// reads as the grid assembling.
  final bool stagger;

  /// Ceiling on a single tile's width.
  ///
  /// Tile height follows its width through an aspect ratio, so without a cap a
  /// wide surface — a tablet, or a phone in a large-display mode — inflates the
  /// squares until the grid outgrows the sheet's height budget and the labels
  /// scroll out of reach. On a phone the available width is well under this, so
  /// the cap never engages.
  final double maxTileWidth;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];

    for (int start = 0; start < tiles.length; start += columns) {
      final int end = (start + columns) < tiles.length
          ? start + columns
          : tiles.length;
      final List<Widget> cells = <Widget>[];

      for (int i = start; i < end; i++) {
        if (i > start) cells.add(SizedBox(width: spacing));
        cells.add(Expanded(child: tiles[i]));
      }
      // Pad a short final row so its tiles keep the column width instead of
      // stretching to fill.
      for (int i = end - start; i < columns; i++) {
        cells
          ..add(SizedBox(width: spacing))
          ..add(const Expanded(child: SizedBox.shrink()));
      }

      if (rows.isNotEmpty) rows.add(SizedBox(height: runSpacing));

      final Widget row = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cells,
      );
      rows.add(
        stagger
            ? EntryReveal(
                slideY: 12,
                duration: const Duration(milliseconds: 420),
                // Picks up after the sheet's title and subtitle have landed.
                delay: Duration(milliseconds: 90 + (start ~/ columns) * 55),
                child: row,
              )
            : row,
      );
    }

    final double cappedWidth =
        columns * maxTileWidth + (columns - 1) * spacing;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cappedWidth),
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }
}
