# Movie pass artwork

How a movie pass uses its poster and title logo on each surface, the opt-in artwork blend,
and the rules that keep missing artwork honest. Replaces the separate artwork-blend,
transition-performance and archive-poster notes.

Status: implemented. Owners: `lib/features/tickets/presentation/movie/`
(`movie_ticket_face.dart` `_HeroBand`, `movie_blended_poster.dart`,
`movie_blurred_artwork.dart`, `movie_feathered_image.dart`),
`lib/features/tickets/application/movie_artwork_blend_provider.dart`,
`lib/features/tickets/presentation/history/archive_pass_deck.dart` (`_MovieArchiveCard`).
Wire fields: `../api/passes.md` (`posterUrl`, `logoUrl`, `posterHint`).

## Surfaces

| Surface | Art |
|---|---|
| Wallet glance card | Transparent **title logo** (TMDB, or bundled demo art) centred on a dark plate, `BoxFit.contain` |
| Opened detail | Full 2:3 **poster** one-sheet |
| Archive deck | Poster with the film's title band; brand chrome forced on (see below) |
| Shared PNG | The glance face, so the title logo (`pass-share.md`) |

The glance card is small and heavily cropped; a poster reduces to an unreadable slice, while
the title logo is designed to read at that size.

## Missing artwork is a normal state

`posterUrl` and `logoUrl` are both nullable: TMDB may have no match, or the async lookup may
not have finished. No logo falls back to the poster; neither falls back to the `posterHint`
gradient, which `MoviePosterArt` paints first and never removes. In the archive, the film's
title is drawn over that gradient because an unnamed gradient is unidentifiable at deck size.
**Never substitute another film's artwork.**

Archived passes are expired, and the expired `MovieBrandStyle` palette is grey for every
brand, so archive cards force brand chrome (`useBrandColors: true`) to keep BookMyShow red and
District purple distinguishable.

## Artwork blend experiment

Settings -> Experimental -> **Movie artwork blend**; off by default, persisted as
`experimental_movie_artwork_blend`. An immediate toggle wins over preference hydration.
Off restores the original rendering exactly. Applies to the vertical roll, the stacked deck
and the expanded detail; the shared PNG keeps the standard face.

- Wallet: the correct poster, softly blurred and scrimmed, becomes the card's upper surface;
  the title logo stays sharp with no dark plate. Expired artwork is desaturated. The hero
  reserves slightly less height so two-line titles fit the 382 x 620 canvas; default geometry
  is unchanged.
- Detail (`MovieBlendedPoster`): keep the ~90%-width inset poster at full 2:3, never cropped
  or stretched. No hard frame: alpha masks feather the perimeter (28 dp sides/top, 42 dp
  bottom start point) into an aligned ~25 dp blurred copy, then the card. Clipped to the ticket
  silhouette; the halo paints below metadata and never covers title, date, seats or code.
- **Partner footer is untouched**: existing SVGs, sizing, alignment, stub height and District
  glow. A smaller text signature was rejected by the owner. Tests pin the footer invariants.
- Real-code rendering and the no-code state are unchanged.

### Performance rules

- Never put full-size `ImageFiltered` blur layers on screen. `MovieBlurredArtwork` prepares a
  blurred raster of at most 128 x 256 px, keyed by source, size, fit, radius and overscan, with
  three blur radii of transparent padding so the halo overflow stays soft. Flutter's bounded
  `ImageCache` owns its lifetime; there is no separate bitmap cache.
- Decode caps: 360 px for the background, 780 px for the sharp poster. Cached network sources
  (`cached_network_image`) as everywhere else.
- `MovieFeatheredImage` bakes the intersecting perimeter gradients into the sharp
  raster once. Scrolling and route motion reuse that image rather than compositing
  two full-size `ShaderMask` layers every frame. The same bounded `ImageCache` owns it.
- Blended faces sit behind a repaint boundary so route motion reuses their paint.
- A mounted blended wallet card prepares the detail poster and halo after its
  first frame, using the exact expanded-view image-cache keys. This does not
  mount a hidden detail route or wait for the network on tap. Preparation uses
  Flutter's bounded image cache and failures retain the existing fallback.
- A prewarmed sharp poster displays synchronously as part of the platform route
  animation, without an overlapping image fade. Cold cache misses retain the
  existing gentle reveal and never hold up navigation.
- The feathered fallback is replaced when the poster loads. Keeping another fallback
  underneath the loaded image compounds its edge opacity and creates a rectangular
  rim. A changed artwork source resets the image so another film's pixels cannot linger.

Measured on the Motorola Edge 30, debug build, 21 Nov 2026 (four Dune open/close cycles, first
excluded): median presented-frame interval 25.17 -> 16.79 ms opening, 16.80 -> 8.39 ms closing;
`SurfaceFrame::Encode` p95 34.92 -> 8.46 ms opening. Long opening intervals remain in debug and
were traced to building/layout of the new route, not the removed filters. These are debug
diagnostics, not release benchmarks; do not describe every stutter as eliminated.

The 24 Nov 2026 follow-up on Nothing A059 found expensive GPU draw spans during
detail scrolling with the live masks. Debug VM traces after cached feathering showed
substantially lighter GPU work. The temporary fallback overlap was then removed;
native checks with the bright Spider-Man poster verified soft sides and bottom, and
the owner confirmed opening and scrolling felt good on the phone. This is a debug
diagnostic and manual check, not a release benchmark or proof that every hitch is gone.
The 198 focused artwork, fixture, sharing and responsive-card tests passed. Scoped
analysis of the affected source, tests and preview tool found no issues.

## Demo movie artwork

`movie_bms_1` is Dune: Part Three (TMDB 1170608), replacing Part Two without
changing the fixture's ID. Its clearer title treatment is bundled from the official film
site, alongside the darker Part Three poster; see `ATTRIBUTIONS.md`.
`MoviePass.logoAsset` is a client-only fixture field,
analogous to `posterAsset`, and takes priority over `logoUrl` on glance/share faces.
Detail always uses the correct poster. A new active District fixture,
`movie_dist_doomsday`, shows Avengers: Doomsday (TMDB 1003596), with its matching
poster bundled too. Booking details,
runtime and certification are illustrative mock data. No entry code is invented
for the new pass.

## Known issue: fixtures bypass the proxy

`mock_pass_fixtures.dart` points at `https://image.tmdb.org/t/p/...` directly rather than the
Docket image proxy, so mock art renders with no backend. `image.tmdb.org` is blocked by many
Indian ISPs; remaining remote fixtures can fall back to the gradient there. The two bundled
demo posters and Dune title avoid this dependency. Remote fixture routing remains separate
work. Archived fixtures carry no `logoUrl` on purpose: an expired pass never renders a glance card.

## Server

`../docket_server/internal/service/pass_mapper.go` emits `logoUrl` through the image proxy
when TMDB enrichment found a logo. Remote passes without one degrade to the poster.

## Not covered

Tablet-adaptive density; broader scrolling and release-mode performance of the blend.
