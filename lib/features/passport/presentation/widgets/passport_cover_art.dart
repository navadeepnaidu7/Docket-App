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

/// The Indian passport cover, drawn from bundled vector art.
///
/// Sized by [height]; the width follows the artwork's own aspect so the two
/// variants always agree. The drop shadow is applied *around* the SVG rather
/// than baked into it — the source files are CC BY-SA and shipped unmodified
/// (see ATTRIBUTIONS.md), so effects compose externally.
class PassportCoverArt extends StatelessWidget {
  const PassportCoverArt({
    super.key,
    required this.variant,
    required this.height,
  });

  final PassportCoverVariant variant;
  final double height;

  /// Artwork viewBox is 400 x 568.0769.
  static const double _aspect = 400 / 568.0769230769231;

  /// The cover is rounded on the outer edge only — the left edge is the spine.
  /// Radius is 20.485638 in a 400-wide viewBox.
  static const double _cornerRatio = 20.485638 / 400;

  static String assetFor(PassportCoverVariant variant) =>
      switch (variant) {
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
    final double width = height * _aspect;
    final double radius = width * _cornerRatio;

    final BorderRadius shape = BorderRadius.only(
      topRight: Radius.circular(radius),
      bottomRight: Radius.circular(radius),
    );

    return Semantics(
      label: switch (variant) {
        PassportCoverVariant.regular => 'Passport cover',
        PassportCoverVariant.ePassport => 'E-passport cover',
      },
      image: true,
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: shape,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.52 : 0.26),
                // Proportional to the art, so the tile and the larger kind-step
                // rendering read as the same object at two sizes.
                blurRadius: height * 0.13,
                offset: Offset(0, height * 0.055),
              ),
            ],
          ),
          child: SvgPicture.asset(
            assetFor(variant),
            width: width,
            height: height,
          ),
        ),
      ),
    );
  }
}
