# Archive categories

## Approved direction (29 October 2026)

Replace the Archive root's paper-folder tiles with the approved Apple + Sofa
preview in `build/archive-preview/categories-apple-sofa.html`. Sofa informs the
photographic covers and compact caption panels; Apple's Reminders reference
informs the clearer count hierarchy. Docket keeps its own typography, neutral
surfaces, header, category labels, and navigation.

This changes the category chooser only. `HistoryCategoryScreen`, its swipeable
pass deck, date dial, ticket faces, detail screens, and sharing are outside scope.

## Implementation plan

- Keep `HistoryFolderTile` as the category-grid widget and retain the current
  folder provider, ordering, real counts, and hide-empty-category behavior.
- Replace its folder painter, sheet stack, and icon well with a bundled photo
  above a neutral caption panel. Remove the obsolete one-sided icon Hero.
- Keep two columns with a 16dp gutter and 20dp row spacing. Derive each tile's
  height from a 1.55:1 cover and a caption panel of at least 76dp. At larger text
  sizes, grow the caption and use one column so the text stays readable.
- Put the category name on the left (Geist 17, semibold). Put its real count on
  the right (28, semibold) with `pass` / `passes` below (11). Keep the complete
  category-and-count accessible label and tap action.
- Use `AppTheme.elevated`, existing ink and secondary-label tokens, the current
  card radius, a fine edge, and a faint light-mode contact shadow.
- Reuse `BounceTap` at 0.972 with a single selection haptic. Reduced motion keeps
  the scale at 1. No repeated entrance effects or new category-interior animation.
- Bundle the exact three approved JPEGs under `assets/archive/covers/`. Preserve
  the preview's crops: train 76%, cinema 55%, bus 64% down the image. Apply only
  a slight runtime dark-mode veil. Decode images near their displayed size.
- Record the Pexels photographers, URLs, license, and file hashes; register the
  credits in the in-app Licences page.

## Covers

| Category | Photograph | Photographer |
|---|---|---|
| Trains | [Running Indian Train](https://www.pexels.com/photo/running-indian-train-20309650/) | GOWTHAM AGM |
| Movies | [Number in a Red Seat](https://www.pexels.com/photo/number-in-a-red-seat-11718584/) | Linda Gschwentner |
| Buses | [Photo of a Coach on a Road in Perspective](https://www.pexels.com/photo/photo-of-a-coach-on-a-road-in-perspective-16962781/) | 虎 曼 |

The covers are category artwork, not previews of a particular saved booking.
Photographs use the [Pexels License](https://www.pexels.com/license/). Pinned
download URLs and SHA-256 hashes live in
`tool/design_src/archive_covers/sources.json`.

## Verification

Run focused static analysis, inspect the installed category grid in light and
dark mode, and open a category to confirm the existing deck still receives the
tap. No automated tests are to be run, per the user's instruction. Existing tile
layout assertions should describe the new visible name/count layout instead of
the removed paper-thickness implementation.

### Implementation checkpoint — 29 October 2026

- Implemented the approved tile, shared grid geometry, offline covers, source
  manifest, and in-app photo credits. Existing tile layout assertions were
  updated for the separated count/unit; no tests were run.
- Focused `flutter analyze --no-pub` passed for both category UI files, asset
  constants/credits, and the existing tile layout test source.
- `flutter build apk --debug --no-pub` passed. The three photographs in the APK
  match the pinned SHA-256 hashes. The build was installed on the Motorola Edge
  30 with a live Flutter debug session.
- The phone's wireless debugging connection disconnected during navigation,
  briefly returned on a new port, then disappeared from discovery. Its last IP
  became unreachable. No local Android emulator is installed. Final inspection
  of the Archive grid in both themes and the category-opening check remain
  pending a stable connection. The category interior source was not changed.
