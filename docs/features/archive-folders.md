# Archive folders

The Passes-tab **Archive** root is a 2-column grid of category folders. Opening one
pushes `HistoryCategoryScreen`, which is now a single swipeable deck of pass faces.

This note is the tile. See `archive-pass-deck.md` for the folder interior;
`movie-archive-posters.md` describes the poster grid that deck replaced.

## Two tiles that failed first

1. **The manila.** A coloured tab with fanned poster and route chips clipped behind the
   front panel. At phone-grid scale the metaphor collapsed — thumbs were unreadable, the
   accent glowed in dark mode, and the folder's identity was its tab colour, not its name.
2. **The notched card.** One rounded shape with a small tab cut into the top-left, a
   whisper of accent (8% light / 11% dark), a 7px sheet peeking below, and an arrow badge
   in the top-right. It was calm but inert: Trains and Movies were indistinguishable at a
   glance, the tab was too small to read as a tab, the "stack" was one flat sliver, and the
   arrow was chrome on a tile that was entirely tappable anyway. A 0.90 aspect left a hole
   between the mark and the name.

## The tile

Not one shape with a notch — **three planes of paper**. That is what carries the
metaphor at 167dp:

```
  ┌────┐
  │    └──────────────┐   ← back panel: tinted, carries the tab
  │  ▁▁▁▁▁▁▁▁▁▁▁▁▁▁   │   ← 1-3 sheet edges, each shading the one behind
  │ ┌────────────────┐│
  │ │                ││   ← front pocket: near-white, holds the copy
  │ │  [mark]        ││
  │ │  Movies        ││
  │ │  4 passes      ││
  └─┴────────────────┴┘
```

| Piece | Treatment |
|---|---|
| Shape | Tab 40% wide × 19 tall, top-left, rounded joins. Body radius 20. Silhouette runs to the cell edge — nothing peeks out the bottom any more. |
| Panel | The folder's own colour: accent at 26% (light) / 32% (dark), deepening to 38 / 44 at the bottom. Only the tab and a 14px shelf show it, so it can hold a real tint where a full-face wash could not. |
| Paper | 1-3 sheet edges in the shelf — `sheetsFor`: 1 pass → 1, 2-4 → 2, 5+ → 3. Each is lower, 5px wider and a shade brighter than the one behind, and each casts a blurred shadow onto it. Pure white in light mode. |
| Pocket | Full-width rounded rect from the shelf to the bottom, top corners 12. Near-surface, with a 6% (light) / 16% (dark) accent settling at its foot. A bright rim on its top edge only — stroking it all round would double up against the silhouette. |
| Lip | Silhouette stroke is a top-to-bottom gradient, bright rim to hairline, plus a short rim fade under the tab (40%) and a fainter one on the shelf (30%). The shelf's has to stay under the tab's or the tab reads as detached. |
| Shadow | Light mode only, two layers: wide ambient (blur 9, offset 5) plus tight contact (blur 2.5, offset 1). One blur alone reads as fog. |
| Mark | 40px squircle, category-tinted — the same `HistoryCategoryWell` the category screen uses, so the Hero is honest. |
| Copy | Name (17px w600, tracking −0.45) then count (12px, tracking +0.15, tertiary). |
| Block | Mark and copy are **one bottom-anchored block**, 12px apart. Splitting them to opposite corners leaves a hole in the middle that no amount of type can fill. |
| Grid | 2 columns, aspect **1.0**, gutters `Space.gutter`, 16 across / 18 down. |
| Press | `BounceTap` 0.96 |

No arrow badge. The whole tile is the target, every tile in the grid behaves the same
way, and Files and Photos do not put one on a folder either.

Colour is still a tint, not a fill — it lives on the panel, where the name is not.
Poster frames and `HistoryPassCard` carry the saturated brand chrome one level down.

## Geometry lives in one place

`_FolderMetrics.of(size)` builds the silhouette, the pocket and the sheet step from the
real cell size, and both the painter *and* the content padding read it. The copy can
therefore never land outside the pocket it appears to sit in, at any scale. It falls back
to a 168dp cell when constraints are unbounded rather than painting a NaN path.

## Hero

Tag `history-category-{name}` flew `HistoryCategoryWell` into `_CategoryIntro`. Both ends
took the widget's default size, so they could not drift apart — a disc or a naked mark has
no counterpart on the tile.

**Currently one-sided.** `_CategoryIntro` went away with the date-sectioned category list,
and the deck has nothing for the mark to land on. A Hero with no counterpart does not
throw; the flight simply does not happen. Either give the deck a landing mark or drop the
tag — leaving it is a transition that works for nobody and fails visibly to nobody.

## What it does not do

- Empty categories stay hidden (`buildHistoryFolders` never emits them).
- No readable contents peek out; `history_folder_thumbs.dart` was deleted with them. The
  sheet count is a thickness to feel, not a number to read.
- `lastAddedLabel` stays off the tile. A date is one fact too many at 167dp.
- `ArchiveScaffold` chrome and `StudioBackdrop` are untouched.
- `SpaceArchiveScreen` (wrapped highlights) is a different screen.
