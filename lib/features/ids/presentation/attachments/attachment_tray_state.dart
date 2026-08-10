/// Pure layout calculation functions for the attachment tray.
///
/// Keeps responsive height threshold logic and conditional visibility rules
/// unit-testable without mounting Flutter widget trees.
class AttachmentTrayLayout {
  const AttachmentTrayLayout._();

  /// Threshold below which the tray switches to compact geometry.
  ///
  /// This has to sit above the height the full layout actually needs, not at a
  /// round number. At 300 there was a dead band: a 320pt tray was not compact,
  /// so it laid out the 216pt hero plus roughly 162pt of chrome and overflowed
  /// its column by about 58pt.
  static const double compactHeightThreshold = 380.0;

  /// Full-size hero height.
  static const double standardHeroHeight = 216.0;

  /// Compact hero height for small viewports.
  static const double compactHeroHeight = 160.0;

  /// Floor for the hero, below which a preview stops being legible.
  static const double minHeroHeight = 110.0;

  // Chrome around the hero: each is the widget's own height plus the gap that
  // precedes it. Kept here rather than inline in the widget so the arithmetic
  // that guarantees the column fits is testable on its own.
  static const double captionBlock = 30.0; // caption + 12pt gap
  static const double counterBlock = 30.0; // counter + 12pt gap
  static const double stripBlock = 70.0; // 58pt strip + 12pt gap
  static const double hintBlock = 32.0; // hint + 14pt gap

  /// Returns true if [availableHeight] is constrained below [compactHeightThreshold].
  static bool isCompact(double availableHeight) =>
      availableHeight < compactHeightThreshold;

  /// Determines whether the "N of M" page counter should be displayed.
  static bool shouldShowCounter(int attachmentCount) => attachmentCount > 1;

  /// Determines whether the "Swipe to see more" hint should be displayed.
  static bool shouldShowSwipeHint({
    required int attachmentCount,
    required double availableHeight,
  }) =>
      attachmentCount > 1 && !isCompact(availableHeight);

  /// Total height of everything in the column except the hero.
  static double chromeHeight({
    required int attachmentCount,
    required double availableHeight,
  }) {
    double chrome = captionBlock;
    if (attachmentCount > 0) chrome += stripBlock;
    if (shouldShowCounter(attachmentCount)) chrome += counterBlock;
    if (shouldShowSwipeHint(
      attachmentCount: attachmentCount,
      availableHeight: availableHeight,
    )) {
      chrome += hintBlock;
    }
    return chrome;
  }

  /// Hero height that leaves room for the chrome actually being rendered.
  ///
  /// Derived from the space left over rather than picked from two fixed sizes,
  /// so there is no band of heights where the column asks for more than it has.
  static double heroHeight({
    required double availableHeight,
    required int attachmentCount,
  }) {
    final double ceiling = isCompact(availableHeight)
        ? compactHeroHeight
        : standardHeroHeight;
    final double free = availableHeight -
        chromeHeight(
          attachmentCount: attachmentCount,
          availableHeight: availableHeight,
        );
    return free.clamp(minHeroHeight, ceiling).toDouble();
  }
}
