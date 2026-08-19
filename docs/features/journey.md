# Journey — a visual memory atlas

Branch: `worktree-journey-atlas` (off `master` @ `5c2c05c`) · PR [#35](https://github.com/navadeepnaidu7/Docket-App/pull/35) (draft)
Status: **PLANNED — parked on 19 Aug 2026, deliberately not merged.**

> A working v1 exists on the branch above and is not going to master yet. The
> call was made after seeing it run: it works, but it does not reach the product
> vision in section 1, and shipping a globe that is merely functional would set
> the wrong bar for a feature whose whole point is that it feels expensive.
>
> **Nothing here is abandoned or blocked.** The branch is green — `flutter
> analyze` clean, 501 tests pass, debug APK builds with both assets bundled.
> Resume by reading section 10 first; it is the only part written for someone
> picking this up cold.

Everything below section 1 is the original spec, kept intact as the statement of
intent, with a revision log in section 9 recording where the build deviated.

## Context

Docket knows where you have been. It holds train tickets between six Indian cities,
movie tickets from eleven cinemas, a passport with a place of birth and a place of
issue. None of that is currently visible as *place*. The wallet shows documents; the
archive shows counts and months. Nothing in the app answers "where have I been."

Journey is that answer: a globe you explore to revisit where you went and what you did
there. It is **not a map and not for navigation**. It is a memory atlas — calm, premium,
slow. The feeling to hit is opening something, not operating something. The user should
finish a session thinking "I was exploring my story," never "I was using a map."

This document is the product spec, and it is the authority on intent. Where an
implementation detail below has since been revised, the revision is recorded here rather
than only in the code.

---

## 1. What Journey is

A globe with **four discrete levels**. No free zoom. You descend by tapping, and the
camera flies.

| Level | What the globe shows | What the markers are |
|---|---|---|
| **World** | Earth's landmass as a dot field. No borders, no political lines. | One cluster per country. Flight arcs sweep between them. |
| **Country** | The country fills the view; simplified state outlines fade in. | One cluster per state or region. |
| **Region** | A state. Borders still drawn. | One cluster per city, with a count. |
| **City** | The surface, near-flat under the camera. | **Individual memories as Apple-Maps-style pins.** Tapping one raises its card. |

City is the floor. There is no street level, no district boundaries, no building
detail. The globe is context, never the content.

### What it is not

- Not a navigation tool. No search, no directions, no "find near me", no current location.
- Not a heatmap or a data dashboard. Density is not the point; recollection is.
- Not exhaustive. It reveals just enough to be meaningful at each level and withholds
  the rest until you descend.

---

## 2. The interaction model

**Tap to descend.** Tapping a cluster flies the camera to it and swaps in the next
level's markers. A back affordance rises at top-left whenever you are below world level;
Android system back does the same thing.

**Pinch is not a zoom.** At most it nudges and springs back. Levels are the only way
through, which is what keeps every interaction purposeful and keeps the frame budget
predictable — level-of-detail changes happen at known moments rather than every frame.

**Drag rotates** the globe at world and country level. At city level the camera is
effectively looking down at the ground and drag does nothing.

**The globe idles.** At world level, before the first touch, it rotates once every ~120
seconds. It stops permanently on first interaction. It starts 480ms after the first
frame, matching `WalletBackdrop`, so the opening frames stay free for layout.

### The camera flight is the feature

This is where premium is won or lost, and it is three separate channels, each with its
own curve. One shared curve is exactly what makes an interpolated camera feel cheap.

- **Target — great-circle slerp** between the two points on the sphere, eased with the
  house curve `easeOutQuint`, so rotation settles early and the descent finishes calmly.
  Never interpolate latitude and longitude as scalars: the path visibly curves and it
  breaks across the antimeridian.
- **Altitude — an arc, not a ramp.** The camera pulls back, then swoops in:
  `lerp(from, to) + arcLift · sin(pi · t)`, where the lift scales with angular distance.
  A hop between two Bengaluru cinemas barely lifts. A hop from India to Europe pulls way
  back and comes down. This single behaviour does most of the work of feeling expensive.
- **Duration scales with distance** — roughly 520ms near, 1000ms far. A fixed duration
  makes short hops sluggish and long ones rushed.

Roughly twenty numbers control all of this, and the entire distance between "Apple" and
"school project" lives in them. They belong in one file, `journey_motion.dart`, next to
where `easeOutQuint` already lives, and they should be tuned on a real device through a
debug-only slider overlay behind the existing Developer flag — not by editing constants
and hot-reloading blind.

---

## 3. The data model

### One idea removes every special case

**Every memory is an ordered list of stops.** A movie has one. A train has origin, up to
eight sampled halts, destination. A flight has two. The renderer never asks what kind of
pass produced a memory — it asks how many stops resolved to real coordinates:

- one resolved stop → a point memory (a pin)
- two or more → a route, with arcs between consecutive stops

A train whose destination cannot be resolved degrades to a point memory at the end that
did resolve. No branch, no fallback path to maintain.

`JourneyEvent` therefore knows nothing about `WalletPassItem`. That ignorance is what
makes flights free later.

### Flights are mocked in v1 — deliberately

`PassKind` is `{train, movie, bus}`. Flights are **not** a pass kind and will not become
one in this work. Instead `mockFlightEventsProvider` returns `JourneyEvent`s directly, so
the world level has real arcs to draw and can be judged.

When a real `FlightPassItem` eventually lands, the sealed-class switch inside
`buildJourneyIndex` **stops compiling** — a loud failure in exactly the right file — one
case is added, and the mock provider returns empty. Nothing downstream changes, because
nothing downstream knows what a flight is.

Record this in `docs/current_state.md` and in `docs/features/journey.md` under a clear
heading, so a later session picks it up without archaeology.

> Related trap, worth one line of test now: `PassKind.fromJson` maps any unknown value to
> `train` (`pass_status.dart:62`). The first time the server sends `"flight"`, Journey
> will draw a rail arc between two airports and nothing will error. Pin the current value
> in a test with a comment naming Journey as the affected consumer, so the eventual change
> is deliberate rather than discovered.

### Places: from display strings to coordinates

The app's geography today is display text authored for card faces — `'Vijayawada Jn
(BZA)'`, `'Phoenix Marketcity, Whitefield, Bengaluru'`, `'CHENNAI'` — three encodings of
"a place" with no shared type and no key. There is no latitude or longitude anywhere in
the repo, and `docs/api/passes.md` has no location field either.

So: **one canonical `Place` type behind a `PlaceResolver` interface**, backed in v1 by a
curated table bundled with the app (~260 rows, ~30KB JSON). No network, no geocoding
package, no API key on a local-first documents app.

`lookup` is **synchronous**. That is the load-bearing decision: it lets the whole index be
a pure synchronous fold in a plain `Provider`, matching how `spaceArchiveAnalyticsProvider`
already works. A future server-backed resolver still fits — it does its I/O in
`ensureReady()` and invalidates the provider.

Resolution order is exact code, then exact normalized name, then alias, then null.
**No fuzzy matching** — fuzzy matching is how a movie in Bengaluru ends up pinned to
Bangladesh. Aliases (Bangalore/Bengaluru, Bombay/Mumbai, Delhi/NDLS/NZM) live in the
table as data, not in code.

Each row carries `cityId`, `regionCode` and `countryCode`. **The table is the hierarchy**,
which means clustering is a hash-map grouping by key, not a spatial algorithm.

### When a place cannot be resolved

The house rule already exists: `MoviePass.resolvedPosterUrl` is nullable and "no poster"
is a normal state that renders a gradient. Same posture here.

- Unresolved intermediate stop → skipped; the arc bridges to the next resolved one.
- Unresolved endpoint → the memory degrades to a point.
- Nothing resolves → the memory goes to `JourneyIndex.unplaced`. **It is never dropped.**
  It surfaces as a "N memories without a place" row at the foot of the level sheet,
  tappable to a plain list, and it counts in totals.

A pass that silently vanishes from the globe is the failure this is designed against.
A resolution report (attempted / resolved / missed) rides along and is exposed under
Settings → Developer — it costs one counter and it is how you find out the cinema-address
heuristic broke on real extracted data.

---

## 4. How the globe is drawn

**Land is a dot field, not polygons.** The world level draws Earth's landmass as points —
calm, graphic, and an evolution of the dot globe the app already ships (whose "continents"
are currently `sin*cos*sin` noise). Borders appear **only on descent**: simplified India
state outlines fade in at country level and below. No political lines at world level.

**Coastline polygons never ship.** They are consumed offline by the generator to decide
which sphere points are land, then discarded. The dot field *is* the landmass. This keeps
the asset small and removes a whole class of runtime geometry.

**The asset** is Natural Earth 1:110m (public domain), world land plus India state lines
only, quantized to int16 and precompiled by `tool/generate_journey_atlas.py` into a
~60KB binary — well inside budget. Other countries' regions get added when journeys go
there. Runtime decode happens in an isolate via `compute()`, following
`attachment_store.dart`, because it lands on the one frame that must not jank.

If the asset fails to load or fails its checksum, the globe renders a **wireframe
fallback** — rim, graticule, arcs and markers, no land. It still tells the truth about
where you have been. Missing data is a normal state.

### The 60fps rule

**Sphere-space geometry is precomputed and immutable. Screen space is per-frame and
written into reused buffers.** Every performance decision follows from that one line.

Concretely: land dots are stored as precomputed unit vectors, projected into preallocated
`Float32List`s, binned into five depth buckets, and drawn as **five `drawRawPoints` calls
for the entire planet**. Arcs are sampled once in sphere space and only projected per
frame. Markers hoist their `Paint` objects and cache their `TextPainter`s. City pins are
decluttered once when the camera settles, then held — running it per frame makes pins
jitter.

Worst case is roughly 100 draw calls and 4000 projected points with zero allocation
inside `paint()`. For scale, the painter this replaces allocates ~600 `Paint` objects per
frame and ships today.

Layers are split by repaint rate under separate `RepaintBoundary`s — atmosphere, surface,
arcs, markers — so a pulsing pin does not re-rasterize the planet. Riverpod holds the
*destination* camera; the in-flight interpolated camera lives in an `AnimationController`
read through an `AnimatedBuilder`. Putting a 60fps value in a provider would rebuild every
consumer sixty times a second. Never a raw `Ticker` + `setState`:
`wallet_card_shine_border.dart:43-45` records that starving input this way already cost
this project once.

---

## 5. Where it lives

**A fourth `DashboardViewMode`**, appended last: `{ home, manage, trash, journey }`. Four
exhaustive switches must gain a case, and the compiler names all four — pure loud failure.
Picker order becomes `[manage, home, journey, trash]`: Journey sits beside Home because it
is a view of your things; Trash stays terminal. Menu height derives itself.

The bottom island (pill tab bar + add button) already slides away for any non-home mode,
so Journey gets full-bleed for free.

**Full-bleed needs care.** Each view sits in a `Column` under the header, so a globe that
stops below the header will look cheap. Do not restructure that `Column` — it is a
high-blast-radius change to a 2.3k-line screen for a cosmetic win. `JourneyView` instead
renders its own `Stack` with the globe in an upward-expanding `OverflowBox`. System bars
are already fully transparent. **Check this on device early** — it is the one real visual
risk in the integration.

**The teaser** goes on `user_card_detail_screen.dart`, the live "wrapped" story deck, as a
fourth story page: "You have been to N cities across M states," over the *same production
painter* at ~120px with a teaser preset — coarsest dot band, no borders, no arcs, no
gestures, slow rotation. Reusing the real painter keeps it in sync and makes it truthful
rather than decorative.

**Two files get deleted** in the same change: `space_archive_screen.dart` (747 lines,
hardcoded `'July 2026'`, **nothing imports it**) and `dot_globe_painter.dart` (imported
only by that dead screen). Do not confuse `space_archive_screen.dart` (dead) with
`space_archive_provider.dart` (live — the teaser page watches it).

---

## 6. Build order

Split by how a mistake fails, per CLAUDE.md: loud (compiler or test catches it) is
delegable, silent (wrong code still looks right) is hand-written.

| # | Phase | Failure mode |
|---|---|---|
| 0 | Copy this spec to `docs/features/journey.md` | — |
| 1 | Domain types, query parser, `buildJourneyIndex` + tests | **Mixed** — types loud, the address/station parser silent |
| 2 | Projection + camera math as free functions | **Silent** — hand-write |
| 3 | First pixels: dot-field painter, procedural sphere, no asset; wire the 4th view mode | **Loud** |
| 4 | Asset pipeline: Python generator, binary decoder, isolate, wireframe fallback | **Silent** — hand-write |
| 5 | Places table: CSV master, generator, resolver | **Mixed** — the curation is silent |
| 6 | Camera flights, level descent, clustering providers | **Mixed** |
| 7 | Arcs + mock flight fixtures — the world level becomes demonstrable | **Loud** |
| 8 | City pins, declutter, memory cards in the existing morph sheet | **Mixed** |
| 9 | Teaser page; delete the two dead files | **Loud** |
| 10 | Perf pass on a real device; update `docs/current_state.md` | — |

Something real is on screen by phase 3, before any asset or data work exists.

### Critical files

- `lib/features/dashboard/presentation/dashboard_screen.dart` — enum `:48`, view switch
  `:656`, bottom island `:812`
- `lib/features/dashboard/presentation/widgets/view_picker.dart` — modes list `:117`,
  title switch `:195`; and `widgets/dashboard_header.dart:115`
- `lib/features/dashboard/presentation/widgets/wallet_backdrop.dart` — **the perf
  template**: `RepaintBoundary`, deferred controllers, `TickerMode`, cheap `shouldRepaint`
- `lib/features/dashboard/application/space_archive_provider.dart` — the derived-data
  `Provider` pattern the journey index copies
- `lib/features/tickets/domain/pass_activity_date.dart` — `PassActivityDate.of()` already
  resolves a `DateTime` for any pass and is unit-tested. **Reuse it, do not rewrite it.**
- `lib/features/tickets/domain/pass_catalog.dart` — the sealed `WalletPassItem`, the
  compiler-enforced seam where flights will slot in
- `lib/features/tickets/data/mock_pass_fixtures.dart` — the ground truth the place table
  must resolve 100% of
- `lib/shared/widgets/morph_sheet.dart` — `showMorphSheet` already does cluster-to-detail
  drilling with a morphing height. No new sheet type is needed.
- `lib/core/storage/attachment_store.dart` — the only `compute()` precedent in the repo
- `tool/generate_launcher_icons.py` — the `tool/` generator precedent
- `lib/core/assets/app_assets.dart` and `asset_licenses.dart` — asset paths and in-app
  licences both need entries; `ATTRIBUTIONS.md` covers the repo, not the installed APK

---

## 7. Verification

**Unit** — the pure functions carry this feature, per the `membership_mesh_test.dart`
precedent of testing a painter's math rather than its pixels:
- projection: equator, poles, antimeridian; `horizonZ(d) == 1/d`; the fast batch path
  agrees with the readable reference to 1e-4 over thousands of random points
- camera: slerp stays on the unit sphere at every `t`; endpoints exact; mid-flight
  altitude exceeds both endpoints for far pairs and not for near ones
- spherical centroid (averaging lat/lng is wrong near the antimeridian and the poles)
- `declutter()` separates overlapping pins without drifting them off their city
- `buildJourneyIndex` against a `FakePlaceResolver`, including every degradation path

**The highest-leverage test in the feature:** every `fromCode`, `toCode`, halt string and
cinema address in `mock_pass_fixtures.dart` resolves to a place. It turns curation gaps
into a red test. It already has a known catch waiting — fixture `mock_t1` uses `BLR`, an
airport IATA code, where every other fixture uses a station code.

**Data sanity** — every table row falls inside its declared country's bounding box; the
decoded atlas passes known-land / known-ocean probes (Kanyakumari is land, mid-Pacific is
not, Antarctica present at the coarsest band) and its dot count matches the generator's
non-bundled debug sidecar.

**Golden** — a static camera over India in both themes, following
`test/add_menu_golden_test.dart` (pinned `physicalSize`, `devicePixelRatio = 1.0`, real
asset warm-up inside `tester.runAsync` before `pumpWidget`).

**Whole suite** — `flutter analyze` and `flutter test` after every phase. Current baseline
is 422 tests passing in ~10s.

**Performance** — there is no `integration_test` dependency and there are zero perf tests
today. Do not add the dependency for this. Measure with `flutter run --profile` on a real
mid-range device, DevTools performance overlay plus `--trace-skia`, along a scripted path:
world → country → region → city → back → back → back. Record the numbers in the
`docs/current_state.md` verification log, which is the existing convention. A repeatable
CI gate is a separate, deliberate investment — flag it, do not smuggle it in here.

**Cannot be verified from a dev machine:** on-device feel of the camera flights, real
frame timing, and how the full-bleed globe sits against the header and system bars.

---

## 8. The three things most likely to go wrong

**1. The place table is the whole feature, and it is hand-curated.** If coverage is thin
the globe is empty, and every later phase becomes unverifiable — you cannot tell a camera
bug from a data gap. *Check it on day one:* finish phase 1, hand-write a throwaway 20-row
table, and run the fixture-resolution test **before writing any rendering code**. If the 6
trains and 11 cinemas resolve at 100%, the pipeline is sound.

**2. Performance collapses at city level, not world level.** World is ~1700 dots in five
draw calls; it will be fine and will tell you nothing. City enables the full field, and
horizon culling only helps if the *traversal* is cheap — a naive cull still touches every
dot every frame. *Check it in phase 3,* with procedural dots and no asset work: put a
`Stopwatch` around `paint()` on a real device at full density. If bare traversal exceeds
~4ms, bucket the dots into coarse spherical cells and cull whole cells. The binary format
reserves header slots for exactly this, so adding it later does not force an asset
regeneration.

**3. The camera never feels premium, and no test can tell you.** Golden tests pin pixels,
not motion. *Mitigate by building the tuning overlay in phase 2-3* — sliders behind the
Developer flag for arc lift, per-level altitudes, durations and easing — and tune on
device in one sitting. Then freeze the results into `journey_motion.dart`.


---

## 9. What was actually built

Phases 0 through 8 landed. The globe is reachable from the dashboard's view
picker, opens over the centre of gravity of the user's own travel, and descends
World to Country to Region to City with the camera flying between them.

**Real data end to end.** The bundled table resolves **100% of the place strings
in `mock_pass_fixtures.dart`** — all six trains, all their halts, all eleven
cinemas — plus six mock flights. Both known traps are handled and pinned by
tests: `mock_t1` uses `BLR` (an airport IATA code) as a train endpoint, and one
halt is spelled `Hyderabad Decan`.

**The atlas is real Earth.** `tool/generate_journey_atlas.py` samples 42,000
points on a Fibonacci sphere against Natural Earth land polygons, keeping
12,125 — **28.9% land, against Earth's actual 29.2%**. Three LOD bands
(1,731 / 5,194 / 12,125) and 65 simplified India state rings pack into a 53KB
binary with a CRC. Decoder tests probe actual geography: India, Brazil, Nigeria,
Australia, Siberia and Antarctica carry dots; the mid-Pacific and mid-Atlantic
do not; the Caspian is correctly subtracted as a hole.

### Deviations from the plan above, and why

- **Two render layers, not four.** Atmosphere and land merged into
  `GlobeSurfacePainter`; arcs and markers merged into `GlobeOverlayPainter`.
  The plan's rationale was grouping by *repaint rate*, and these are the two
  real rates — a pulsing pin still never re-rasterises the twelve thousand land
  dots.
- **Declutter runs every frame** instead of once when the camera settles. It is
  a pure deterministic function over at most a few dozen markers, so a settled
  camera already gives settled pins, and this removes a whole caching path.
- **Border opacity is derived from camera distance** rather than driven by its
  own controller, so it can never fall out of step with where the camera
  actually is.
- **Drag lives in the view, not the navigator.** The navigator holds only
  settled cameras; rotation is layered on top and reset on each descent, so a
  level always opens framed on whatever was tapped.
- **The memory card uses `AppleSheet`, not `MorphSheet`.** There is no drill-down
  inside the card yet, so the morphing shell would have bought nothing.
- **The place table is hand-curated JSON.** The CSV master plus generator path
  described above was not built — 41 rows did not justify it yet. The JSON is
  the source of truth today.
- **Country and region rows are deliberately not name-searchable**, which the
  plan did not anticipate. Without it an address ending in a state name resolves
  a whole state as though it were the venue.

### What is not done

1. **The teaser on `user_card_detail_screen.dart`.** Phase 9's story page was not
   added. The globe painter takes a size and a camera, so it is ready to be
   embedded — this is additive work, not rework.
2. **On-device performance measurement.** No frame timing has been taken. The
   budget reasoning holds (five draw calls for the planet, zero allocation in
   the hot loop), but *reasoned is not measured*. Risk 2 in this document stands
   until someone runs the profile pass — and it warns that world level will look
   fine and tell you nothing, so measure at **city** level.
3. **The debug tuning overlay** for the ~20 motion constants. They are all
   isolated in `journey_motion.dart` and were set by reasoning, not by feel on
   real hardware. Risk 3 stands.
4. **Golden tests.** Rendering is covered by widget tests that assert it draws
   without throwing in both themes and that tap-to-descend works, but no pixels
   are pinned.

### Flights are mocked — the pickup note

`PassKind` is still `{train, movie, bus}`. Six `FlightItinerary` fixtures in
`lib/features/journey/data/mock_flight_fixtures.dart` give the world level real
arcs to draw. When a real flight pass lands:

1. Add `FlightPassItem` to the sealed `WalletPassItem`.
2. The switch in `buildJourneyIndex` **stops compiling** — the intended loud
   failure, in the right file.
3. Add one case delegating to `_fromItinerary`, which already exists because the
   mocks go through it.
4. Make `mockFlightsProvider` return `const []`.

Nothing else changes, because nothing downstream of `JourneyEvent` knows what a
flight is.

---

## 10. Picking this up later

Read this section first. Sections 1-8 are the spec; section 9 is what got built.

### Where it is

`git worktree list` will show the branch checked out at
`.claude/worktrees/journey-atlas`, or check it out fresh — it is pushed. Four
commits off `master` @ `5c2c05c`:

| Commit | What |
|---|---|
| `76f5ded` | The feature: domain, atlas pipeline, rendering, fourth view mode |
| `621f744` | Teaser page on the membership story deck |
| `9b8750a` | Fix: the camera flight was never running |
| `b6e599b` | Verification log |

It is behind `master` by whatever has landed since. Rebase before doing anything
else; the only files it shares with the rest of the app are
`dashboard_screen.dart`, `dashboard_header.dart`, `view_picker.dart` (one enum
case and three switch arms each), `user_card_detail_screen.dart`, `pubspec.yaml`
and the two asset registries.

### What is solid and should not be rebuilt

These were the expensive parts and they are done and tested:

- **The atlas pipeline.** `tool/generate_journey_atlas.py` plus the binary
  format and decoder. Real Earth, CRC-guarded, probed against actual geography.
  Regenerating is one command.
- **The place resolution layer.** `PlaceResolver`, the query parser, and the
  100%-fixture-coverage test. This was the genuinely hard problem — the app had
  no geography at all — and the answer holds regardless of how the globe looks.
- **The projection and camera math.** Pure functions with hand-computed
  expectations, including the fast path agreeing with its own reference.
- **The one-idea data model** — a memory is an ordered list of stops — which is
  what keeps the renderer free of per-pass-kind branches and lets flights slot
  in later without rework.

### What the vision needs that this does not have

Ordered by how much they matter to "it should feel like opening a memory":

1. **Motion tuning on real hardware.** The ~20 constants in
   `journey_motion.dart` were reasoned, never felt. This is the single largest
   gap between what exists and what was described, and no test can close it.
   Build the debug slider overlay behind the Developer flag first — Risk 3.
2. **Performance measured at city level**, where the full 12,125-dot field is
   enabled. Never done. World level draws ~1,700 dots, will look fine, and
   proves nothing — Risk 2. The binary format already reserves header slots for
   a spherical-cell index if traversal turns out to be the cost.
3. **The visual language of the markers.** Cluster bubbles and pins are
   functional placeholders, not designed objects. The spec asks for Apple-grade
   polish and this is where it visibly is not there yet.
4. **Level transitions beyond the camera.** Markers currently swap; nothing
   cross-fades, staggers or settles. The calm the spec describes lives here.
5. **Real flights.** Still mocked by design — see section 9.

### The trap to remember

`PassKind.fromJson` maps any unknown value to `train` (`pass_status.dart:62`).
The first time the server sends `"flight"`, Journey will draw a rail arc between
two airports and nothing will error.
