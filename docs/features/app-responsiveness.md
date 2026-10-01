# App responsiveness

Scope: wallet scrolling and gestures, portrait decoding, and pass-provider
invalidation. Weather and the dashboard shell are being edited in another session
and are outside this change.

## Confirmed issues and implementation

- Card tilt resets immediately on release. Ease back from the live tilt, allow a
  new touch to interrupt, keep vertical swipes available to PageView, and respect
  reduced motion. Track one pointer so a second finger cannot flip the card.
- The ID carousel resets to page zero whenever the visible IDs change. Retain
  the focused document when it survives a mutation; otherwise choose the nearest
  remaining card. Explicit filter changes still start at the first card. Give
  pages stable keys and map them to current indices. Refresh cached ID faces
  when document data changes, including an edit that keeps the same document ID.
- ID shine wrappers rebuild on every PageController notification, and shine
  rebuilds its CustomPaint every animation frame. Update focus only on page
  changes, stop shine during scrolling, paint from animation listenables, and
  isolate the static card from the moving border.
- Large base64 portraits decode synchronously when a card mounts. Keep small
  payloads synchronous; decode large payloads on a native background isolate,
  with stale-result guards and the existing malformed-image fallback.
- Pass repositories and API clients watch every developer flag, so changing a
  visual setting reloads passes. Select only repository/client configuration.

## Verification

Add behavioral regressions for gestures, focus retention, large-image races,
and visual-setting changes. Run Flutter analysis and the full test suite.
Frame-time improvements require profile-mode measurements on a physical phone;
no Android/iOS device is currently connected. Do not claim measured FPS gains.

## Device follow-up

Run `flutter run --profile` on a physical phone, using the same wallet and device
for a before/after comparison. In DevTools record cold entry, ten vertical card
swipes, rapid card flips, opening/closing Settings, and adding/removing a card.
Separate UI and raster frame time, and report p90/p99 plus frames exceeding the
device's refresh budget (16.7 ms at 60 Hz, 8.3 ms at 120 Hz). Check reduced motion
and confirm that a second touch can interrupt a tilt release. A debug-mode FPS
reading is not sufficient evidence of a production improvement.

The rendering changes follow Flutter's guidance on
[isolating repaint work](https://api.flutter.dev/flutter/widgets/RepaintBoundary-class.html)
and [moving CPU work off the native UI isolate](https://docs.flutter.dev/perf/isolates).
`compute` uses the current event loop on web; the portrait-isolate improvement is
specific to native platforms.

## Verification results (2026-10-01)

- Final focused run: 40 passed, one existing Manage row-tap test failed because
  `ink_sparkle.frag` contained Vulkan stages while the test backend required SkSL.
  All new gesture, portrait, provider, shine-painting, and carousel regressions
  passed, including editing a mounted ID and retaining focus across reorder.
- Full-suite attempt: 593 passed, 32 failed. This ran while other sessions edited
  bus/weather files and compiled shared assets. Failures included transient bus
  compile errors, shader-backend mismatches, font-loading errors, and an overly
  strict new assertion about retaining widget state across offscreen reorder.
  That assertion was corrected to check the intended focus behavior; a separate
  mounted-edit test verifies face refresh without remounting. The final focused
  run verifies both. The full suite is not green and needs a stable build run.
- Final `flutter analyze`: no errors or warnings; four informational findings
  in the untouched settings and NFC files. No findings in this change's files.
- `git diff --check` passed for changed tracked implementation/test files.
- No physical-device profile or FPS measurement performed.

Local run logs are in `terminals/responsiveness-focused.log`,
`terminals/responsiveness-tests.log`, and `terminals/responsiveness-analysis.log`.
