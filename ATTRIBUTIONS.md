# Third-party asset attributions

Docket bundles the following third-party assets. Each is redistributed **verbatim**,
unmodified, under its own licence. This file satisfies the attribution requirement;
the same credits are registered with Flutter's `LicenseRegistry` in `lib/main.dart`
so they also appear in-app under Settings -> About -> Licences.

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

## Other bundled assets

- `assets/branding/`, `assets/navbar/`, `assets/wallet/passport/emblems/`,
  `assets/wallet/aadhaar/` — Docket's own artwork, rasterized from masters in
  `tool/design_src/`.
- `assets/auth/google/` — Google Sign-In branding, used per Google's branding
  guidelines with the official filenames unchanged.
- `assets/passes/bookmyshow*.svg`, `assets/passes/district-logo.svg`,
  `assets/passes/zomato.svg` — third-party brand marks, used nominatively to
  identify the source of a pass.
