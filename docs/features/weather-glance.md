# Weather glance

Polish the existing pull-down sky without changing the wallet's visual language.

- Keep scene previews in Settings → Developer and ignore them in release builds.
- Preserve finger tracking; stop settling motion on drag start, carry release velocity
  into a critically damped spring, and avoid rebuilding the wallet on every drag frame.
- Request foreground approximate location only after the user chooses local weather.
  No background tracking or persisted coordinates. Refresh on reveal/resume with a
  15-minute cache and keep recent data visibly marked when refresh fails.
- Use the backend `/v1/weather` Open-Meteo proxy. The owner selected its free
  non-commercial service; Railway `WEATHER_NON_COMMERCIAL=true` explicitly
  enables it without a key. If commercial use begins, switch provider terms or
  add a paid `WEATHER_API_KEY` on the server.
- Return timestamps, timezone offset, day/night, temperature and WMO conditions.
  Accept an optional UTC `at` for trip/event forecasts inside the 16-day horizon.
  No destination guessing or forecasts outside the provider horizon.
- Preserve interruptible scene blends, pause hidden sky tickers, add snow/fog, and
  use provider daylight rather than assuming that night starts at 21:00 everywhere.

Verification: Flutter analysis and meaningful widget/model/controller tests, rendered
sky inspection, Go tests/race checks, live Railway readiness/configuration audit.
Device gesture feel and iOS location require hardware follow-up.

The iOS host is intentionally gitignored in this Android-first repository.
Its local Info.plist has the foreground usage description. After regenerating
an iOS host, run `python tool/configure_weather_ios.py` before building.


Verification (1 October 2026): 26 focused weather/scene tests passed, including
shader frame inspection, interruptible transitions, reduced motion, permission
states, latest-target request races, and 320/390px layouts at 1x/2x text.
The broader full-suite run has 605 passes and two add-menu golden failures; weather
checks pass. Flutter analysis has no errors/warnings and four existing info lints.
Go full suite and go vet pass. Race instrumentation is unavailable because the
Windows host has no usable C runtime toolchain. A debug APK builds with a temporary
JDK; the globally configured Adoptium install is missing bin/java.exe.

The backend is deployed to staging and real current and trip forecast responses
were smoke-tested. A paid weather key is unnecessary for the selected non-commercial
use. Production still requires real Google auth setup. A physical handset was not connected; gesture feel and location prompts
still need a device review before calling the feature production ready.


Final motion handoff uses the derivative of the overpull rubber band so release
velocity matches the visible sheet. Added a separate ordinary-rain scene; drizzle,
rain, heavy rain, snow, fog and thunderstorms now have distinct rendering states.
The APK manifest removes the geolocator plugin's unused foreground tracking-service
permission; only approximate foreground location is requested for single fixes.

## Pull-down refinement — 1 October 2026

The Moto Edge 30 feedback came from a debug build; the Nothing Phone 3a had
also felt uneven during general navigation. This change focuses on the sky reveal.

- The complete dashboard, including navigation and Add, translates as one
  full-size surface. It never shrinks or reflows the wallet to make room.
- A single full-width clip replaces the scaled surface and corner shadow.
  The sky paints only the exposed height plus the corner allowance.
- Opening requires at least 64 logical pixels of deliberate travel. Slow
  releases commit beyond 56% of the panel; an already-open glance has a separate
  closing threshold. A rejected tiny flick cannot throw the sheet farther open.
- Overpull starts at finger speed and progressively resists, with bounded
  extra travel. Grabbing a settling overpull preserves its visible position.
  Release velocity follows the derivative of the resistance curve.
- The wallet stays behind a repaint boundary and its backdrop tickers pause
  during the reveal. The spring remains interruptible and respects reduced motion.
- The glance has 252px of space before large-text expansion. Sun and moon sit
  below the actual status-bar inset. Sparse, broken and overcast cloud patterns
  blend with the conditions; WMO 1 and 2 now have distinct visual coverage.
- Night uses a shaded, textured illustrative gibbous moon and faint stars.
  Its phase is decorative, not an astronomical measurement. Transient shader
  load failures can be retried on a later reveal.

Rendered clear/partial/overcast/night scenes and small/large-text summaries were
reviewed. Physical frame times are unmeasured: no phone is connected. Use the
profile APK to review gesture feel on the Moto, then the Nothing Phone 3a.

Final verification: all 30 focused weather/motion checks pass, including a
regression that keeps wallet interaction tickers active while the sky is open.
The isolated checkout's full analysis has no errors/warnings and four existing
info lints. Its ARM64 profile APK builds successfully and is copied to
`build/weather-polish/app-weather-profile.apk` (76,744,360 bytes).

The final package was built from `D:\dev\projects\docket_weather_app_release`,
based on committed responsiveness revision `6b5240d`, with the weather files
overlaid. An in-progress add-menu artwork change in the main workspace references
images that do not yet exist and blocked its rebuild; that work was preserved.


## Softer sky refinement

Restore the previous five-octave soft cloud style and remove the forced opaque
bank. Mostly cloudy and overcast retain different coverage without cut-out
edges. Drizzle uses short, fine, sparse drops; rain varies drop length, depth,
lane phase and speed; storm gusts and localized branching lightning add depth.
Unused rain/snow fields skip their per-pixel loops. Existing moon, safe-area sun
position, interruptible transitions and reduced-motion behavior stay covered.

Remove the provider button and local-location caption from the reveal. Keep
an "Updated earlier" notice for cached conditions. Settings > About > Weather
credits provides attribution, provider and licence links; the same weather
credit is registered in the app's licence registry.

The wallet surface corner radius now scales with screen width from 32 to 48
logical pixels (about 41 at 390px), instead of 24. This is a visual adaptive
radius, not a reading of the phone's physical display radius. The sky extends
48px below the reveal to cover the larger corner cutouts without a border.

Verification: 31 weather/provider/motion/Settings checks pass, including
rendered sky previews, interrupted transitions, localized lightning and
reduced motion. Layouts cover 320/390px and 1x/2x text. The initial full suite
reported 623 passes and four failures during concurrent add-menu work; a
recheck clears Passes menu and pass removal, leaving the two existing
Documents-menu golden mismatches. Device frame timing has not been measured.


The final stale-data/accessibility layout checks also pass (four cases), and
an arm64 profile APK builds successfully with the new sky, credits and pass
menu artwork. Hardware smoothness still needs validation on Moto Edge 30 and
Nothing Phone 3a.
