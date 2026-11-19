# Complete wallet at launch

Returning users should see complete document faces on the first Flutter frame,
without a spinner, fallback-font swap, missing emblem or reordered first card.
Prepare encrypted local records and saved order concurrently before runApp,
using the same Riverpod container that owns the live UI. Prepare bundled fonts
and artwork for the initial document pages before revealing the dashboard.
Keep onboarding independent of wallet reads. Keep network passes, weather,
add-menu artwork and maintenance outside the launch barrier. Remove the extra
dashboard entrance fade, without changing card gestures or other motion.

Do not cache document screenshots or write new plaintext records. Preserve
existing storage error handling and write interlocks. Asset failures must be
best-effort and cannot prevent launch. Verify delayed reads, persisted order,
single reads, failure paths, and existing startup/interaction tests. Windows can
build and smoke-test Android; iPhone startup timing requires an iOS device/Mac.

## Verification

122 targeted tests pass: boot readiness/order and asset failures, actual bundled
asset preparation before mounting a wallet, launch-only portrait byte reuse,
existing dashboard startup and close races, onboarding, bundled fonts, and card
layout regressions. Portrait handoff holds at most four encoded images in memory
and clears after the first frame; nothing new is written to disk.

The native launch surface remains until runApp can present the loaded wallet.
The extra 200ms dashboard entrance fade is removed, and saved theme settings are
used at initial construction rather than animated from device defaults. This
changes time to first complete content; no before/after latency improvement is
claimed without device measurements. ADB currently has no connected phone, and
iOS device/build verification is unavailable from this Windows workspace.
Scoped analysis is clean. The final arm64 debug APK built successfully at
`build/app/outputs/flutter-apk/app-debug.apk`; it was not installed because ADB
reported no devices after the build.
