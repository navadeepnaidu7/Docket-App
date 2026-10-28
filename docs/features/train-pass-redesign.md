# Train pass redesign

Replaces the blush "paper facsimile" train face (Instrument Serif codes, booking chip, two-column
data grid, cross-fading status band) with a solid graphite card built on type and spacing alone.
Direction agreed against HTML mocks in session, 28 Oct 2026.

Status: **in progress**. Applies to the wallet glance card, the detail screen hero, the archive
deck and the shared PNG — they all render `TrainTicketFace`.

## Direction

What the user rejected on the way here, so nobody reintroduces it:

- gradients and colour blooms on the surface
- status as a pill with a coloured dot
- icons inside tinted squircles
- ALL-CAPS tracked labels
- `·` middle-dot separators joining values
- a dot riding the route line
- a short, widget-sized card

What stays: one solid surface, the dotted tear line with side notches, sentence-case labels,
the two-tone status sentence (the same voice as `AccountSummary`), generous fixed spacing.

## Layout (382 x 498 canvas)

```
 Rajdhani Express                 Thu, 30 Oct     name 20/600, date 15/500
 12951                                            number 14/500 muted

 New Delhi                     Mumbai Central     city 14/500 muted
 16:55  ───── 15h 40m ─────   08:35 +1            time 44/400, duration 12 above the rule
 NDLS                                    MMCT     code 14/500 muted

 Departs in 2h 10m                                lead 24/500 muted + emphasis 600 ink
 On time, chart prepared                          detail 14.5/500 muted
◖·································◗  tear, notch centres on it
 Coach        Berth            Class              label 13/500 muted, value 17/500
 B2           34 Lower            3A
 Passengers                     Platform
 Navadeep and 1 other                4
```

- Horizontal inset 26 on both sides; every right-hand column ends on the same edge.
- Everything is placed by **baseline**, not by top, so the fallback face google_fonts shows
  before Geist arrives cannot shift the layout.
- The stub holds equal space above the first label's cap line and below the last value's
  baseline, so the grid sits optically centred between the tear and the bottom edge.

### Optical alignment of the big times

The city above, the time and the code below must share one left edge and one right edge.
Two things broke that in the mocks:

1. **Tabular figures.** Geist's `tnum` "1" is centred in a full-width cell, so a time starting
   with 1 sat ~7 dp right of the city name. The big times use proportional figures — they never
   animate, so they gain nothing from `tnum`.
2. **Side bearings.** At 44 dp a digit's side bearing is 1-5 dp, against ~1 dp for the 14 dp
   letters around it. The face shifts each time by the measured bearing of its first (or last)
   glyph, from a table read off `Geist-Regular.ttf` with fontTools.

The `+1` day marker hangs in the right margin instead of pushing the arrival time inward.

Found on device (motorola edge 30), 28 Oct 2026:

- At 50 dp, two wide times (`20:00`, `06:00`) left the route rule ~30 dp and clipped the
  duration. 44 dp leaves room for both on every fixture.
- The rule and duration sit in a `MultiChildLayoutDelegate`, not a `Row`: a Row asserts when
  the times outgrow the card (free text, the test font's full-em glyphs); the delegate just
  collapses the rule. Unparseable times print as a dash for the same reason.
- A lone lead line (no detail parts) drops to the middle of the two-line block.
- Berth spans into the third column's spare room; groups past three seats read
  "12 and 5 more" instead of an ellipsized list.

## Palette

| Token | Active | Spent |
|---|---|---|
| surface | `#1C1C1E` | `#E9E8E5` |
| ink | `#F5F5F7` | `#58585C` |
| muted | ink at 52% | `#3C3C41` at 52% |
| faint (rules, dots) | ink at 17% | `#3C3C41` at 16% |
| warning | `#FFB340` | flattened to muted |
| critical | `#FF6961` | flattened to muted |

Fixed in both themes, like the movie and passport cards. A 1 dp top-edge highlight is the
only depth on the face; the shadow lives outside it.

## Status sentence

`resolveTrainJourneyStatus(pass, now)` — pure, unit-tested, replaces `TrainStatusBand`.

| State | Lead line | Detail |
|---|---|---|
| cancelled | **Cancelled** (critical) | — |
| arrived / expired | Arrived **08:35** | Journey complete |
| underway | Arrives in **3h 46m** | Next stop X at 11:00 |
| boarding (within 10 min after) | **Boarding now** | status parts |
| < 1 hour | Departs in **25 min** | status parts |
| same day | Departs in **2h 10m** | status parts |
| next calendar day | Departs **tomorrow** | status parts |
| later | Departs in **4 days** | status parts |

Waits of a day or more format as `1d 15h`. A "departed" origin halt only counts as underway
when the clock is within an hour of departure, so a mis-dated feed cannot print "Arrives in 72h".
| unknown departure | Departs at **16:55** | status parts |

Status parts, comma-joined in this order: running late (warning) or on time (only when the
backend says `onTime`), booking status when it is not confirmed (warning), chart prepared.

Delays move times only where the delay is known to apply: before departure the departure time
shifts and turns amber with the scheduled time struck beside the code; once underway the
arrival does.

## Ticket code

The face no longer draws a code. The detail screen shows a **Show ticket code** button under
the card when the pass has a real `codePayload`, opening the existing code sheet. The shared PNG
already prints the code below the face.

## Files

| File | Change |
|---|---|
| `train/train_pass_theme.dart` | new palette, metrics, type ramp, glyph bearing table |
| `train/train_journey_status.dart` | new — pure status resolver |
| `train/train_status_band.dart` | deleted |
| `train/train_ticket_face.dart` | rewritten; `TrainTicketFace` / `TrainTicketDensity` API kept |
| `core/wallet/wallet_card_metrics.dart` | `trainCanvas` 382 x 498 |
| `ticket_detail_screen.dart` | code button replaces the tap target on the face |
| `share/pass_share_card.dart` | drops `showCode` |
| `test/train_journey_status_test.dart` | new |
| `test/train_pass_face_test.dart` | rewritten for the new layout |
| `test/train_status_band_test.dart` | deleted |

## Not yet

- Detail screen body (summary sentence + grouped lists) — the mock was liked, built separately.
