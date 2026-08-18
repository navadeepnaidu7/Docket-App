import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';

/// Which passport cover to draw.
enum PassportCoverVariant {
  /// Plain cover — no chip symbol.
  regular,

  /// Carries the ICAO e-passport chip symbol at the foot of the cover.
  ePassport,
}

/// How much of the cover to show.
enum PassportCoverCrop {
  /// The whole cover.
  full,

  /// A close-up of the lower cover: the "PASSPORT" wordmark, and the chip
  /// symbol on the e-passport.
  ///
  /// Side by side this is the more useful framing — the chip is the *only*
  /// thing that distinguishes the two variants, and at tile size it is a few
  /// pixels on a full cover.
  wordmark,
}

/// The Indian passport cover, drawn from bundled vector art.
///
/// Sized by [height]; the width follows the artwork's own aspect so the two
/// variants always agree. The drop shadow is applied *around* the SVG rather
/// than baked into it — the source files are CC BY-SA and shipped unmodified
/// (see ATTRIBUTIONS.md), so effects compose externally. The [PassportCoverCrop
/// .wordmark] framing is likewise a clip over the untouched artwork, not a
/// second asset.
class PassportCoverArt extends StatelessWidget {
  const PassportCoverArt({
    super.key,
    required this.variant,
    required this.height,
    this.crop = PassportCoverCrop.full,
  });

  final PassportCoverVariant variant;

  /// Displayed height — of the whole cover, or of the crop.
  final double height;

  final PassportCoverCrop crop;

  /// Artwork viewBox is 400 x 568.0769.
  static const double _aspect = 400 / 568.0769230769231;

  /// The cover is rounded on the outer edge only — the left edge is the spine.
  /// Radius is 20.485638 in a 400-wide viewBox.
  static const double _cornerRatio = 20.485638 / 400;

  /// Fraction of the artwork's height kept by the wordmark crop, measured up
  /// from the bottom edge.
  ///
  /// The Devanagari wordmark sits at y 455, "PASSPORT" at y 484 and the chip
  /// symbol at y 531, in a 568-tall viewBox — so the bottom 24% holds all
  /// three with a little air.
  static const double _cropHeightFraction = 0.245;

  /// Fraction of the artwork's width kept, centred. The wordmark occupies the
  /// middle of the cover; keeping the full width would frame mostly margin.
  static const double _cropWidthFraction = 0.54;

  static String assetFor(PassportCoverVariant variant) => switch (variant) {
    PassportCoverVariant.regular => AppAssets.passportCoverRegular,
    PassportCoverVariant.ePassport => AppAssets.passportCoverEPassport,
  };

  /// Parses both covers into the SVG cache ahead of first paint.
  ///
  /// Each file is ~100 KB of path data for the emblem, and parsing happens on
  /// the platform thread the first time one is built. Without this the add menu
  /// hitches on open. Call after first frame, not during startup — main() is
  /// already on a font-loading budget.
  static Future<void> warmUp() async {
    for (final PassportCoverVariant variant in PassportCoverVariant.values) {
      final SvgAssetLoader loader = SvgAssetLoader(assetFor(variant));
      await svg.cache.putIfAbsent(
        loader.cacheKey(null),
        () => loader.loadBytes(null),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Whole-artwork dimensions. For the crop these are larger than what shows:
    // the SVG is drawn at full size and clipped down to the visible window.
    final double artHeight = switch (crop) {
      PassportCoverCrop.full => height,
      PassportCoverCrop.wordmark => height / _cropHeightFraction,
    };
    final double artWidth = artHeight * _aspect;

    final double shownWidth = switch (crop) {
      PassportCoverCrop.full => artWidth,
      PassportCoverCrop.wordmark => artWidth * _cropWidthFraction,
    };

    final BorderRadius shape = switch (crop) {
      // Rounded on the outer edge only — the left edge is the spine.
      PassportCoverCrop.full => BorderRadius.only(
        topRight: Radius.circular(artWidth * _cornerRatio),
        bottomRight: Radius.circular(artWidth * _cornerRatio),
      ),
      // The crop is an interior window, so it carries none of the cover's own
      // corners. A small uniform radius keeps it reading as a deliberate
      // close-up rather than a torn edge.
      PassportCoverCrop.wordmark => BorderRadius.circular(8),
    };

    final Widget art = SvgPicture.asset(
      assetFor(variant),
      width: artWidth,
      height: artHeight,
    );

    return Semantics(
      label: switch (variant) {
        PassportCoverVariant.regular => 'Passport cover',
        PassportCoverVariant.ePassport => 'E-passport cover, with chip symbol',
      },
      image: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.52 : 0.26),
              // Proportional to what is shown, so both framings read as the
              // same object lit the same way.
              blurRadius: height * 0.13,
              offset: Offset(0, height * 0.055),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: shape,
          child: SizedBox(
            width: shownWidth,
            height: height,
            child: switch (crop) {
              PassportCoverCrop.full => art,
              // OverflowBox hands the artwork its full size while itself
              // taking the smaller box above, anchoring the oversized child
              // bottom-centre — where the wordmark and chip live — so the
              // ClipRRect trims everything else away.
              //
              // The looser constraints are the point: SvgPicture defaults to
              // BoxFit.contain, so under the crop box's tight constraints it
              // would shrink the whole cover to fit instead of overflowing it.
              PassportCoverCrop.wordmark => OverflowBox(
                alignment: Alignment.bottomCenter,
                minWidth: 0,
                maxWidth: artWidth,
                minHeight: 0,
                maxHeight: artHeight,
                child: art,
              ),
            },
          ),
        ),
      ),
    );
  }
}
