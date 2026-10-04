const double kEasterEggPanelHeight = 176;
const double kEasterEggSnapThreshold = 0.56;
const double kEasterEggVelocityOpen = 650;
const double kEasterEggVelocityClose = -550;
const double kEasterEggMinimumOpenPull = 64;
const Duration kEasterEggSnapDuration = Duration(milliseconds: 360);
// Maximum extra travel beyond the resting position, as a fraction of the panel.
const double kEasterEggDrawerOvershootFactor = 0.28;

double weatherPanelHeight(double textScale) =>
    // At 2x text, a narrow screen wraps the greeting and location action into
    // several lines. Leave room for both above the revealed panel's bottom.
    kEasterEggPanelHeight + (textScale - 1).clamp(0.0, 1.5) * 190;
