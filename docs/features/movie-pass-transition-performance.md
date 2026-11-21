# Movie pass transition performance and navigation

Status: implemented, verified, and installed on the Motorola. Frame pacing and
rendering spikes improved; initial debug build/layout delays remain measurable.

## Owner request

Remove stutters opening/closing movie passes while retaining the approved artwork
blend, sharp poster center, real entry codes, and original partner footer. Also
replace the app-wide upward/downward screen motion with consistent directional
push/back transitions. Actual bottom sheets should retain their sheet behavior.

## Baseline and cause investigation

- The connected Motorola is running the debug APK, with artwork blending enabled.
  Timings from this build are comparative diagnostics, not release benchmarks.
- Four warm open/close cycles were captured with Android SurfaceFlinger. Opens
  showed median presented-frame intervals around 25ms and maxima up to 59ms;
  closes showed median intervals around 17ms and maxima around 50ms. The display
  reported an 8.33ms refresh interval during these captures.
- VM timeline captures are recorded under `outputs/pass-blend-preview`. The
  experiment creates full-card and poster-halo image filters, two poster alpha
  masks, and route opacity compositing while the underlying wallet also animates.
- Bounding poster decode width does not bound the image filter's rendered output:
  the existing blur layers still cover large screen areas during the transition.
- `AppTheme` explicitly selects `FadeUpwardsPageTransitionsBuilder` on Android,
  and `studioPageRoute` independently implements another rise/fade transition.
  This accounts for the widespread vertical screen motion reported by the owner.

## Scoped implementation

1. Prepare small blurred artwork rasters once and let Flutter's ImageCache own
   their reuse and disposal. Retain cached network sources and bounded decoding.
   Draw the prepared images during transitions instead of recomputing large GPU
   blurs. Keep feather masks and sharp poster rendering intact.
2. Isolate the blended ticket's static paint so route motion can reuse it.
3. Use Android's directional Fade Forwards page transition and retain Cupertino
   transitions on Apple platforms. Route peer destinations through the same
   MaterialPageRoute/theme policy rather than a separate custom rise animation.
   Preserve bottom sheets, popup transitions, reduced-motion behavior, and normal
   back navigation; do not enable predictive-back previews as part of this fix.
4. Verify image/cache lifecycle, poster ratios, real codes, footer invariants,
   normal navigation/back and route interruption. Inspect actual Flutter renders.
5. Install over the existing debug app and repeat the same device interactions.
   Report measured improvement and any remaining debug/device limitations.

## Implementation and verification

- `MovieBlurredArtwork` prepares a raster of at most 128 x 256 pixels. The cache
  key includes the source, dimensions, fit, blur radius, and overscan. Flutter's
  existing bounded ImageCache owns its lifetime; there is no separate unbounded
  bitmap cache. Three blur radii of transparent padding preserve the halo's soft
  overflow instead of introducing a hard rectangle below the poster.
- The sharp poster, its perimeter masks, ticket geometry, experimental preference,
  original partner footer, and entry-code controls are retained. Blended ticket
  faces have a repaint boundary, and the onscreen background/halo no longer use
  full-size `ImageFiltered` layers.
- Android regular routes now use `FadeForwardsPageTransitionsBuilder` through
  the theme. `studioPageRoute` uses `MaterialPageRoute` so it follows the same
  policy. Cupertino transitions and separately presented sheets remain intact.
- A cold/hot restart exposed a profile-button assertion during preference
  hydration: an AnimatedContainer interpolated between a rounded rectangle and
  `BoxShape.circle`, producing an invalid circle with a border radius. Its shadow
  now interpolates compatible rounded rectangles, retaining the circular endpoint.
- 173 targeted regression tests passed, covering cache reuse/eviction, a route
  closing before artwork preparation finishes, push/back direction, interrupted
  navigation, profile-shape hydration, both movie variants, poster sizing, footer
  invariants, entry codes, wallet layouts, settings, sharing, and tab transitions.
- The manual Flutter render harness also passed. Dune and Odyssey expanded
  renders were inspected after adding blur padding; both retain the sharp poster
  center, feathered edges, readable metadata, and original partner marks.
- Final analysis of the eleven changed source/test files reported no issues.
  The Android arm64 debug APK built successfully, and its kernel was checked
  for the prepared-artwork implementation before installation.
- Device measurements are retained under `outputs/pass-blend-preview`. The
  `measure_transitions.py` diagnostic records SurfaceFlinger presented intervals
  and VM raster durations across four open/close cycles. The first cycle includes
  cold setup and is excluded from warm comparisons. These debug captures include
  surrounding wallet frames and are not isolated release-mode frame benchmarks.

## Installed device result (21 November 2026)

- Reconnected to the owner's Motorola Edge 30 over wireless ADB. Captured a fresh
  baseline from the currently installed debug app before replacing it, rather
  than comparing only with the previous day's captures.
- Installed the verified Android arm64 APK using `adb install -r`, launched it
  cold, and confirmed that the loaded VM contains the prepared-artwork provider.
  The enabled `experimental_movie_artwork_blend` preference was retained. No
  uninstall or data clearing was performed.
- Repeated four Dune open/close cycles before and after installation. Excluding
  the first cycle, the median of the three per-cycle median presented intervals
  was 25.17ms before / 16.79ms after for opening, and 16.80ms / 8.39ms for closing.
  Both runs reported an 8.33ms display refresh interval.
- Across the three warm capture windows, the engine's `SurfaceFrame::Encode`
  95th-percentile duration decreased from 34.92ms to 8.46ms on opening and from
  25.11ms to 10.11ms on closing. Median `GPURasterizer::Draw` was 13.52ms / 11.42ms
  for opening and 13.13ms / 10.72ms for closing. Route durations and frame counts
  differ, and these windows include surrounding wallet activity; these results
  demonstrate reduced rendering spikes, not a release-performance guarantee.
- Long opening intervals still appear in debug mode. An additional instrumented
  layout trace attributes the remaining startup delay to building/layout of the
  new route, rather than the removed full-size artwork filters. Layout profiling
  was disabled immediately after that diagnostic. Do not describe every stutter
  as eliminated or interpret a presented-frame gap as exclusively GPU work.
- Inspected the installed expanded Dune poster and movie wallet rendering.
  Normal Android back and an opening reversed after 100ms returned safely to the
  wallet. No Flutter exceptions, render overflows, or Android fatal exceptions
  appeared in the scoped application logs during these checks. The app was left
  open on the Dune wallet card for the owner's review.
