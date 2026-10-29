# Manage and Trash redesign

Manage and Trash are the second and third modes of the dashboard's view picker.
Both used to speak a plainer register than Home and Passes: 13 pt captions,
Material glyphs, and an empty state built from `titleMedium` text over three
outlined rectangles. This brings them into the wallet's own language.

## Language being matched

`WalletEmptyState` (`lib/shared/widgets/wallet_empty_state.dart`) defines it:

- A 26 pt two-tone headline: a muted line saying where the user is, then an
  ink line saying what to do.
- Glass artwork in the wallet palette (blue `#4C7CFF`, purple `#7C5CBF`, teal
  `#2A9D8F`), animated, and still when reduced motion is on.
- `DocketButton` pills: one solid primary, a quiet secondary beside it.
- Rise-in motion: fade plus a 14 px lift, staggered 70 ms per step.

## Decisions

- **Each view gets its own artwork.** Reusing Home's fanned cards says
  "cards", which is Home's job. Manage animates a row being dragged into a new
  slot (`ManageOrderPreview`). Trash animates a card sinking into a tray and
  rising back out (`TrashTrayPreview`): kept, and recoverable.
- **Empty Manage offers Add and Trash.** Manage hides the dashboard FAB, so
  without its own Add the empty view was a dead end. Trash stays reachable at
  zero documents, which is exactly when someone looks for what they removed.
- **Empty Trash offers "Go to Home".** With nothing to restore, the wallet
  itself is the useful place to land.
- **Populated views open with the same headline.** `WalletListHeadline`
  carries the two-tone pair left-aligned over the list, plus one 13 pt hint
  naming the gestures. Left-aligned because it heads a list.
- **Glyphs are Lucide, not Material.** `assets/icons/` holds UI glyphs from
  Lucide 1.31.0 at stroke 1.5, the same set and weight as the pass icons.
  `LineIcon` renders them and reads size and colour from `IconTheme`, so they
  drop into `DocketButton.leading` like an `Icon`.
- **Trash rows look removed.** Their mini card is drawn at reduced opacity so
  the list reads as "out of the wallet" at a glance.
- **"Empty Trash" is a quiet secondary pill under the list**, confirmed by a
  destructive dialog. It loops the existing `permanentlyDeleteItem` path one
  item at a time rather than adding a second deletion path, so attachment
  cleanup and the write interlock stay in one place.

## Out of scope

Swipe-to-restore, undo after permanent delete, and auto-purge by age.
