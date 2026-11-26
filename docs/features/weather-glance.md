# Weather glance

The pull-down sky above the wallet: local weather, then the next upcoming pass.

Status: implemented; device gesture feel and iOS location still need hardware review.
Owners: `DashboardScreen` (drag, spring, `_animateWeather`),
`lib/features/dashboard/presentation/widgets/` (`easter_egg_constants.dart`,
`easter_egg_drawer.dart`, `travel_weather_glance.dart`, `weather_soft_transition.dart`),
`lib/features/weather/` (`weather_provider.dart`, `weather_glance_session.dart`,
`local_weather_drawer.dart`), shader `assets/shaders/docket_sky.frag`. Backend:
`GET /v1/weather` in `../docket_server`.

## Opening and closing

- **Manual only.** The glance opens when the user pulls the dashboard down. It does not
  open by itself at launch: `WeatherGlanceSession.scheduleOpening()` still exists and is
  tested, but `DashboardScreen` does not call it (calm-startup decision, 29 Oct 2026; see
  `startup.md`). Re-enabling it is a product decision, not a bug fix.
- The whole dashboard, navigation and Add included, translates as one full-size surface. It
  never shrinks or reflows the wallet. One full-width clip; the sky paints only the exposed
  height plus the corner allowance.
- Panel rests at 176 logical px (`kEasterEggPanelHeight`), growing with text scale
  (`weatherPanelHeight`). Opening needs 64 px of deliberate travel; slow releases commit past
  56%; fling thresholds +650 / -550 px/s; an already-open glance has its own close threshold.
- Overpull starts at finger speed and resists progressively (bounded at 0.28 of the panel).
  Release velocity follows the derivative of that curve so the spring continues the visible
  motion. Grabbing a settling sheet keeps its position. The spring is interruptible and
  respects reduced motion.
- The wallet sits behind a repaint boundary and its backdrop tickers pause during the
  reveal. Wallet surface corner radius scales with screen width (32-48 px) and does not
  change with pull progress.

## Reading sequence (after a manual open)

`WeatherGlanceSession.openedManually()` starts the reading time once refreshing finishes:
weather for 3 s, then the nearest upcoming pass (`nextUpcomingPass`) for the rest of 7 s,
then the wallet glides back. Touch pauses the timer; routes, dialogs, backgrounding and
disposal cancel scheduled movement. Network waits do not consume reading time. With no
eligible pass, weather stays for the whole period. Event copy describes pass times, never
venue forecasts.

Refresh frosts the exposed weather area with an 8 px blur (no label, no tint) that resolves
over 760 ms; overlapping refreshes cannot clear the latest request's veil. The pass text
replaces weather through a blur dissolve (heading first, detail ~60 ms later, 760 ms, 4 px
travel) while the sky stays mounted and defocuses behind it. The opening pull also resolves
the sky and summary from a haze that follows progress both ways; actions become available at
95%. Blur covers weather material only, never the wallet, and is off at rest and under
reduced motion.

## Privacy and data

- Foreground approximate location, requested only after the user chooses local weather.
  No background tracking, no persisted coordinates. The manifest strips geolocator's
  foreground-service permission.
- 15-minute cache, refreshed on reveal/resume. Cached conditions stay visible during a
  refresh; stale data is marked "Updated earlier" when refresh fails.
- Provider: the backend's Open-Meteo proxy, free non-commercial tier (Railway
  `WEATHER_NON_COMMERCIAL=true`, no key). If Docket ever goes commercial, change provider
  terms or set a paid `WEATHER_API_KEY` server-side. Optional UTC `at` serves trip/event
  forecasts inside the 16-day horizon; nothing outside it, no destination guessing.
- Day/night comes from provider daylight, not a fixed 21:00. Attribution: Settings ->
  About -> Weather credits, also registered in the licence registry.

## Rendering

Shader scenes: clear, partly/mostly cloudy, overcast, fog, snow, drizzle, rain, heavy rain,
thunderstorm (localized branching lightning), plus an illustrative gibbous moon (phase is
decorative, not astronomical). Scene changes blend over 800 ms and are interruptible; sky
tickers pause when hidden; unused rain/snow loops are skipped. A shader load failure falls
back to a gradient and is retried on a later reveal.

## Testing aids

Settings -> Developer -> Weather glance preview (debug/profile only; ignored in release):
session-only scenes and "Movie in 4 hours" / "Train in 2 days" previews with a simulated
900 ms refresh, no location or network.

iOS: the host is gitignored in this Android-first repo. After regenerating it, run
`python tool/configure_weather_ios.py` to restore the location usage description.

## Still unverified

Physical frame timing and gesture feel (Motorola Edge 30, Nothing Phone 3a, profile build),
iOS location prompts. Go race checks have not run (no C toolchain on the Windows host).
