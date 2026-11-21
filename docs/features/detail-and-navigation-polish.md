# Detail size and navigation polish

## Requested changes

- Make the lower detail UI slightly larger while keeping document, payment and
  ticket details aligned with each other.
- Replace the thin eye/copy action icons with stronger rounded glyphs.
- Smooth the IDs/Passes handoff, including quick reversals and reduced motion.
- Disable Android predictive back throughout the app; retain normal back and
  existing draft/overlay back handling.

## Implementation plan

- Increase the main shared detail roles by 1dp, add a little row breathing room,
  and enlarge the eye/copy glyphs while preserving their 48dp touch targets.
- Keep both wallet tabs' existing state and lazy first mount. Use a brief
  crossfade with smaller translation, isolate each wallet's paint, and drive
  content, nav indicator and backdrop tint from the same controller timeline.
- Honor reduced motion without lateral translation. Make rapid selection
  changes continue from the current animation value.
- Disable enableOnBackInvokedCallback in the app manifest and explicitly use
  a conventional Android page transition in both themes. Keep PopScope guards.
  Route the profile detail through MaterialPageRoute so Android uses that same
  policy while iOS keeps its platform transition.

## Verification

- Detail copy/reveal and light/dark golden checks; narrow/large-text layout.
- Tab animation handoff, interruption, pointer/semantics gating, retained state,
  ticker suppression and reduced-motion checks.
- Manifest/theme verification, native APK build, install over the current app,
  and physical-device checks of details, repeated tab switches and normal back.

## Verification results (19 Nov 2026)

- 45 focused tests pass across tab handoff/reversal, backdrop synchronization,
  retained state, reduced motion, startup, back navigation, typography, copy/
  reveal and narrow layouts. After the final filled-copy glyph change, all 19
  relevant detail/navigation/font tests pass again without updating goldens.
- Reviewed updated light/dark detail goldens. Main rows are 14dp, headings 16dp,
  action glyphs 22dp; original touch targets, masking and timers remain intact.
- Analysis of `lib` and `test` reports the same four existing info-level notices.
  A final check of the changed detail/navigation files reports only the existing
  Settings `cacheExtent` deprecation.
- Final arm64 profile APK builds successfully at
  `build/app/outputs/flutter-apk/app-profile.apk` (92.3 MB). `aapt2` confirms the
  packaged `enableOnBackInvokedCallback` attribute is false.
- Physical-device installation and motion/back checks are pending: wireless ADB
  disconnected during compilation. The user has been asked to reconnect.
  The phone's original 60-second screen timeout must be restored on reconnect;
  it was temporarily set to 10 minutes for this verification session. Original
  predictive-back developer setting was 0; it has not been changed.
