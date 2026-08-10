import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/bounce_tap.dart';

enum AttachmentAddTileVariant { hero, strip }

/// Restrained, composed placeholder tile for adding new attachments.
///
/// Supports two visual layouts:
/// - [AttachmentAddTileVariant.hero]: Card with subtle vertical gradient, solid hairline border,
///   and a centred accent circle chip with action text.
/// - [AttachmentAddTileVariant.strip]: Compact 56x54 thumbnail tile with a centred "+" icon.
class AttachmentAddTile extends StatelessWidget {
  const AttachmentAddTile({
    super.key,
    required this.onTap,
    this.variant = AttachmentAddTileVariant.hero,
    this.height,
  });

  final VoidCallback onTap;
  final AttachmentAddTileVariant variant;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accentColor = AppTheme.accentOf(brightness);
    final inkColor = AppTheme.ink(brightness);
    final isHero = variant == AttachmentAddTileVariant.hero;
    final borderRadius = isHero ? AppTheme.radiusCard : AppTheme.radiusControl;

    final tileDecoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          AppTheme.surface(brightness),
          AppTheme.elevated(brightness),
        ],
      ),
      border: Border.all(
        color: inkColor.withValues(alpha: 0.10),
        width: 1.0,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(
            alpha: brightness == Brightness.dark ? 0.30 : 0.06,
          ),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );

    final Widget tileContent;
    if (isHero) {
      tileContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 56.0,
            height: 56.0,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add_rounded,
              size: 26,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 14.0),
          Text(
            'Add image or PDF',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: inkColor.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            'Up to 3 images and 1 PDF',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: inkColor.withValues(alpha: 0.45),
            ),
          ),
        ],
      );
    } else {
      tileContent = Center(
        child: Icon(
          Icons.add_rounded,
          size: 22,
          color: accentColor,
        ),
      );
    }

    if (!isHero) {
      return BounceTap(
        onTap: onTap,
        child: Container(
          width: 56.0,
          height: 54.0,
          decoration: tileDecoration,
          child: tileContent,
        ),
      );
    }

    // The empty slot stands in for a document, so it should read as a card
    // sitting in the tray rather than a panel spanning the sheet. Stretching to
    // the full width made it touch both edges and lose that shape; the
    // populated hero never does, since the pager insets its pages.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final double tileWidth = (available * 0.78).clamp(200.0, 320.0);

        // Height follows the width so the tile keeps a card-like proportion on
        // a narrow phone instead of turning into a tall box.
        final double requested = height ?? 216.0;
        final double tileHeight = requested.clamp(140.0, tileWidth / 1.30);

        return BounceTap(
          onTap: onTap,
          child: Container(
            width: tileWidth,
            height: tileHeight,
            decoration: tileDecoration,
            child: tileContent,
          ),
        );
      },
    );
  }
}
