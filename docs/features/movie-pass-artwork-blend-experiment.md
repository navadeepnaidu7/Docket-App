# Movie pass artwork blend experiment

Status: wallet and expanded-view experiments implemented and installed; expanded
rendering and navigation checked on the Motorola.

## Approved scope (owner feedback)

- Add `Movie artwork blend` to Settings > Experimental, off by default and
  persisted locally. Switching it off restores the original rendering.
- Apply the soft poster background and sharp title-logo treatment to movie wallet
  cards. The expanded view now also follows the same experimental preference,
  using the full poster with feathered edges. Exported pass images keep their
  current faces.
- Preserve the partner footer exactly: the existing SVG assets, logo sizing,
  alignment, footer height, and District glow. The smaller text signature in the
  conversation mockup is explicitly rejected by the owner.
- Make narrowly scoped edits in the existing workspace so the current debug
  session can pick them up. Preserve concurrent changes, including Settings.
  Avoid interfering with concurrent debug sessions. The owner later authorized
  hot reload/restart; the wallet build was installed over the existing app after
  its old runtime rejected both. A subsequent ADB force-stop ended that runner.

## Expanded view: approved edge treatment

- Keep the current inset poster geometry (approximately 90% of the card width),
  retaining its full 2:3 aspect ratio. Do not crop or stretch the sharp poster.
- Remove the hard inner frame. Feather all four edges into an aligned, softly
  blurred copy of the same poster, then into the darker card background.
- Use the approved 28dp horizontal/top feather and 42dp bottom feather as the
  starting point. Keep the middle sharp and original artwork/title recognizable.
- Clip the overall effect to the ticket silhouette. The halo must paint below
  metadata and never obscure the title, date, seats, or entry-code controls.
- Keep partner SVGs, sizing, alignment, stub height and District glow unchanged.
  Preserve real-code rendering and the no-code state, plus booking/cinema/share
  sections beneath the ticket.
- Reuse the existing persisted experiment, off by default, with no new sliders
  in the app. The conversation's controls were design exploration only.
- Verify both preference states, 2:3 sizing at narrow/wide widths, footer
  invariants, entry-code behavior, missing/failing artwork, and actual Flutter
  renders with the Dune and Odyssey reference posters.

## Intent

Explore the owner's Apple Music inspired idea: retain the movie title logo and
poster, but let the artwork establish a continuous card surface. The movie should
set the atmosphere; the booking partner remains identifiable as a secondary mark.
Start with movie passes because these carry poster and title-logo assets.

## Current evidence

- `MovieBrandStyle` supplies BookMyShow red, District purple, and neutral palettes.
- `MovieTicketFace` uses that palette behind an inset artwork panel, information
  grid, tear line, and large partner footer.
- The wallet hero prefers the transparent title logo on a dark plate when one is
  available; otherwise it shows the poster. Detail uses the full 2:3 poster.
- The face is reused by wallet, detail, and share, so an unguarded face change
  would affect all three.
- A Motorola Edge 30 is connected, with a Flutter debug run already attached.
  Other analyzer/test processes and substantial uncommitted work are present.
- A read-only phone capture showed Manage, not a movie pass. The diagnosis above
  is based on source, not a rendered assessment of the current movie card.

## Proposed composition

1. Keep the existing ticket silhouette, information order, and wallet fit for the
   first comparison. This isolates the effect of the artwork blend.
2. Put the correct movie poster beneath the upper card area, softly enlarged and
   blurred where it supplies atmosphere. Keep the title logo sharp and contained.
3. Fade the artwork continuously into a darker, artwork-tinted lower surface.
   Remove the visually separate inner artwork plate in the experimental variant.
   Derive atmosphere from the poster, not the transparent logo or partner color.
4. Keep show date/time, screen/seats, and cinema on a calm, high-contrast area.
   Preserve the movie title as readable text as well as its decorative logo.
5. Reuse the original partner footer unchanged, including its SVG logo and glow.
6. Use a stable poster-hint gradient if artwork is absent, downloading, or broken;
   use text if the logo fails. Never substitute another movie's artwork.

This translates the owner's reference into artwork-led atmosphere; it is not a
proposal to copy music controls, typography, or screen structure.

## Implementation sequence

1. Capture a movie-card baseline when the phone is available for navigation.
2. Add an opt-in movie-wallet variant with the current rendering as the default.
   Preserve all pre-existing edits in the shared tree.
3. Produce an off-device Flutter render comparing the same pass in both variants.
   Begin with one pass, then exercise contrasting posters before tuning globally.
4. Reuse cached image providers and bounded image decoding. Prefer a small static
   artwork blur plus dark scrim for the first prototype; only add memoized palette
   extraction if rendered evidence shows it is needed. Avoid work on every frame.
5. Verify bright/dark artwork, missing poster/logo, loading/failure, long titles,
   multiple seats, expired passes, light/dark surroundings, and short viewports.
   Run targeted layout/image tests and analysis for the touched code.
6. Review on the connected Motorola at actual carousel size, including swiping
   smoothness. Only extend the treatment to detail/share after the wallet concept
   is accepted; preserve full-poster framing and scannable-code behavior there.

## Coexisting with other sessions

- No process termination, adb-server reset, storage clearing, or reinstall over
  the existing application as part of this planning pass.
- An isolated checkout separates source edits but does not isolate a phone's
  installed app. Do not launch a competing Flutter runner against the same app.
- Prefer off-device renders first. If the current runner must remain in use,
  prepare a separate lab application ID and isolated preview entrypoint for a
  side-by-side install; its storage/auth is separate from the main app.
- Keep the first experiment out of shared theme, navigation, archive, API, and
  persistence owners. Leave existing uncommitted changes intact.

## Success criteria

The poster, logo, and ticket read as one surface; different movies establish
different atmospheres; show time and seats remain quick to find; the partner
remains recognizable; and image loading never destabilizes the layout.

## Implementation and verification

- `movieArtworkBlendProvider` persists the choice under
  `experimental_movie_artwork_blend`, defaulting to false. An immediate change
  wins over preference hydration; writes are ordered.
- Settings > Experimental > Movie artwork blend updates the vertical roll,
  stacked deck, and expanded movie detail view in place.
- The soft background uses the correct cached poster at a bounded 360px decode,
  with a prepared, cached blur, dark scrim, and persistent gradient fallback. The sharp
  title-logo layer has no dark inner plate. Expired artwork is desaturated.
- The original partner footer code remains unchanged. Tests compare the SVG
  asset, dimensions, tint policy, and alignment inside the stub.
- The experimental hero reserves slightly less height so two-line titles fit the
  existing 382 x 620 wallet canvas. Default card geometry is unchanged.
- 161 targeted tests passed: preference/variant integration, both carousel modes,
  expanded-view preference reactivity, full-poster sizing, sharp/blurred image
  selection, original footer invariants at both densities, entry-code actions,
  movie hero/ratio, responsive wallet layouts, Settings scroll, pass ingestion
  recovery, and pass sharing. The manual rendering harness also passed.
- Analysis of the seven Dart/test/tool files touched by the expanded extension
  reported no errors or warnings, and one pre-existing info lint: deprecated
  `cacheExtent` in Settings.
- Actual Flutter renders of Dune and Odyssey (classic and blended) were inspected
  under `build/movie-artwork-preview`. The optional manual render harness is
  `tool/movie_artwork_preview_test.dart`; it seeds the image cache from the
  downloaded conversation assets under `outputs/pass-blend-preview`. It now
  renders expanded Dune/Odyssey faces in both modes, with genuine fixture codes
  and original partner logos. The expanded renders were visually inspected.
- `MovieBlendedPoster` retains the existing inset and full 2:3 frame, with
  intersecting alpha masks fading only the perimeter into an aligned 25dp blur.
  The card-wide artwork continues below it; metadata paints above the halo.
  Background decoding is capped at 360px and the sharp image at 780px.
- The performance follow-up replaces onscreen background/halo blur filters with
  cached rasters capped at 128 x 256 pixels, preserving soft blur overflow. See
  [movie-pass-transition-performance.md](movie-pass-transition-performance.md)
  for the navigation correction, lifecycle tests, and device measurement status.
- The expanded debug APK was built for Android arm64, checked for the new poster
  implementation, and installed over the existing Motorola build using
  `adb install -r`. Installation and cold launch succeeded; the existing enabled
  artwork preference was retained. No uninstall or data clearing was performed.
  A subsequent performance follow-up inspected the expanded poster on the
  Motorola, verified back/interrupted navigation, and measured repeated opening
  and closing. Broader scrolling and release-mode performance remain unverified.
