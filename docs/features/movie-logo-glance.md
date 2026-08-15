# Movie logo glance

How movie passes split their art between the two surfaces they appear on.

## Design

| Surface | Art |
|---------|-----|
| **Wallet glance card** | Transparent TMDB **title logo** (PNG) centered on a **dark** plate |
| **Opened detail** | Full-length **poster** one-sheet (2:3) |

The glance card is small and heavily cropped, so a poster reduces to an unreadable slice of
artwork. The title logo is designed to be legible at that size and identifies the film
immediately. The detail view has room for the full one-sheet, so it keeps the poster.

This is the committed treatment for movie passes, on mock fixtures and on real data alike.

## Client

| Piece | Role |
|-------|------|
| `MoviePass.logoUrl` / `resolvedLogoUrl` | Optional field; JSON key `logoUrl` |
| `_HeroBand` in `movie_ticket_face.dart` | Glance + logo → dark plate + `BoxFit.contain`; detail → poster |
| Mock fixtures | Carry poster + logo URLs so the treatment is visible without a backend |

Both fields are **nullable**, and that is a normal state — TMDB may have no logo for a film, or
the async lookup may not have finished. With no logo the glance card falls back to the poster,
and with neither it falls back to the `posterHint` gradient. Never substitute another film's
artwork.

## Server work still to do

The API does not emit `logoUrl` yet, so today only mock fixtures exercise the logo path;
remote passes fall back to the poster. To wire it up in `docket_server`:

1. Pick from TMDB images `logos`, preferring `iso_639_1` matching the ticket language, falling
   back to `en`
2. Persist `logo_path` (or resolve on read)
3. Emit an absolute `logoUrl` through the Docket image proxy — either the existing
   `/img/poster/{size}/{file}` route or a dedicated `/img/logo/...` if separate cache keys are
   wanted

Contract field is documented in [`../api/passes.md`](../api/passes.md).

## Known issue: fixture URLs bypass the proxy

The mock fixtures currently point at `https://image.tmdb.org/t/p/...` **directly**, rather than
going through the Docket image proxy that `MOCK_POSTER_ORIGIN` normally gates. That is why the
art renders with no backend running.

`image.tmdb.org` is blocked by many Indian ISPs, so on those networks the fixture art silently
fails to load and the cards fall back to the gradient. Routing fixtures back through the proxy
is the fix, and it lands naturally with the server work above.

## Not covered yet

- History folder thumbs still use poster / gradient only
