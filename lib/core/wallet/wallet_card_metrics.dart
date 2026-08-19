import 'package:flutter/material.dart';

/// Shared geometry for wallet cards.
///
/// Card faces are authored against a fixed logical canvas (see
/// [WalletCardCanvas]) and then scaled to whatever box the device gives them.
/// That keeps a face pixel-identical to its design on a 320dp phone and a
/// 1024dp tablet, instead of stretching the box while the type stays put.
class WalletCardMetrics {
  const WalletCardMetrics._();

  /// ISO/IEC 7810 ID-1 (85.6 × 54 mm) — physical credit/ID card ratio.
  static const double idAspect = 1.586;

  /// Widest a single card is allowed to get. Past this a card stops looking
  /// like a card and starts looking like a poster, so on tablets we cap and
  /// centre rather than stretching edge to edge.
  static const double maxCardWidth = 460.0;

  /// Design canvas for ID-1 faces (Aadhaar, PAN).
  ///
  /// Measured under the app theme with text scaling pinned: the Aadhaar front
  /// needs >= 406dp and the PAN front >= 426dp before their fixed-size content
  /// stops overflowing. 440 clears both with headroom, which matters because
  /// these faces have no flex give — a font with different metrics (main.dart
  /// falls back to one when Inter cannot load offline) shifts what they need.
  ///
  /// One canvas for every ID type keeps typography consistent between cards.
  static const Size idCanvas = Size(440, 440 / idAspect);

  /// Design canvas for the portrait passport face.
  static const double _passportW = 382;
  static const double _passportH = 570;
  static const Size passportCanvas = Size(_passportW, _passportH);

  /// Portrait passport booklet ratio, kept in step with [passportCanvas].
  static const double passportAspect = _passportW / _passportH;

  /// Design canvas for train and movie pass faces.
  ///
  /// Measured at 382dp wide with text scaling pinned: the train face lays out
  /// at ~597dp tall and the movie face at ~595dp. 620 clears both with room to
  /// spare. These faces size themselves from their content, so without a fixed
  /// canvas they simply grew past short viewports — badly in landscape.
  static const double ticketCanvasWidth = 382;
  static const double ticketCanvasHeight = 620;
  static const Size ticketCanvas =
      Size(ticketCanvasWidth, ticketCanvasHeight);

  /// Portrait ticket ratio, kept in step with [ticketCanvas].
  static const double ticketAspect = ticketCanvasWidth / ticketCanvasHeight;

  /// Design canvas for the train pass face.
  ///
  /// Taken straight from the Figma export rather than reusing [ticketCanvas]:
  /// the train card is narrower and taller (0.581 vs 0.616) and its layout is
  /// absolutely positioned, so it cannot be poured into a differently-shaped
  /// box without breaking every measured baseline. Retuning [ticketCanvas]
  /// instead would have dragged the movie face along with it.
  ///
  /// Train and movie passes therefore have different aspect ratios, which is
  /// safe: `tickets_tab.dart` gives each pass its own `PageView` page and
  /// [resolve] centres the card inside it, so pages need not match heights.
  static const double _trainW = 366;
  static const double _trainH = 630;
  static const Size trainCanvas = Size(_trainW, _trainH);

  /// Train pass ratio, kept in step with [trainCanvas].
  static const double trainAspect = _trainW / _trainH;

  /// Resolve the card box for the space available, honouring both axes and the
  /// tablet cap. Using only `maxWidth` (the previous behaviour) produced cards
  /// taller than the viewport in landscape and on short screens.
  static Size resolve(BoxConstraints constraints, double aspect) {
    double width = constraints.maxWidth;
    if (width > maxCardWidth) width = maxCardWidth;

    if (constraints.hasBoundedHeight) {
      final double widthFromHeight = constraints.maxHeight * aspect;
      if (widthFromHeight < width) width = widthFromHeight;
    }
    return Size(width, width / aspect);
  }
}

/// Renders [child] at a fixed design canvas, then uniformly scales it to fill
/// the available box.
///
/// Text scaling is neutralised inside the canvas on purpose. A card face is a
/// facsimile of a physical document with a fixed layout, and the whole face
/// already grows with the card — so honouring the system text scale here would
/// double-apply and reintroduce the overflow this widget exists to remove.
/// Readable, screen-reader-friendly copies of the same data live on the
/// document detail screens, which do respect text scaling.
class WalletCardCanvas extends StatelessWidget {
  const WalletCardCanvas({
    super.key,
    required this.designSize,
    required this.child,
  });

  final Size designSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: SizedBox(
          width: designSize.width,
          height: designSize.height,
          child: child,
        ),
      ),
    );
  }
}
