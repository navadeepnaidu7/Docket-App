# Archive

The Passes-tab **Archive**: a category grid at the root, and inside each category one
overlapping deck of full pass faces over a finite scrubber. Replaces the separate
archive-folders and archive-scrubber notes and the retired movie poster grid.

Not to be confused with `pass-deck.md`, the *live* Passes tab's experimental horizontal
carousel. Different screen, no shared code.

Status: implemented and checked on a phone via hot reload (20 Nov 2026); a separately
installed final APK was not checked. Owners: `lib/features/tickets/presentation/history/`
(`passes_archive_screen.dart`, `history_folder_tile.dart`, `history_category_screen.dart`,
`archive_pass_deck.dart`). Tests: `archive_pass_deck_test.dart`, `archive_layout_test.dart`,
`pass_history_folders_test.dart`.

## Category grid (root)

- `HistoryFolderTile`: a bundled photo cover (1.55:1) above a neutral caption panel of at
  least 76 dp. Category name left (Geist 17 semibold); the real count right (28 semibold) with
  `pass`/`passes` (11) beneath. One accessible label carries name and count.
- Two columns, 16 dp gutter, 20 dp row spacing; large text grows the caption and drops to one
  column. Empty categories stay hidden; folder order and counts come from the folder provider.
- `AppTheme.elevated`, existing ink/secondary-label tokens, card radius, a fine edge and a faint
  light-mode contact shadow. Press: `BounceTap` at 0.972 with one selection haptic; reduced
  motion keeps scale 1. Slight runtime dark-mode veil on the photos.
- Covers are category artwork, not previews of a booking: `assets/archive/covers/`
  (trains, movies, buses; crops 76% / 55% / 64% down). Pexels License; photographers, URLs and
  SHA-256 hashes in `tool/design_src/archive_covers/sources.json`, credits in the in-app
  Licences page. Decode near display size.

| Category | Photograph | Photographer |
|---|---|---|
| Trains | [Running Indian Train](https://www.pexels.com/photo/running-indian-train-20309650/) | GOWTHAM AGM |
| Movies | [Number in a Red Seat](https://www.pexels.com/photo/number-in-a-red-seat-11718584/) | Linda Gschwentner |
| Buses | [Photo of a Coach on a Road in Perspective](https://www.pexels.com/photo/photo-of-a-coach-on-a-road-in-perspective-16962781/) | 虎 曼 |

## The deck

`HistoryCategoryScreen` pushes `ArchivePassDeck` for every category, movies included (the
old year-sectioned poster grid is gone; movie art rules are in `movie-logo-glance.md`). It
re-derives from `passListProvider`, so removing the last pass shows the empty state.

### One position value

`AnimationController.unbounded` holds a fractional pass index. Deck transforms, the scrubber
marker and the date readout all render from it, so nothing disagrees mid-drag or mid-spring.

### One pass per gesture

Release velocity decides only **whether** a drag that stopped short of halfway still commits
to the next pass; it is not projected forward. An ordinary phone flick is 2000-4000 px/s,
which would cross 3-5 passes and lose the user's place. A long drag still travels as far as the
finger. Crossing the archive is the scrubber's job. Interrupted snaps cancel their completion
future, so an old snap cannot reset a newer selection.

### Scrubber

- A finite ruler spanning the archive: first pass at the left inset, last at the right. Card
  swipes move its marker; taps and drags on it select the matching position directly, settling
  to the nearest pass on release, so one sweep reaches the end of any archive.
- Fine rounded ticks with faded edges and the coral marker. The selected month/year sits in a
  compact badge above it, clamped inside the viewport; a quiet ordinal ("5 of 9") below gives
  context for repeated dates. A one-pass folder centres the marker with no travel.
- Uses existing `AppFonts` and theme surface/label tokens.

### Haptics

`_detent()` fires a selection haptic per notch crossed, rate-limited to one per 28 ms so a
fast scrub is a ruler, not a buzz. The landing detent clicks only if the drag did not already
click past that notch. Running off either end fires one heavier impact.

### Taps and removal

Every card the viewport shows takes a tap and settles onto it; wrapping neighbours in
`IgnorePointer` ate taps on a card half in view that looked like a button. Removal (long
press, `pass-delete.md`) is gated on `interactive`, i.e. the focused card only: a long press
on a half-covered card is more likely a mis-grab than an intent to delete.

### Accessibility

Dragging and scrubbing are gestures a screen reader cannot perform, and non-focused cards are
`hidden`. The scrubber therefore carries `Semantics(slider: true)` with increase/decrease
actions and an "N of M" value; without it the folder is one unreachable card. The focused
index is a separate `ValueNotifier` so the node rebuilds once per pass, not per frame.

## Known gaps

- `_MovieArchiveCard`'s 76 dp title band and `_DateReadout`'s fixed column clip past roughly
  1.4x text scale rather than grow.
- Hardware check of the final installed APK in both themes.
