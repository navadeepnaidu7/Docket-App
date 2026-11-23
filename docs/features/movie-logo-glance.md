# Movie pass artwork

How a movie pass uses its poster and title logo on each surface, the opt-in artwork blend,
and the rules that keep missing artwork honest. Replaces the separate artwork-blend,
transition-performance and archive-poster notes.

Status: implemented. Owners: `lib/features/tickets/presentation/movie/`
(`movie_ticket_face.dart` `_HeroBand`, `movie_blended_poster.dart`,
`movie_blurred_artwork.dart`), `lib/features/tickets/application/movie_artwork_blend_provider.dart`,
`lib/features/tickets/presentation/history/archive_pass_deck.dart` (`_MovieArchiveCard`).
Wire fields: `../api/passes.md` (`posterUrl`, `logoUrl`, `posterHint`).

## Surfaces

| Surface | Art |
|---|---|
| Wallet glance card | Transparent TMDB **title logo** centred on a dark plate, `BoxFit.contain` |
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
- Blended faces sit behind a repaint boundary so route motion reuses their paint.

Measured on the Motorola Edge 30, debug build, 21 Nov 2026 (four Dune open/close cycles, first
excluded): median presented-frame interval 25.17 -> 16.79 ms opening, 16.80 -> 8.39 ms closing;
`SurfaceFrame::Encode` p95 34.92 -> 8.46 ms opening. Long opening intervals remain in debug and
were traced to building/layout of the new route, not the removed filters. These are debug
diagnostics, not release benchmarks; do not describe every stutter as eliminated.

## Known issue: fixtures bypass the proxy

`mock_pass_fixtures.dart` points at `https://image.tmdb.org/t/p/...` directly rather than the
Docket image proxy, so mock art renders with no backend. `image.tmdb.org` is blocked by many
Indian ISPs; there the fixtures silently fall back to the gradient, which looks like a design
bug. Routing fixtures through the proxy is the fix. Archived fixtures carry no `logoUrl` on
purpose: an expired pass never renders a glance card.

## Server

`../docket_server/internal/service/pass_mapper.go` emits `logoUrl` through the image proxy
when TMDB enrichment found a logo. Remote passes without one degrade to the poster.

## Not covered

Tablet-adaptive density; broader scrolling and release-mode performance of the blend.
