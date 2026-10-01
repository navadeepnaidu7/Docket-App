import 'easter_egg_constants.dart';

abstract final class EasterEggSheetMotion {
  /// Resistance starts at the finger's speed, then increases continuously.
  static double rubberBandOffset(
    double rawOffset, {
    double panelHeight = kEasterEggPanelHeight,
  }) {
    if (rawOffset <= 0) return 0;
    if (rawOffset <= panelHeight) return rawOffset;
    final range = panelHeight * kEasterEggDrawerOvershootFactor;
    final over = rawOffset - panelHeight;
    return panelHeight + over * range / (range + over);
  }

  static double rawOffsetForVisible(
    double offset, {
    double panelHeight = kEasterEggPanelHeight,
  }) {
    if (offset <= panelHeight) return offset.clamp(0.0, panelHeight);
    final range = panelHeight * kEasterEggDrawerOvershootFactor;
    final over = (offset - panelHeight).clamp(0.0, range - 0.01);
    return panelHeight + over * range / (range - over);
  }

  static bool shouldSnapOpen({
    required double offsetY,
    required double velocityY,
    double panelHeight = kEasterEggPanelHeight,
    bool wasOpen = false,
  }) {
    // A quick accidental tug must never throw the entire screen open.
    if (!wasOpen && offsetY < kEasterEggMinimumOpenPull) return false;
    final double threshold =
        panelHeight * (wasOpen ? 0.42 : kEasterEggSnapThreshold);
    if (velocityY > kEasterEggVelocityOpen) return true;
    if (velocityY < kEasterEggVelocityClose) return false;
    // A short projection makes a deliberate gentle flick count, too.
    return offsetY + velocityY.clamp(-650.0, 650.0) * 0.10 > threshold;
  }

  /// The spring inherits the velocity of the visible sheet, which is lower
  /// than finger velocity while the rubber band is resisting overpull.
  static double releaseVelocity({
    required double rawOffset,
    required double velocityY,
    double panelHeight = kEasterEggPanelHeight,
  }) {
    if (rawOffset <= 0 && velocityY < 0) return 0;
    final over = (rawOffset - panelHeight).clamp(0.0, double.infinity);
    if (over == 0) return velocityY;
    final range = panelHeight * kEasterEggDrawerOvershootFactor;
    final resistance = 1 + over / range;
    return velocityY / (resistance * resistance);
  }
}
