# Movie archive posters

Inside **Archive → Movies**, films are shown as a grid of framed posters instead of the titled
rows every other category uses.

## Why only movies

A film is recognised by its artwork long before its title. Trains and buses have no artwork, so
they keep `HistoryPassCard`. The switch is one branch in `HistoryCategoryScreen`, keyed on
`PassHistoryCategory.movie` — every other category is untouched.

## Sections are years, not months

Posters run three to a row, so a header per month strands one- and two-tile sections between
rules and the grid stops reading as a shelf. The movies folder buckets by **year**; every other
category keeps months, where a titled row per month is the right density.

`buildHistorySections(items, span:)` takes a `HistorySectionSpan` — `month` (default) or `year`.
Ordering, the newest-first sort, and the trailing **Undated** bucket are identical either way:
a pass whose date string will not parse is never dropped, whichever span is in play.

## The tile

| Piece | Treatment |
|-------|-----------|
| Art | Full 2:3 one-sheet (`posterUrl`), **not** the title logo the glance card uses |
| Frame | 3px border in the ticket provider's colours, 16px radius |
| Depth | Brand-tinted glow plus a neutral drop shadow |
| Grid | 3 columns, 14px across, 16px down |

### Brand frames

Archived passes are expired, and `MovieBrandStyle`'s expired palette is grey for *every* brand —
which would make the whole grid identical. The tile forces brand chrome
(`MovieBrandStyle.forPass(pass, useBrandColors: true)`) so a BookMyShow ticket still reads red
and a District one purple. `HistoryStripLook.forMovie` is the same brand-chrome path the
glance strip uses.

### No poster is a normal state

TMDB may have no match, or the async lookup may not have finished. `MoviePosterArt` paints the
`posterHint` gradient first and never removes it, so it shows through while the image loads and
stays as the art when there is none. The archive tile adds the **film's title** over that
gradient — at grid size an unnamed gradient rectangle is unidentifiable. Another film's
artwork is never substituted.

## Opening a pass

`posterScaleRoute` pushes the detail screen with a scale-and-fade: the page starts at 0.86 and
settles at 1.0 over 420ms on `easeOutCubic`, so opening reads as the poster growing into the
screen. `BounceTap` handles the press.

Deliberately **not** a `Hero`. The destination is a full e-ticket face, not a bare poster, so
there is no honest counterpart to fly into — and a Hero tag that collides (the same pass drawn
twice on one route) throws at runtime, where this cannot.

## Fixtures

The archive ships nine finished bookings spread across 2023–2025, so the grid and its year
headers have something real to render. Every `posterUrl` was checked against `image.tmdb.org`
and returns image bytes — a mistyped hash 404s silently and falls back to the gradient, which
looks like a design bug rather than a typo.

Archived fixtures carry **no `logoUrl`**, deliberately: the logo exists so the glance card has
legible art, and an expired pass never renders a glance card. The detail face it opens into
uses the poster.

## Not covered

- The glance card keeps the title logo; only the movies archive grid uses the poster
- The Archive root folders no longer preview posters (see `archive-folders.md`)
- Grid density is fixed at 3 columns — it does not adapt on tablets
- Fixture posters point at `image.tmdb.org` directly rather than the Docket proxy, so they do
  not load on ISPs that block it (see `movie-logo-glance.md`)
