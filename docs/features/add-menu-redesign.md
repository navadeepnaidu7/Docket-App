# Add menu redesign — squircle tiles + morphing sheet

Issue: [#31 — Navigation Enhancement: Redesigned + add layout](https://github.com/navadeepnaidu7/Docket-App/issues/31)
Branch: `feature/add-menu-redesign` (off `master`)
Status: **built** — `flutter analyze` clean for these files, 404 tests pass.
On-device behaviour is still unverified (see Verification).

## What is wrong today

The `+` FAB opens `showModalBottomSheet`, and every subsequent choice **pops that
sheet and opens another one**. Picking Train on the Passes tab means: sheet slides
down, screen is briefly bare, a second sheet slides up. Three route transitions to
reach a PNR field.

| Tab | Today |
|-----|-------|
| Docs | `AddItemSheet` -> pop -> `PassportTypeSheet` / `AddIdSheet` -> pop -> push entry screen |
| Passes | `AddPassSheet` -> pop -> `AddPassMethodSheet` -> pop -> push `PnrEntryScreen` / picker |

Both are full-width list rows with a coloured icon chip on the left
(`AddOption`, `EntryMethodCard`, `_IdOption`) — three near-identical row widgets
in three files, none of which match the mockup.

## What we are building

**One sheet, one route.** The `+` opens a single modal sheet that *morphs* in
place: the tile grid cross-fades out, the next grid cross-fades in, and the sheet
grows or shrinks around it — anchored at the **bottom edge**, so extra content
glides upward and the bottom of the sheet never moves.

Layout follows the mockup: a header (`✕` / `←` on the left, "Add" centred), a
left-aligned section title and subtitle, then a grid of squircle tiles with the
label sitting *below* the tile, not inside it.

The FAB stays tab-aware, as today — `_showAddSheet` already branches on
`_tabCtrl.index == 0`. Tab 0 opens the Documents tree, tab 1 the Passes tree.

**Tab naming.** The two tabs are labelled `IDs` and `Passes`, hardcoded at
`pill_tab_bar.dart:81` and `:100` (`showNavLabelsProvider` toggles label
*visibility* only, not the text). The mockup heads the first panel "Documents"
and names one of its two tiles "IDs" — so from the **IDs** tab the user would open
a **Documents** panel containing an **IDs** tile, with the same word meaning two
different scopes one tap apart.

Resolution: keep the mockup's "Documents" header and narrow the tile to
**"ID Cards"**, which is what that sheet already calls itself today
(`AddIdSheet` title: "Add ID card"). Documents = Passport + ID Cards. The tab
label itself is not touched by this issue.

### Step trees

```
Documents (tab 0, "IDs")                Passes (tab 1)
  Passport ──> Passport kind             Trains  ──> Enter PNR / Photo / PDF
  │              E-Passport   (chip art)  Bus     ──> Photo / PDF
  │              Regular      (plain art) Flights     [Soon]
  ID Cards ──> ID type                    Movies  ──> Photo / PDF
                 PAN                      Events      [Soon]
                 Aadhaar                  More        [Soon]
                 Driving Licence [Soon]
                 Voter ID        [Soon]
```

Grid shape: Documents = 2 columns (tall tiles, two-line subtitle). Passes =
3 columns, 1:1 tiles. Method steps (PNR / Photo / PDF) = 3 columns, 1:1.

Only `train`, `bus` and `movie` exist in `PassInputCategory` and on the server.
**Flights, Events and More render dimmed with a "Soon" badge and do not accept
taps** — the same treatment `AddIdSheet` already gives Driving Licence and Voter
ID, so there are no dead-end taps into an endpoint that would mis-classify.

Terminal steps close the sheet, then run the existing handlers unchanged
(`_handleSource`, `_pickPhoto`, `_pickFile`, `_submitFile`, `_openPassportEntry`,
`_openIdEntry`). **No ingestion, auth or storage logic changes in this issue.**

## The morph — mechanics

This is the load-bearing part and the one that fails silently. It looks correct at
one content height and collapses or snaps at another, and no test catches that.

Host widget: `lib/shared/widgets/morph_sheet.dart`.

```dart
AnimatedSize(
  alignment: Alignment.bottomCenter,   // grow upward — NOT the topCenter default
  duration: const Duration(milliseconds: 380),
  curve: Curves.easeOutQuint,          // matches studioPageRoute
  child: ConstrainedBox(
    constraints: BoxConstraints(maxHeight: maxSheetHeight),
    child: SingleChildScrollView(child: currentStepBody),
  ),
)
```

Three specific traps:

1. **`alignment` must be `bottomCenter`.** The default (`topCenter`) pins the top
   edge and grows *downward*, off the bottom of the screen. Bottom-anchored is
   what "glides above" means and it is a one-word difference.

2. **`AnimatedSwitcher`'s default layout builder defeats `AnimatedSize`.** It
   stacks the outgoing and incoming children, so the Stack is instantly as tall as
   the taller of the two and the size *snaps* instead of animating. Fix — take the
   outgoing children out of the layout:

   ```dart
   layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
     alignment: Alignment.topCenter,
     children: <Widget>[
       ...previous.map((Widget w) => Positioned(left: 0, right: 0, top: 0, child: w)),
       if (current != null) current,
     ],
   )
   ```

   `Positioned` children do not contribute to a `Stack`'s size, so the Stack
   measures the incoming child alone while the outgoing one fades over the top.

3. **Height cap.** `maxSheetHeight = MediaQuery.sizeOf(context).height * 0.82`
   minus the top safe-area inset. `ConstrainedBox` + `SingleChildScrollView`
   yields `min(content, cap)`, so short steps stay short and a long step scrolls
   instead of overflowing.

Transition: paired fade + a small **vertical** drift (4% of the step's height).
The plan first called for a directional horizontal slide, which does not survive
contact with `AnimatedSwitcher`: it builds the transition once per child and
replays the outgoing child's own animation in reverse, so an incoming-from-right
tween sends the outgoing child back out to the right too. Distinguishing them
means threading direction through the builder for a cue the size morph already
carries. Vertical drift reads identically forwards and backwards, so there is no
wrong-direction artifact.

Navigation and dismissal:

- Header button is `✕` at depth 0 and `←` deeper, cross-faded via a small
  `AnimatedSwitcher`.
- `PopScope(canPop: depth == 0)` — Android back pops one *step*, and only closes
  the sheet from the root. Without this, system back dumps the whole flow from a
  sub-step, which is the bug the redesign exists to remove.
- `HapticService.select()` on each morph; `HapticService.confirm()` stays on open.

The mockup's top-right circle is decorative and has no action behind it — omitted.

## Passport artwork

The issue asks for a realistic passport only in the Documents grid, and for the
kind step to show an e-passport cover (chip symbol) versus a plain cover.

Source, per your note, is Wikimedia Commons — both files verified:

| File | Author | Licence | Use |
|---|---|---|---|
| [`Indian_Passport.svg`](https://commons.wikimedia.org/wiki/File:Indian_Passport.svg) | Swapnil1101 | CC BY-SA 4.0 | Passport tile, Regular kind |
| [`Indian_Passport_(e-Passport,_2024).svg`](https://commons.wikimedia.org/wiki/File:Indian_Passport_(e-Passport,_2024).svg) | FireDragonValo | CC BY-SA 4.0 | E-Passport kind |

Both are 400x568 SVGs of the navy cover with the gold emblem — exactly the two
variants the issue describes.

**Licence obligations, and they are real.** CC BY-SA 4.0 requires attribution and
requires that *the asset and any modified version of it* stay under CC BY-SA. It
does **not** relicense the app: bundling an independent asset is aggregation, not
adaptation. But if we recolour, crop or restyle either SVG, that derived file is
CC BY-SA and must be shipped as such. Concretely:

- Keep the SVG masters in `tool/design_src/passport_covers/` with an adjacent
  `README.md` naming author, source URL and licence.
- Add `ATTRIBUTIONS.md` at the repo root.
- Register at runtime so the credit ships inside the binary, not just the repo:
  `LicenseRegistry.addLicense()` in `main.dart`, surfaced by a "Licences" row in
  Settings -> About (`showLicensePage`). Nothing in the app reads
  `LicenseRegistry` today; this adds the first entry.

**Bundle the SVGs verbatim.** The plan originally called for rasterizing to PNG,
following the emblem's precedent, on the assumption these files were "gradients
and fine detail". Inspecting them showed otherwise: 94-98% of each file is
`<path d="...">` data, with **no** gradients, filters, masks, text or embedded
images — just two flat fills, navy `#070930` and gold `#f4ca81`. That is the case
`flutter_svg` renders exactly, and the menu draws the art at two different
heights, so vector wins. Shipping unmodified also makes the CC BY-SA position
trivial: redistribution, not adaptation.

```
assets/wallet/passport/covers/passport_regular.svg     (109 KB)
assets/wallet/passport/covers/passport_epassport.svg   (83 KB)
```

Registered in `AppAssets` under the existing "Wallet: passport" block and in
`pubspec.yaml`. Both render correctly under `flutter_svg` 2.0.17 — verified by
golden (`test/passport_cover_art_test.dart`). Two `unhandled element` warnings
for `<inkscape:path-effect>` and `<sodipodi:namedview>` are editor metadata with
no visual effect.

Parsing ~100 KB of path data is not free, so `PassportCoverArt.warmUp()` primes
the SVG cache from a post-frame callback in the dashboard's `initState` — after
first paint, deliberately not in `main()`, which is already on a font budget.

Widget: `lib/features/passport/presentation/widgets/passport_cover_art.dart` —
`PassportCoverArt({required PassportCoverVariant variant, required double height})`,
drawing the PNG with a soft drop shadow and a slight rotation, matching the
mockup's floating-book look. Dark mode keeps the navy cover as-is (it reads on
both grounds) and only the tile behind it changes.

## Tiles

`lib/shared/widgets/squircle_tile.dart` — `SquircleTile` + `SquircleTileGrid`.

- Fill: `isDark ? onSurface.withValues(alpha: 0.06) : onSurface.withValues(alpha: 0.04)`
  — the mockup's soft grey, expressed against the cream ground rather than a raw
  hex, per the design-token convention.
- Radius: 26 on a 1:1 tile via `BorderRadius.circular`. No squircle package —
  `ContinuousRectangleBorder` is not an Apple squircle and a new dependency is not
  worth the delta at this size. `AppTheme.radiusCard` (20) reads too tight against
  the mockup's proportions, so this is a deliberate local value.
- Icon: thin line glyphs at 34 px, `scheme.onSurface` — `Icons.train_outlined`,
  `Icons.directions_bus_outlined`, `Icons.flight_outlined`,
  `Icons.local_activity_outlined`, `Icons.theater_comedy_outlined`,
  `Icons.more_horiz_rounded`.
- Label sits **below** the tile: 13 px, `w700`, centred, up to two lines.
  Subtitle (Documents grid only) in `AppTokens.secondaryLabel(scheme)`.
- `soon: true` -> 0.48 opacity, "Soon" pill reusing the `_IdOption` badge styling,
  `onTap: null`, `Semantics(enabled: false)`.
- Press feedback via the existing `BounceTap` (`scaleFactor: 0.97`).
- **`maxTileWidth` (148).** Tile height follows tile width through an aspect
  ratio, and width follows the available space — so on a wide surface the squares
  inflate until the grid outgrows the sheet's height budget and the labels scroll
  out of reach. Found by the test suite: on the default 800x600 test surface,
  five tap-based tests missed their targets. A phone never reaches the cap
  (3 columns inside the sheet is ~95 pt/tile at 390 pt wide), so this only
  engages on tablets and large-display modes.

**Label lengths are constrained by the ~95 pt tile.** The mockup's
"Bus / Public Transport" wraps to four lines there and blows out the row, so the
tile reads **"Bus"** — which is also more honest, since `bus` is the only transit
category the server classifies. Passport sublabels were shortened to
"Has an NFC chip" / "No chip" for the same reason.

## Files

**New**

| Path | Contents |
|---|---|
| `lib/shared/widgets/morph_sheet.dart` | `MorphSheet` host, `MorphStep` model, `showMorphSheet()` |
| `lib/shared/widgets/squircle_tile.dart` | `SquircleTile`, `SquircleTileGrid` |
| `lib/features/dashboard/presentation/widgets/add_menu.dart` | Documents + Passes step trees, callback wiring |
| `lib/features/passport/presentation/widgets/passport_cover_art.dart` | Cover art, regular / e-passport variants |
| `assets/wallet/passport/covers/*.svg` | Cover art, bundled verbatim |
| `tool/design_src/passport_covers/` | SVG masters + licence README |
| `lib/core/assets/asset_licenses.dart` | `LicenseRegistry` entry for the CC BY-SA art |
| `ATTRIBUTIONS.md` | CC BY-SA credits |
| `test/add_menu_test.dart` | Morph, back-stack and gating tests (8) |
| `test/add_menu_golden_test.dart` | Visual regression, light + dark (3) |
| `test/passport_cover_art_test.dart` | Cover art renders (1) |

**Changed**

- `dashboard_screen.dart` — `_showAddSheet` collapses to one call;
  `_showPassportTypeSheet` deleted (its two callbacks move into the tree).
- `add_pass_flow.dart` — `showAddPassFlow` builds the Passes tree.
  `_handleSource` / `_pickPhoto` / `_pickFile` / `_submitFile` untouched.
- `app_assets.dart`, `pubspec.yaml`, `main.dart` (licence registration),
  Settings -> About (licences row).

**Retired** — each has exactly one caller, all of which this change rewrites:

- `add_item_sheet.dart` — **whole file deleted.** The plan said to keep
  `TicketsComingSoonSheet`; it turned out to have zero callers anywhere (it
  predates the passes wallet), so nothing in the file survived.
- `add_pass_sheet.dart`: `AddPassSheet`, `AddPassMethodSheet` — file deleted.
- `add_id_sheet.dart`: `AddIdSheet` — file deleted, content became the ID-type
  step. The `_IdOption` "Soon" badge treatment carried over to `SquircleTile`.

`EntryMethodCard` is **not** retired — `id_entry_screen.dart` still uses it.

One caller the plan missed: the easter-egg drawer's "add passport" shortcut also
called `_showPassportTypeSheet`. It now calls `showPassportKindMenu`, which roots
the same sheet at the kind step.

## Phases

Split by how a mistake fails, per CLAUDE.md.

| # | Work | Why |
|---|---|---|
| 1 | Fetch SVGs, `AppAssets` + pubspec, attribution plumbing, `PassportCoverArt` | Licence handling and asset-path correctness fail silently |
| 2 | `MorphSheet` host — size anchoring, layoutBuilder, height cap, `PopScope` | Silent column: snaps and collapses that look fine at one height |
| 3 | `SquircleTile` + `SquircleTileGrid` | Loud — compiler and widget tests catch it |
| 4 | Documents + Passes step trees on the finished host | Loud — wiring errors surface immediately |
| 5 | Retire old sheets, tests, `flutter analyze` + `flutter test` | Deletion needs the caller audit above to be right |

The plan earmarked phases 3 and 4 for `agy`. They were written directly instead —
each landed under ~160 lines, below the threshold where a delegation brief costs
less than just writing the code.

## Verification

Done — none of these widgets had any test before this change.

`test/add_menu_test.dart` (8, all passing):

- Root step shows the Documents grid with real cover art.
- Tapping Passport morphs to the kind step, removes the category grid, and the
  `MorphSheet` count stays at 1 — proving it is a morph, not a second route.
- `←` returns to the root and reverts to `✕`; `✕` dismisses.
- Android `popRoute` at depth 1 pops one step and leaves the sheet open.
- Choosing a kind closes the sheet and reports the choice.
- Soon tiles carry `onTap: null`, do not fire, and leave the sheet in place.
- The sheet renders and morphs inside a 320x568 surface with no exception.

`test/add_menu_golden_test.dart` (3) — Documents, kind step, Passes grid, train
method step, plus dark mode, at 390x844. `test/passport_cover_art_test.dart` (1)
covers the artwork itself.

Full suite: **404 passing**. `flutter analyze`: 5 infos, all pre-existing in
`settings_screen.dart`, `manage_cards_view.dart` and `chip_payload.dart` — none
in the new or changed files.

Note the goldens render text as fallback boxes: `google_fonts` cannot fetch Inter
in the test sandbox. They verify layout, geometry and colour, not typography.

Still unverified, and must be said so in the PR:

- Whether the morph reads as smooth at 60/120 Hz on a real device.
- Haptic timing against the visual.
- Cover art at real screen density, and the cost of the first SVG parse.
