import 'dart:ui' as ui;

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

    final Widget art = _RasterizedSvg(
      asset: assetFor(variant),
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

/// An SVG asset drawn as a bitmap, rendered once per pixel size and reused.
///
/// Each cover is ~100 KB of emblem path data. Drawn as vectors, every frame
/// re-encodes all of it, and in the add menu the cover sits inside several
/// fades at once -- the step's own, the tile row's reveal -- so a step change
/// re-drew it several times a frame. On a 120Hz phone that made going back to
/// the Documents step rasterise at 60-80ms a frame. As a bitmap it costs what
/// any image costs. Until the bitmap is ready the vector draws in its place,
/// and the two are pixel for pixel the same, so the swap is invisible.
class _RasterizedSvg extends StatefulWidget {
  const _RasterizedSvg({
    required this.asset,
    required this.width,
    required this.height,
  });

  final String asset;
  final double width;
  final double height;

  /// Bitmaps by asset and pixel size. A handful at most: two covers, at the
  /// few sizes the add menu draws them.
  static final Map<String, ui.Image> _images = <String, ui.Image>{};
  static final Map<String, Future<ui.Image?>> _pending =
      <String, Future<ui.Image?>>{};

  static Future<ui.Image?> _render(String asset, int pw, int ph) async {
    final PictureInfo info = await vg.loadPicture(SvgAssetLoader(asset), null);
    try {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      Canvas(recorder)
        ..scale(pw / info.size.width, ph / info.size.height)
        ..drawPicture(info.picture);
      final ui.Picture scaled = recorder.endRecording();
      final ui.Image image = await scaled.toImage(pw, ph);
      scaled.dispose();
      return image;
    } finally {
      info.picture.dispose();
    }
  }

  @override
  State<_RasterizedSvg> createState() => _RasterizedSvgState();
}

class _RasterizedSvgState extends State<_RasterizedSvg> {
  String? _key;
  ui.Image? _image;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_RasterizedSvg old) {
    super.didUpdateWidget(old);
    _resolve();
  }

  void _resolve() {
    // Twice the device pixels, drawn down with mipmaps: the cover sits at
    // fractional offsets and sizes, and a bitmap at exactly screen resolution
    // would be resampled up and read softer than the vector it replaces.
    final double scale = MediaQuery.devicePixelRatioOf(context) * 2;
    final int pw = (widget.width * scale).round();
    final int ph = (widget.height * scale).round();
    final String key = '${widget.asset}@${pw}x$ph';
    if (key == _key) return;
    _key = key;
    _image = _RasterizedSvg._images[key];
    if (_image != null || pw <= 0 || ph <= 0) return;
    _RasterizedSvg._pending
        .putIfAbsent(key, () => _RasterizedSvg._render(widget.asset, pw, ph))
        .then((ui.Image? image) {
          _RasterizedSvg._pending.remove(key);
          if (image == null) return;
          _RasterizedSvg._images.putIfAbsent(key, () => image);
          if (mounted && _key == key) {
            setState(() => _image = _RasterizedSvg._images[key]);
          }
        }, onError: (Object _) => _RasterizedSvg._pending.remove(key));
  }

  @override
  Widget build(BuildContext context) {
    final ui.Image? image = _image;
    if (image == null) {
      return SvgPicture.asset(
        widget.asset,
        width: widget.width,
        height: widget.height,
      );
    }
    return RawImage(
      image: image,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );
  }
}
