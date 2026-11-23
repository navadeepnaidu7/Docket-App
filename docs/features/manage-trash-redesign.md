# Manage and Trash

Manage and Trash are the second and third modes of the dashboard's view picker
(`DashboardViewMode { home, manage, trash }`). This is the maintained contract for both,
replacing the separate manage-redesign, trash swipe and illustration notes.

Status: implemented; on-phone checks via hot reload (29 Oct 2026). Owners:
`lib/features/dashboard/presentation/widgets/` (`manage_cards_view.dart`, `trash_view.dart`,
`wallet_row_tile.dart`, `swipe_to_empty_trash.dart`, `manage_order_preview.dart`,
`trash_tray_preview.dart`), `lib/shared/widgets/wallet_list_headline.dart`,
`lib/shared/widgets/line_icon.dart`, and `_removeWalletItem` in `dashboard_screen.dart`.
Tests: `test/manage_view_test.dart` and the trash view tests.

## One wallet, three registers

| Mode | Shows | Register |
|---|---|---|
| Home | one card at a time, full art | visual, gestural |
| Manage | every document as a row | textual, actionable |
| Trash | removed documents | recovery |

Manage verbs: **order** (drag handle), **reveal** (tap a row to jump Home to that card),
**remove** (swipe left, Cupertino confirm), **account** (count line and a route into Trash).
Out of scope by decision: rename (no user-editable name in the schema), passes (own tab and
archive), field editing (entry screens do that), bulk multi-select (competes with drag for a
2-6 document wallet), and the category filter (Home only, dev-flagged).

## Visual language

Both views speak `WalletEmptyState`'s language: a two-tone 26 pt headline (muted "where you
are", ink "what to do"), glass artwork in the wallet palette (`#4C7CFF`, `#7C5CBF`, `#2A9D8F`),
`DocketButton` pills, and a fade + 14 px rise staggered 70 ms. Populated views open with
`WalletListHeadline` left-aligned over the list plus one 13 pt gesture hint. No in-view title
under the shared "Manage" header.

- **Rows** (`WalletRowTile`, shared by both views): title is the document **type**
  (`Passport`, `PAN Card`), number right-aligned on the same ~48 pt line, headed by a mini card
  in that document's own `WalletPalette.forItem` gradient. Type metadata comes from
  `IdDocumentCatalog`; no possessive holder names, no type chips, no tinted icon plates.
  Trash rows draw the mini card at reduced opacity.
- **Glyphs** are Lucide 1.31.0 at stroke 1.5 (`assets/icons/`), rendered by `LineIcon`, which
  reads size and colour from `IconTheme`.
- **Artwork**: Manage animates a row dragged into a new slot (`ManageOrderPreview`); Trash
  animates an ID rising out of a tapered, ribbed wastebasket and settling back
  (`TrashTrayPreview`, 220 x 164, 5.4 s cycle, a directly repainted `CustomPainter`).
  Reduced motion holds a readable still (Trash: the raised-card frame). Dark mode uses its own
  treatment over `surfaceContainerHighest` with lighter blue/violet/teal markings and tinted
  rims; light-mode formulas are unchanged. The final Trash silhouette was not re-checked on the
  phone in light mode.
- **Empty states**: Manage offers Add and Trash (Manage hides the FAB, and Trash is where
  people look at zero documents). Empty Trash offers "Go to Home".

## Structure notes (silent failure traps)

- The list is a `SliverReorderableList` inside a `DecoratedSliver` in the page's own
  `CustomScrollView`, so the section shrinks to its content. `DecoratedSliver` carries the same
  tokens as `StudioSection` but is a parallel expression: change both if the grouped look
  changes. It does not clip, so a row splash may paint past the rounded corner.
- Use `onReorderItem`, not the deprecated `onReorder`; carrying the old `newIndex -= 1`
  correction forward would be an off-by-one on downward drags.
- No `Theme(data: theme.copyWith(...))` in build: it invalidates every row each rebuild. The
  drag proxy styling lives in `proxyDecorator`, which runs once per drag. The perf effect was
  never measured.
- **Reveal**: `_DashboardScreenState` owns a `ValueNotifier<String?>` request consumed and
  cleared by `IdsTab`. The mode switch remounts `IdsTab`, so the jump happens post-frame once
  the controller has clients. The target index is into the **filtered** list; a card hidden by
  the filter must clear the filter first, or the reveal lands on the wrong card. A request for
  a card that is not present is dropped, never landed on a neighbour.
- **Removal** touches three stores that must agree or the carousel order drifts silently:
  `trashProvider.moveToTrash`, the live list provider, and
  `walletOrderProvider.updateOrderOnItemRemoved`. `_removeWalletItem(Object)` holds that
  sequence and is the only place any surface removes a document; each surface (long-press
  sheet, ID attachment sheet, Manage swipe) keeps only its own confirmation UI.

## Empty Trash control

`SwipeToEmptyTrash`, pinned below the independently scrolling list:

- 68 pt graphite track, 8 pt inset, 52 pt satin handle; 24 pt side padding, 20 pt bottom
  clearance inside the safe area. Drag starts on the handle and keeps the grab offset; short
  swipes and pointer cancel spring home. **Velocity alone never completes it.**
- Releasing at 92%+ settles the handle and crossfades the same footer into one two-line
  question, "Delete N docs permanently?" ("1 doc" singular), with Cancel and Delete. No
  popup, no subtitle. Cancel, Back or Escape restores the slider.
- Only a separate Delete activation calls the deletion provider, which loops the existing
  `permanentlyDeleteItem` path one item at a time, so attachment cleanup and the write
  interlock stay in one place. Progress stays in the footer; errors use the scaffold.
- Explicit sliding / settling / confirming / deleting states; repeat activation latched;
  outgoing children take no pointer, focus or semantics input; row actions blocked while
  deleting. Any change to the reviewed document identities resets confirmation, and the set is
  rechecked when Delete fires.
- Keyboard and screen readers reach the same inline confirmation, with Cancel focused first.
  RTL mirrors the gesture. The idle label's light sweep pauses while dragging/confirming and is
  static under reduced motion. Haptic preferences are respected.

The Delete action itself has not been exercised on the phone (no documents were deleted for
QA); it is covered by widget tests.

## Test traps

- `pumpAndSettle` times out on anything containing the wallet carousel (continuous
  animation); use counted `pump()`s.
- `passportLoadingProvider` and `idLoadingProvider` default to `true`; an un-overridden
  `IdsTab` renders a spinner and never builds the `PageView`, so a test can pass for the wrong
  reason.

## Out of scope

Swipe-to-restore, undo after permanent delete, auto-purge by age.
