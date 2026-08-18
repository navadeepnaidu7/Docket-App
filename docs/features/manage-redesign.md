# Manage redesign — the wallet index

Branch: `feature/add-menu-redesign` (continues the design-system pass; may want its own branch off `master`)
Status: **built** — `flutter analyze` clean for these files, 422 tests pass (14 new).
On-device behaviour is still unverified (see Verification).

Revised once after the first build was reviewed: the row design was rejected and
replaced. See "Row design, take two".

## What Manage is today

`DashboardViewMode { home, manage, trash }`. Manage renders `ManageCardsView`
(`lib/features/dashboard/presentation/widgets/manage_cards_view.dart`, 346 lines),
reached from the header nav title's `ViewPickerExpanded`, where it sits *above*
Home in the menu.

It does exactly one thing: drag to reorder the wallet carousel. Nothing in it is
tappable — `ManageCardTile` has no `InkWell`, only a `ReorderableDragStartListener`
on the handle. It is a dead end.

## Three complaints, three separate causes

### "Out of order" — it renders a second title under the first

`DashboardHeader` already shows the nav title **"Manage"** (tappable, opens the
picker). Then `ManageCardsView` renders its own heading at lines 120-139:

```
Manage                     <- shared header, 20 px above
Wallet order               <- the view's own titleSmall
Drag to reorder how cards appear on Home.
```

Two titles, one gap apart. Trash mode renders no heading at all, so the two
sibling modes disagree about whether a view titles itself.

### "Not consistent" — it predates the design system

| Line | Today | Should be |
|---|---|---|
| 38, 52 | `CupertinoIcons.book_fill`, `creditcard_fill` — filled glyphs | Lucide line icons, per 81e752a |
| 39 | `Color(0xFF007AFF)` iOS blue for passports | `scheme.primary` (`#1A3A6B`) |
| 70, 227 | `ink.withValues(alpha: isDark ? 0.45 : 0.55)` | `AppTokens.secondaryLabel(scheme)` |
| 143-164 | `DecoratedBox` + `ClipRRect` + `DecoratedBox` reimplementing a grouped card | `StudioSection` |
| 115 | `ink.withValues(alpha: isDark ? 0.08 : 0.06)` | `AppTokens.separator(scheme)` |

`trash_view.dart` has the same three problems with *different* hardcoded values —
`Color(0xFF4C7CFF)` for the passport blue where Manage uses `0xFF007AFF`, and
`GoogleFonts.inter` sizes inline instead of `theme.textTheme`. The same concept is
drawn two ways in two files rendered by the same picker.

### "Sluggish" — one real cause, one contributing

**Primary — `Theme(data: theme.copyWith(...))` at lines 165-169, inside `build`.**
`ThemeData.copyWith` constructs a complete new `ThemeData` on every build, and the
result is never `==` the previous instance. Every descendant that read
`Theme.of(context)` is therefore invalidated: `ManageCardTile` (line 224),
`_TypeChip` (317), and `_ManageRowDivider` — which calls `Theme.of` **three times**
in one expression (332-335). So any rebuild of `ManageCardsView` rebuilds every row
and every divider. And `ManageCardsView` is constructed inline inside
`dashboard_screen.dart`'s build (line 644), so it rebuilds whenever the dashboard
does.

The `copyWith` exists only to null out `canvasColor` and `shadowColor` for the drag
proxy. Both can be handled by `proxyDecorator` instead, which is called once per
drag rather than once per build.

**Contributing — two 350 ms cross-fades run simultaneously on entry.** Switching to
Manage fades `WalletBackdrop` out (dashboard_screen 508-533) while the mode
`AnimatedSwitcher` fades the views (659-689). For the first ~350 ms the frame paints
the gradient backdrop, the outgoing carousel *and* the incoming list.

**Not a cause, contrary to first read:** the `ClipRRect` at line 157 uses the default
`Clip.antiAlias`, which does not `saveLayer`. It adds a clip layer around a scrolling
child and is worth dropping with the hand-rolled chrome, but it is not the cost.

## What Manage becomes

Home, Manage and Trash are one wallet in three registers:

| Mode | Shows | Register |
|---|---|---|
| Home | one card at a time, full art | visual, gestural |
| **Manage** | **every card at once, as rows** | **textual, actionable** |
| Trash | removed cards | recovery |

"Every card at once" implies four verbs. Manage currently implements one.

1. **Order** — drag to set carousel order. *Exists.*
2. **Reveal** — tap a row to jump Home to that card. **New.** Today Manage is a
   dead end; the list that shows you everything cannot take you to any of it.
3. **Remove** — row action moves the card to Trash. **New here.** Today deletion is
   a *long-press on a Home card* (`_showDeleteDialog` / `_showDeleteIdDialog`),
   which is undiscoverable and absent from the one view that lists everything.
4. **Account** — a count line and a route into Trash, so the three modes read as
   one system rather than three unrelated screens.

### Deliberately out of scope

- **Rename.** Neither `PassportProfile` nor `IdDocument` has a user-editable display
  name — titles are derived (`"$firstName's Passport"`). Adding one is a storage
  schema change, not a redesign.
- **Passes.** Separate tab, separate repository, its own archive. Manage stays
  documents-only, as today.
- **Editing document fields.** That is what the entry screens are for.
- **Bulk multi-select.** Drag-to-reorder and tap-to-select compete for the same
  gesture, and with a realistic wallet (2-6 documents) the Edit/Done ceremony costs
  more than it saves.
- **The category filter.** `walletFilterProvider` is dev-flagged and lives on Home.
  A list that shows every card, each headed by its own coloured mini card,
  already does the filter's job better; leave the flag where it is.

## Structure

```
┌ Manage ─────────────────────────── (shared header, unchanged)
│
│  3 documents · drag to reorder      <- one quiet caption line, replaces
│                                        the competing "Wallet order" title
│  ┌─────────────────────────────────────┐
│  │ ▐▓▌  Passport            Z3456789 ⠿ │
│  ├─────────────────────────────────────┤
│  │ ▐▒▌  PAN Card          ABCDE1234F ⠿ │
│  ├─────────────────────────────────────┤
│  │ ▐░▌  Aadhaar Card  4321 8765 0987 ⠿ │
│  └─────────────────────────────────────┘
│      ^ mini card in that document's own WalletPalette gradient
│
│  Trash · 2 items              >     <- footer row, opens trash mode
└
```

- **No in-view title.** The caption ("3 documents · drag to reorder") carries the
  instruction the old subtitle carried, at caption weight, so it does not read as a
  second header.
- **Rows are tappable** (reveal) with a **trailing drag handle** (order). Swipe-left
  reveals Remove — `Dismissible` with `confirmDismiss` wired to the existing
  Cupertino confirm dialog, so the destructive path keeps its confirmation.
- **`DecoratedSliver`** replaces the hand-rolled chrome, which also removes the
  `ClipRRect` and both `DecoratedBox`es.

  The plan said `StudioSection`. It could not be used: `StudioSection` is a box
  widget, and the list had to become a sliver. `DecoratedSliver` carries the same
  three tokens (`groupedFieldFill`, `radiusCard`, `separator`) that
  `StudioSection` composes, so the rendered chrome matches — but this is a
  parallel expression of that component, not a reuse of it. If the grouped-card
  look changes, both need editing.

- **A `SliverReorderableList` inside the page's own `CustomScrollView`**, not a
  `ReorderableListView` inside an `Expanded`. This fixes a third visual bug that
  the original brief did not name: `Expanded` + a bordered card made the group
  stretch to the full viewport height, so a two-document wallet drew a card
  border down an otherwise empty screen. The section now shrinks to its content
  and the whole page scrolls as one.

- **`onReorderItem`, not `onReorder`.** The latter is deprecated after
  v3.41.0-0.0.pre and hands back a raw `newIndex` that the caller must correct
  with `if (oldIndex < newIndex) newIndex -= 1`. `onReorderItem` has already
  applied that adjustment, so carrying the old correction forward would have
  been an off-by-one that only shows up on downward drags.
- **Footer row into Trash** — makes the picker's third mode discoverable from the
  second, and gives Trash a reason to exist that isn't "hidden in a dropdown".

### Shared row widget

Manage and Trash render the same concept — a document as a row — in two files with
divergent hardcoded colors. Extract one `WalletRowTile` used by both:

```dart
WalletRowTile({
  required Object item,          // PassportProfile | IdDocument
  Widget? trailing,              // drag handle (Manage) | restore+delete (Trash)
  VoidCallback? onTap,
  bool showDivider,
})
```

Type metadata comes from one place. `IdDocumentCatalog.descriptorFor(type)` already
supplies `title`, `shortLabel` and `accentColor` for IDs — Manage uses it at line 46
and Trash ignores it. Passports have no descriptor, so they take `scheme.primary`.
That deletes both hardcoded blues.

Redesigning Manage's rows while leaving Trash's alone would relocate the
inconsistency rather than fix it, so Trash adopts the shared row in the same change.

### Icons

**Take one used bundled Lucide SVGs. Reverted — see below.** No icon assets were
added in the end; the two glyphs that remain (drag handle, Trash actions) are
Material.

### Row design, take two

The first build gave each row a Lucide glyph on a translucent tinted plate, a
two-line title/subtitle, and a coloured type chip beside the title. All three
were rejected on review, and the objections were right:

- **The chip was redundant.** The row read `Navadeep's Passport` with a chip
  next to it saying `Passport` — the same word twice. IDs were worse: the title
  `Navadeep's ID` said almost nothing while the chip carried the only real
  content (`PAN`).
- **The possessive was noise.** Every document in a personal wallet belongs to
  the same person, so prefixing every row with the holder's name distinguishes
  nothing.
- **The icon plate was decoration.** A generic glyph on a `withValues(alpha:
  0.12)` tint told the reader nothing the title did not already say, and a
  column of them turned the list into a field of coloured dots.

What replaced it:

| Was | Now |
|---|---|
| `Navadeep's Passport` + `Passport` chip | title is the **type**: `Passport`, `PAN Card`, `Aadhaar Card` |
| number as a muted second line | number right-aligned on the **same line** |
| Lucide glyph on a tinted circle | a **mini card** in that document's own `WalletPalette` gradient |
| ~60 pt two-line rows | ~48 pt single-line rows |

The single-line label-left / value-right shape is not a new invention: it is
what `manage_account_screen.dart`'s `_Field` already does, so the app's two
grouped lists now read the same way.

**The mini card is the load-bearing idea.** Manage is an index of cards, so each
row is headed by a miniature of the card it points at, drawn from
`WalletPalette.forItem` — the same palette the wallet backdrop blends. It is not
a picture *of* a category, it is a small version of that specific card, which
also makes the reveal gesture legible: tap the small card, get the big card.

Note this reintroduces `0xFF007AFF` for passports, the blue an earlier section
calls out. That is not a regression: there it was an ad-hoc row accent invented
in `manage_cards_view.dart`; here it is `WalletPalette.passport.primary`, the
card's real system colour, used to draw the card. The complaint was never the
hue, it was a second uncoordinated source of truth.

Empty states lost their tinted-circle-plus-glyph too, replaced by
`GhostCardStack` — three empty card outlines, fanned. Same mini-card shape
language, nothing inside it.

### Reveal — the one piece of real plumbing

Tapping a row must switch `_viewMode` to `home`, ensure the Documents tab is
selected, and page `IdsTab` to that card. `IdsTab` owns its `PageController`
privately and only receives `pageNotifier` as an *output*. It also force-jumps to
page 0 in `didUpdateWidget` whenever the visible id list changes (lines 58-71).

So this needs a `ValueNotifier<String?> _revealItemId` owned by
`_DashboardScreenState`, passed into `IdsTab`, consumed and cleared after the jump.
Two traps, both silent:

1. The mode `AnimatedSwitcher` **remounts** `IdsTab` on the way back from Manage, so
   the jump must happen after the new controller has clients — a post-frame callback
   keyed off the reveal request, not a call at tap time.
2. The target index is an index into the **filtered** `displayItems`, not `items`.
   Manage lists `items` (unfiltered, line 648). If a filter is active and the tapped
   card is filtered out, the reveal must clear the filter first or it silently lands
   on the wrong card.

## Files

**New**

| Path | Contents |
|---|---|
| `lib/features/dashboard/presentation/widgets/wallet_row_tile.dart` | Shared row, type metadata resolution |
| `test/manage_view_test.dart` | Reorder, reveal, remove, row metadata (14 tests) |

**No asset or `pubspec.yaml` changes.** Take one added five Lucide SVGs and an
`AppAssets` block; take two deleted both. `app_assets.dart` is untouched by this
feature.

**Changed**

- `manage_cards_view.dart` — rewritten on `DecoratedSliver` + `WalletRowTile`;
  `Theme(copyWith)` replaced with `proxyDecorator`; `_TypeChip` and
  `_ManageRowDivider` moved into the shared row; `ManageCardTile` deleted.
- `trash_view.dart` — adopts `WalletRowTile` and `GhostCardStack`; drops its
  hardcoded palette and inline `GoogleFonts` sizes; `TrashCardTile` deleted.
- `dashboard_screen.dart` — `_revealItemId` notifier wired to `IdsTab`;
  `_revealWalletItem`; **`_removeWalletItem` extracted** (see below).
- `ids_tab.dart` — consumes the reveal request.


## Order persistence — the silent risk

Removing a card from Manage touches three stores that must agree, or the carousel
order drifts with no error:

1. `trashProvider.moveToTrash(item)` — writes the trash list
2. `passportListProvider` / `idListProvider` — removes the live record
3. `walletOrderProvider.updateOrderOnItemRemoved(id)` — drops it from the order

`reconcileWalletOrder` repairs drift on the next load, but only if it is called;
CLAUDE.md flags it as a standing hazard.

The plan said Manage must call the existing long-press path rather than
reimplement it. That turned out to be the wrong shape: `_showDeleteIdDialog`
opens the **ID attachment tray** as its confirmation, which is the right gesture
for a long-press on a card and quite wrong for a swipe on a list row.

Resolved by separating the two concerns. `_removeWalletItem(Object)` now holds
the three-store sequence and nothing else, and is the single place any surface
removes a document. `_showDeleteDialog` (action sheet), `_showDeleteIdDialog`
(attachment tray) and Manage's swipe (Cupertino confirm) each keep their own
confirmation UI and all three call into it. The silent risk lives in the
sequence, not in the dialog, so that is what got centralised.

## Phases

Split by how a mistake fails, per CLAUDE.md.

| # | Work | Failure mode |
|---|---|---|
| 1 | Icon assets + `AppAssets` + pubspec | Silent — a wrong asset path renders an empty box |
| 2 | `WalletRowTile` + metadata resolution | Loud — compiler and widget tests |
| 3 | Manage rebuilt on `StudioSection`; `proxyDecorator` replaces `Theme(copyWith)` | Loud for layout, **silent for the perf fix** — verify with a rebuild counter, not by eye |
| 4 | Reveal plumbing | **Silent** — lands on the wrong card, or no-ops, and looks plausible either way |
| 5 | Remove wired to the existing delete path | **Silent** — order drift |
| 6 | Trash adopts the shared row; `flutter analyze` + `flutter test` | Loud |

Phase 2 was the only real candidate for `agy` and landed around 250 lines. It was
written directly — a brief precise enough to get the token usage and the
metadata-resolution rules right would have cost more than the code.

Phase 3's perf fix behaved exactly as the "silent" label predicts: the rewrite
looks right and the tests pass either way. Nothing in this change *proves* the
rebuild storm is gone.

## Verification

`manage_cards_view.dart` has no test today (`flutter analyze` currently reports
pre-existing infos in it).

`test/manage_view_test.dart` (12, all passing):

- One row per document, with the type chip drawn from `IdDocumentCatalog`.
- The caption counts documents, and "Wallet order" is gone — pinning that the
  view no longer titles itself under the shared header.
- Tapping a row reveals *that* document, not its neighbour.
- Swipe-to-remove asks first; cancelling leaves both rows in place.
- Confirming reports the removed document.
- Empty wallet renders the empty state rather than an empty stretched card.
- The Trash footer routes to trash mode.
- Dragging a handle writes a complete, permuted order to `walletOrderProvider`.
- `IdsTab` pages to a request set *before it mounts* (the real sequence — Manage
  is on screen when the row is tapped) and clears the request.
- A request for a card that is not visible is dropped, not landed on a neighbour.
- `WalletRowMeta` gives a passport `scheme.primary`, asserted to be neither of
  the two hardcoded blues this change deleted.

Full suite: **420 passing** (was 408). `flutter analyze`: 4 infos, all
pre-existing in `settings_screen.dart` and `chip_payload.dart`. The info that
previously sat in `manage_cards_view.dart` is gone with the rewrite.

Two traps the tests themselves fell into, worth knowing before extending them:

- `pumpAndSettle` **times out** on anything containing the wallet carousel — it
  runs a continuous animation and never reaches a quiescent frame. Use counted
  `pump()`s.
- `passportLoadingProvider` and `idLoadingProvider` both default to **true**, so
  an un-overridden `IdsTab` renders a spinner and never builds the `PageView`.
  The "request is dropped" test passed against that spinner before the overrides
  went in — i.e. it was green for the wrong reason.

Not verified, and must be said so in the PR:

- Whether Manage actually *feels* faster at 60/120 Hz. The `Theme(copyWith)`
  removal is structurally correct but its effect was not measured; there is no
  rebuild-count test (the planned one was not written).
- The entry transition still runs two simultaneous 350 ms cross-fades — this
  change did **not** address that contributing cause.
- Drag-handle ergonomics and swipe-to-remove against a real thumb.
- `DecoratedSliver` does not clip its children, so an `InkWell` splash on the
  first or last row may paint slightly outside the rounded corner. Not visible
  in tests; needs a look on device.
