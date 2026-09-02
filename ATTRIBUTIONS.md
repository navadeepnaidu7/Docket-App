# Third-party asset attributions

Docket bundles the following third-party assets under their own licences. Each
entry states whether it ships verbatim or modified, and what was changed. This
file satisfies the attribution requirement; the same credits are registered with
Flutter's `LicenseRegistry` from `lib/main.dart` so they also appear in-app under
Settings -> About -> Licences.

## Journey globe geometry — Natural Earth (public domain)

The Journey globe's land-dot field and India state outlines derive from
[Natural Earth](https://www.naturalearthdata.com/), which is in the public
domain and explicitly requires neither permission nor attribution. Credited
here anyway, because knowing where map data came from matters.

| Bundled as | Derived from | Licence |
|---|---|---|
| `assets/journey/atlas_v1.bin` | `ne_110m_land`, `ne_50m_admin_1_states_provinces_lines` | Public domain |

**Heavily modified — this is not Natural Earth data in any recognisable form.**
`tool/generate_journey_atlas.py` uses the land polygons only to decide which
points of a Fibonacci sphere fall on land, then **discards the polygons
entirely**; what ships is a list of points, not a coastline. The India admin-1
lines are filtered out of the global set, Douglas-Peucker simplified at 0.02
degrees, and quantised to int16 (about 300m of error). Masters live in
`tool/design_src/naturalearth/` and are not bundled.

Place coordinates in `assets/journey/places_v1.json` are separately sourced and
hand-curated in this repository; they are not Natural Earth data.

## Passport cover artwork — CC BY-SA 4.0

Used in the add menu to illustrate the Passport option and the e-passport /
regular passport choice.

| Bundled as | Source | Author | Licence |
|---|---|---|---|
| `assets/wallet/passport/covers/passport_regular.svg` | [Indian Passport.svg](https://commons.wikimedia.org/wiki/File:Indian_Passport.svg) | Swapnil1101 | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |
| `assets/wallet/passport/covers/passport_epassport.svg` | [Indian Passport (e-Passport, 2024).svg](https://commons.wikimedia.org/wiki/File:Indian_Passport_(e-Passport,_2024).svg) | FireDragonValo | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |

Both are hosted on Wikimedia Commons. Masters are kept in
`tool/design_src/passport_covers/`.

**ShareAlike, in practice.** CC BY-SA 4.0 obliges attribution and requires that
the work *and any adaptation of it* stay under a compatible licence. Bundling
these files alongside the app is aggregation, not adaptation — it does not
relicense Docket. But **editing either SVG** (recolouring, cropping, re-pathing)
produces a derivative that must itself remain CC BY-SA 4.0 and be credited as a
modified version. Both files are currently byte-identical to the Commons
originals; keep them that way and compose effects around them
(`PassportCoverArt` adds shadow and rotation externally for exactly this reason).

The Ashoka emblem depicted within the artwork is the State Emblem of India; its
use here is depictive, as part of a rendering of a passport cover.

## Pass category icons — ISC

The line glyphs in the add menu's pass grid (`assets/passes/icons/`) are from
[Lucide](https://lucide.dev), **modified**: `stroke-width` is reduced from
Lucide's default `2` to `1.5`. At the ~95pt tile these render into, the stock
weight read as chunky rather than as the thin line set the design calls for.
No geometry was changed. ISC permits modification; the notice below still
applies.

Copyright (c) for portions of Lucide are held by Cole Bemis 2013-2022 as part of
Feather (MIT). All other copyright (c) for Lucide are held by Lucide Contributors
2022, under the [ISC License](https://github.com/lucide-icons/lucide/blob/main/LICENSE).

Files: `train-front`, `bus`, `plane`, `ticket`, `calendar-days`, `ellipsis`,
`camera`, `file-text`, `hash`.

ISC is permissive: use, copy, modify and distribute freely, provided the
copyright and permission notice travel with the work. That notice is registered
with `LicenseRegistry` in `lib/core/assets/asset_licenses.dart` so it ships
inside the app, not only in this file.

## Other bundled assets

- `assets/branding/`, `assets/navbar/`, `assets/wallet/passport/emblems/`,
  `assets/wallet/aadhaar/` — Docket's own artwork, rasterized from masters in
  `tool/design_src/`.
- `assets/auth/google/` — Google Sign-In branding, used per Google's branding
  guidelines with the official filenames unchanged.
- `assets/passes/bookmyshow*.svg`, `assets/passes/district-logo.svg`,
  `assets/passes/zomato.svg` — third-party brand marks, used nominatively to
  identify the source of a pass.
