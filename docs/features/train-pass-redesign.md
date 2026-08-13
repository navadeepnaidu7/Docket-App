# Train pass redesign

Rebuilds the train pass face against `train-pass-card(1).svg` (Figma export, 430x694
artboard, 366x630 card) and replaces the static "Indian Railways" footer with a **dynamic
status band** that cross-fades between live journey messages.

Status: **in progress**. Applies to the wallet glance card and the fullscreen detail
screen. The history archive thumbnail (`HistoryPassCard`) is explicitly out of scope and
keeps its current look.

## What changes

| Before | After |
|---|---|
| Mint/paper "boarding pass" with a route timeline and a train capsule | Warm blush card, editorial serif station codes, two-column data grid |
| `TicketShapeClipper` side notches + dashed tear | Plain rounded rect, r32, one hairline + one dashed rule |
| Fixed "Indian Railways" footer lockup | 90dp band that cycles delay / countdown / platform / on-time over a ghosted wordmark |
| Inter everywhere | Instrument Serif (codes) + Geist (everything else) |

## Design tokens

Measured off the SVG path outlines (`min/max` of every coordinate in each `d=`), not
eyeballed. All values are **card-local** design units on a 366 x 630 canvas — subtract
`(32, 16)` from raw SVG coordinates.

### Palette

| Token | Hex | Use |
|---|---|---|
| `surface` | `#FFF6F6` | card fill |
| `border` | `#EAD5D8` | 1px card outline |
| `ink` | `#1F1619` | station codes, values, QR modules |
| `muted` | `#6B5A5E` | labels, station names |
| `rule` | `#E8D8DA` | both dividers + the dashed connector |
| `qrBorder` | `#E5D1D4` | QR card outline |
| `chipFill` | `#E8F5E9` | booking-status chip |
| `chipInk` | `#2E7D32` | booking-status chip text |

Shadow: `dy 16`, blur 32 (`feGaussianBlur stdDeviation=16`), black at 25%.

The face is **fixed-light in both themes**, matching `WalletPassportCard` and the outgoing
train face. A wallet card is a facsimile of a paper document; it does not invert.

### Type

Instrument Serif has only w400. Geist tops out at w700 — no w800/w900, so nothing in this
design may ask for heavier.

| Element | Font | Size | Weight | Baseline (card y) |
|---|---|---|---|---|
| Station code (`HYD`) | Instrument Serif | 57 | 400 | 88 |
| Station name (`HYDERABAD`) | Geist | 10.75 | 500 | 118 |
| Train name | Geist | 15.5 | 600 | 181 |
| Train number | Geist | 11.7 | 500 | 202 |
| Booking chip (`CNF`) | Geist | 13 | 600 | centred in chip |
| Grid label | Geist | 11 | 500 | 245 / 299 / 353 |
| Grid value | Geist | 15 | 600 | 267 / 321 / 375 |
| Passenger / PNR label | Geist | 11 | 500 | 443 / 493 |
| Passenger / PNR value | Geist | 15 | 600 | 465 / 515 |
| `+2 others` | Geist | 12 | 500 | 464 |

Cap heights were converted at Geist's 0.727 em and Instrument Serif's ~0.70 em, so treat
these as within +/-0.5 of the export rather than exact.

### Geometry

Content inset 24 left and right (content width 318).

```
y  47.7 .. 88     station codes           (left x 24, right edge x 342)
y  75.5           dashed connector        x 24 -> 342, w2, dash 4/4,
                                          masked back to a 31dp gap by each code
y 110.2 .. 118    station names           (left x 24, right edge x 342)
y 144.5           hairline rule           x 24 -> 342, w1
y 169.6 .. 183    train name              x 24
y 171  .. 200     booking chip            x 295, 47x29, r8
y 193.3 .. 202    train number            x 24
y 237  .. 375     data grid               cols at x 24 and x 192
                    row pitch 54, label->value baseline gap 22
y 407.25          dashed rule             x 24 -> 342, w1.5, dash 6/4
y 435  .. 515     passenger + PNR block   x 24, row pitch 50
y 441.5           QR card                 x 272.5, 69x69, r11.5
                    7x7 modules, 6dp cells on 8dp pitch, 7.5 inset
y 540  .. 630     status band             full bleed, h90
```

The QR is vertically centred (476) against the passenger/PNR block (435..515, centre 475).

### Canvas

The design is 366 x 630 (aspect 0.581); `ticketCanvas` is 382 x 620 (0.616) and is shared
with the movie face. Adding `WalletCardMetrics.trainCanvas` / `trainAspect` rather than
changing `ticketCanvas` keeps the movie card untouched.

Differing aspects between the two pass types are safe here: `tickets_tab.dart` puts each
pass on its own `PageView` page and `WalletCardMetrics.resolve` centres the card inside it,
so pages do not need matching heights.

## The status band

The 90dp strip is a flat `#E0E0E0` placeholder in the export, with a 6%-opacity wordmark
hidden underneath it (x 87..279, y 583.5, clipped by the card's bottom edge). That hidden
layer is the intent: a large ghosted word half-bleeding off the bottom.

### Structure

```
 ghosted wordmark   blurred, 6% ink, baseline below the card edge, never changes
 message layer      cross-fades between states, bottom-masked so descenders melt out
 top edge           1px rule at #E8D8DA? -- no: the band is flush, no rule (per export)
```

### Message priority

Computed by a pure function over `(TrainPass, DateTime now)` so it is unit-testable and
does not read the clock from inside `build`. Highest priority first; the band cycles
through every message that applies, ~4s dwell, ~700ms cross-fade.

1. `cancelled` -> "Cancelled"
2. `delayMinutes > 0` -> "45 mins delayed"
3. journey underway and a platform is known -> "Platform 4"
4. countdown -> "4 days to go" / "in 6 hours" / "Departs in 25 min" / "Boarding now"
5. `onTime` -> "On time"
6. idle -> wordmark only

The wordmark is the resting layer, always painted, so a pass with nothing live to say
still reads as designed rather than as an empty strip.

Single-message passes must not run a repeating animation — start the controller only when
there are two or more messages, and dispose it either way.

## Domain changes

`liveStatusLabel` is free text ("Running on time"), which cannot drive styling. Adding
structured fields alongside it — the label stays for the detail screen's Live tab.

```dart
enum TrainRunState { scheduled, onTime, delayed, arrived, cancelled }
```

On `TrainPass`:

- `runState` — `TrainRunState`, wire `"runState"`, defaults to `scheduled`
- `delayMinutes` — `int?`, wire `"delayMinutes"`, null means unknown (not zero)

Both are optional on the wire; absent fields must not change today's rendering. Platform
comes from the existing `TicketHalt.platform` — origin halt before departure, `nextHalt`
after — exposed as a `platformLabel` getter rather than recomputed in the widget.

`docs/api/passes.md` gets both fields so `../docket_server` matches.

## Files

| File | Change |
|---|---|
| `lib/features/tickets/domain/pass_status.dart` | add `TrainRunState` |
| `lib/features/tickets/domain/ticket_models.dart` | `runState`, `delayMinutes`, `platformLabel`, JSON both ways |
| `lib/features/tickets/presentation/train/train_pass_theme.dart` | new — palette + metrics constants |
| `lib/features/tickets/presentation/train/train_status_band.dart` | new — message model, pure resolver, cross-fading band |
| `lib/features/tickets/presentation/train/train_ticket_face.dart` | rewritten to the new layout; keeps the `TrainTicketFace` / `TrainTicketDensity` public API |
| `lib/features/tickets/presentation/wallet_ticket_card.dart` | switch to `trainCanvas` / `trainAspect` |
| `lib/features/tickets/presentation/ticket_detail_screen.dart` | wrap the face in its own canvas |
| `lib/core/wallet/wallet_card_metrics.dart` | `trainCanvas`, `trainAspect` |
| `lib/main.dart` | warm Geist + Instrument Serif alongside Inter |
| `lib/features/tickets/data/mock_pass_fixtures.dart` | fixtures covering every band state |
| `docs/api/passes.md` | document the two new fields |
| `test/train_status_band_test.dart` | new — resolver priority + countdown formatting |

## Two layout traps, both hit during the build

**`RenderBaseline` loosens and left-pins.** `_computeSizes` lays the child out under
`constraints.loosen()` and places it at `Offset(0, top)`. A `Text` child therefore
shrink-wraps and sits flush left no matter what, so `width` + `textAlign: TextAlign.right`
is silently a no-op — the destination station name rendered from x 192 instead of ending
at 342. Nothing throws, nothing overflows; only a screenshot catches it. `_Baselined` now
wraps the child in a `SizedBox` when a width is given, and
`test/train_pass_face_test.dart` pins the anchoring.

**Do not measure text in `build` to position anything.** The connector rule was first
placed from `TextPainter`-measured code widths. That measurement runs once, before
google_fonts has resolved Instrument Serif, so the rule kept the fallback face's much
wider proportions permanently — visibly too short and pushed right, even after the serif
appeared. Font loading re-lays out a `RenderParagraph`; it does not re-run `build`.

The fix is to let layout do the measuring: the rule spans the full content width and each
code is painted over it on an opaque swatch of the card surface, inset by
`codeConnectorGap`. The visible dash run is whatever gap the codes leave, it re-lays out
by itself when the font swaps, and codes wide enough to meet in the middle mask the rule
off entirely rather than having it drawn through them.

## Risks

- **Offline first run.** Nothing is bundled; `main()` warms GoogleFonts with a 900ms cap and
  falls back. Two new families widen the window where a cold offline install renders in the
  fallback face — most visibly the 57dp serif codes. Warming them in `main()` limits this to
  the very first launch, but it cannot be eliminated without bundling the TTFs.
- **Band timer.** A repeating controller inside a `PageView` page. Verify it is disposed and
  that off-screen pages are not animating.
- **`DateTime.now()` staleness.** The countdown is recomputed each cycle tick, so a card left
  on screen stays roughly current; it will not tick second-by-second and is not meant to.
- Layout is fixed-position by design. It is authored inside `WalletCardCanvas`, which pins
  text scaling — accessibility text sizing is served by the detail screen's rows, not the face.
