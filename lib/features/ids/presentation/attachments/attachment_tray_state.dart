/// Pure layout calculation functions for the attachment tray.
///
/// Keeps responsive height threshold logic and conditional visibility rules
/// unit-testable without mounting Flutter widget trees.
class AttachmentTrayLayout {
  const AttachmentTrayLayout._();

  /// Threshold below which the tray switches to compact hero geometry.
  static const double compactHeightThreshold = 300.0;

  /// Full-size hero height.
  static const double standardHeroHeight = 216.0;

  /// Compact hero height for small viewports.
  static const double compactHeroHeight = 160.0;

  /// Returns true if [availableHeight] is constrained below [compactHeightThreshold].
  static bool isCompact(double availableHeight) =>
      availableHeight < compactHeightThreshold;

  /// Calculates the appropriate hero preview height given [availableHeight].
  static double heroHeight(double availableHeight) =>
      isCompact(availableHeight) ? compactHeroHeight : standardHeroHeight;

  /// Determines whether the "N of M" page counter should be displayed.
  static bool shouldShowCounter(int attachmentCount) => attachmentCount > 1;

  /// Determines whether the "Swipe to see more" hint should be displayed.
  static bool shouldShowSwipeHint({
    required int attachmentCount,
    required double availableHeight,
  }) =>
      attachmentCount > 1 && !isCompact(availableHeight);
}
