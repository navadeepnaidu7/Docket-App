import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/bounce_tap.dart';
import '../../domain/history_folder.dart';
import '../../domain/pass_history_category.dart';

/// Photographic category cover and real pass count for the Archive root only.
class HistoryFolderTile extends StatelessWidget {
  const HistoryFolderTile({
    super.key,
    required this.folder,
    required this.onTap,
  });

  final HistoryFolderSummary folder;
  final VoidCallback onTap;

  static const double coverAspectRatio = 1.55;
  static const double minCaptionHeight = 76;

  /// The grid and tile share this geometry, including larger system text.
  static double extentFor(double width, TextScaler textScaler) {
    final double captionHeight = math.max(
      minCaptionHeight,
      25 + textScaler.scale(28) + 3 + textScaler.scale(11) * 1.25,
    );
    return width / coverAspectRatio + captionHeight;
  }

  void _open() {
    HapticService.select();
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final BorderRadius radius = BorderRadius.circular(AppTheme.radiusCard);

    return Semantics(
      button: true,
      label: '${folder.category.label}, ${folder.countLabel}',
      onTap: _open,
      child: ExcludeSemantics(
        child: BounceTap(
          onTap: _open,
          hapticFeedback: false,
          scaleFactor: reduceMotion ? 1 : 0.972,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 120),
          child: RepaintBoundary(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppTheme.elevated(theme.brightness),
                borderRadius: radius,
                boxShadow: isDark
                    ? null
                    : const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x06000000),
                          blurRadius: 3,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: AppTokens.hairline(scheme),
                  width: 0.6,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AspectRatio(
                    aspectRatio: coverAspectRatio,
                    child: _CategoryCover(category: folder.category),
                  ),
                  Expanded(child: _CategoryCaption(folder: folder)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCover extends StatelessWidget {
  const _CategoryCover({required this.category});

  final PassHistoryCategory category;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // CSS object-position percentages from the approved preview map to
    // Flutter alignment as (2 * percentage - 1).
    final ({String asset, Alignment alignment})? cover = switch (category) {
      PassHistoryCategory.train => (
        asset: AppAssets.archiveTrainCover,
        alignment: const Alignment(0, 0.52),
      ),
      PassHistoryCategory.movie => (
        asset: AppAssets.archiveMovieCover,
        alignment: const Alignment(0, 0.10),
      ),
      PassHistoryCategory.bus => (
        asset: AppAssets.archiveBusCover,
        alignment: const Alignment(0, 0.28),
      ),
      PassHistoryCategory.flight ||
      PassHistoryCategory.event ||
      PassHistoryCategory.other => null,
    };

    if (cover == null) {
      return ColoredBox(color: theme.colorScheme.surfaceContainerHighest);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int decodeWidth = math.min(
          1000,
          math.max(
            1,
            (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                .round(),
          ),
        );
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? const Color(0x14000000)
                : Colors.transparent,
          ),
          child: Image.asset(
            cover.asset,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            alignment: cover.alignment,
            cacheWidth: decodeWidth,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
            gaplessPlayback: true,
          ),
        );
      },
    );
  }
}

class _CategoryCaption extends StatelessWidget {
  const _CategoryCaption({required this.folder});

  final HistoryFolderSummary folder;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 120;
          return Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  folder.category.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.ui(
                    fontSize: compact ? 16 : 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.45,
                    height: 1.2,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.42,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '${folder.count}',
                        style: AppFonts.ui(
                          fontSize: compact ? 26 : 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1.1,
                          height: 1,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        folder.count == 1 ? 'pass' : 'passes',
                        style: AppFonts.ui(
                          fontSize: 11,
                          height: 1.25,
                          color: AppTokens.secondaryLabel(scheme),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
