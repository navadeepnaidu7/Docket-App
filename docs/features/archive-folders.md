# Archive folders

The Passes-tab **Archive** root is a 2-column grid of category folders. Opening one
pushes `HistoryCategoryScreen` (titled rows, or the movie poster grid).

This note is the tile. Category lists are unchanged; see `movie-archive-posters.md`
for the movies folder interior.

## Why the previous tile failed

The first folder was a physical manila: coloured tab, paper lip, fanned poster and
route chips clipped behind the front panel. At phone-grid scale the metaphor
collapsed — thumbs were unreadable, the accent glowed in dark mode, and the
identity of the folder was the tab colour rather than its name.

## The tile

A paper object sitting on the page — the same craft as `SquircleTile`. A flat
fill reads as a hole punched in the sheet; the stack, the lip, and the well
make it a thing you can pick up.

```
    ▔▔
  ┌──────────────┐
  │ [well]   (↗) │
  │              │
  │  4 passes    │
  │  Movies      │
  └──────────────┘
     ──── sheet ────
```

| Piece | Treatment |
|---|---|
| Shape | Short top-left tab (~36% width, 18px), body radius 20. Path sits 7px short of the cell so a backing sheet peeks out. |
| Fill | Vertical gradient, top catching light, bottom receding. Whisper of the category accent (8% light / 11% dark) so Trains and Movies are distinct without a painted tab. |
| Lip | Stroke is a top-to-bottom gradient, bright rim to hairline. A 16px fade of rim colour under the top edge. |
| Pocket | Soft crease under the tab — the body recedes as if the folder were open. |
| Sheet | One rounded rect behind, inset, no tab. Not contents — just the idea of paper. |
| Well | 36px squircle, category-tinted, same `HistoryCategoryWell` the category screen uses so the Hero is honest. |
| Arrow | 32px filled circle, hairline. Visual only; the whole tile is the hit target. |
| Count | `1 pass` / `N passes`, 12px, tracking +0.15, tertiary. |
| Title | `category.label`, 17px w600, tracking −0.45. Semibold, not heavy. |
| Grid | 2 columns, aspect 0.90, gutters `Space.gutter`, 16px gaps |
| Press | `BounceTap` 0.96 |

Colour stays a tint, not a fill. Poster frames and `HistoryPassCard` still carry
the saturated brand chrome one level down.

## Hero

Tag `history-category-{name}` flies `HistoryCategoryWell` into `_CategoryIntro`.
Both ends are the same 36px tinted squircle — a disc or a naked mark has no
counterpart on the tile.

## What it does not do

- Empty categories stay hidden (`buildHistoryFolders` never emits them).
- Peeking thumbs are gone; `history_folder_thumbs.dart` was deleted with them.
- `ArchiveScaffold` chrome and `StudioBackdrop` are untouched.
- `SpaceArchiveScreen` (wrapped highlights) is a different screen.
