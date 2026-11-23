# Bus pass redesign

Replaces the brand-header-over-paper bus face (gradient header, coach photograph, three-row
field grid) with the train pass's system on an operator-coloured surface, plus one bus mark:
a flat coach watermark. Direction agreed against HTML mocks in session, 19 Nov 2026.

Status: **built, not yet checked on a device**. Applies to the wallet glance card, the detail
screen, the archive deck and the shared PNG; they all render `BusTicketFace`. Owners:
`lib/features/tickets/presentation/bus/`.

The earlier photographic coach artwork (redBus PNG and an unbranded ivory-and-teal coach
generated for the universal style, Oct 2026) is retired with its assets; the flat
`bus_coach_painter.dart` watermark replaces it. Kept from that pass: no generic boarding
advisory on the face, and long operator names must never run behind the coach.

## Direction

What the user turned down on the way here:

- a graphite twin of the train face: the two pass types read as one
- vertical stop-to-stop itineraries, a dot-matrix destination board, a side stub: too far from
  the train family
- a coach glyph on the route rule, a front-view glyph beside the operator, wheel-arch cut-outs
- the platform / bay field: bus tickets rarely carry one and it does not matter at the kerb

What it is: the train layout (382 x 560, same type ramp, baselines, tear, status sentence) on one
solid operator surface, with a tone-on-tone side-profile coach pulling out of the stub's
bottom-right corner. The surface colour separates bus from train in the carousel; the coach
says "bus" even at thumbnail size.

## Layout (382 x 560 canvas, same as the train)

```
 redBus                            Sat, 21 Nov    name 20/600, date 15/500
 Booking RB8842119                                14/500 muted, omitted when empty

 Bengaluru                              Mysuru    city 14/500 muted, one line
 8:30 AM  ───── 3h 15m ─────      11:45 AM +1     time 44/400 + meridiem 14/500 muted
 Kempegowda Bus           Mysuru City Bus Stand   stop 14/500 muted, two lines
 Station

 Departs in 2 days                                lead 24/500 muted + emphasis 600 ink
 Overnight, arrives Sat 5:30 AM                   detail 14.5/500, only when it says something
◖·································◗  tear
 Seat                                     Fare
 12A                                      ₹650    seat 34/600 (24 past 7 chars), fare 17/500
 Passengers                       [coach]         one line, stops short of the coach
 Navadeep and 1 other
```

- Every column hangs off x = 26 or ends at x = 356. City, time and stop share the left edge
  under the departure and the right edge under the arrival.
- Everything is placed by baseline, as on the train face.
- The meridiem sits on the time's baseline. Times are 12-hour without a leading zero, because
  bus operators print them that way; the big digits get the train's side-bearing correction.
- `+1` hangs in the right margin so the arrival keeps the shared edge.
- The route rule fills with ink as the journey progresses, exactly like the train.
- Seat and fare share a baseline. Long seat values ("L12 Lower sleeper") drop to 24 dp instead
  of wrapping. Passengers use the train wording: "Navadeep and 1 other".

## Palette

| Token | redBus | Universal | Spent |
|---|---|---|---|
| surface | `#A3262E` | `#1F3533` | `#E9E8E5` |
| ink | white | white | `#58585C` |
| muted | white 62% | `#F0F6F5` 55% | `#3C3C41` 52% |
| faint | white 24% | `#F0F6F5` 18% | `#3C3C41` 16% |
| coach body | white 12% | white 12% | `#3C3C41` 7% |
| coach windows, wheels | `#3C0006` 30% | black 30% | `#3C3C41` 6% |

The universal surface is a petrol teal, never another operator's colour. Spent keeps the
operator's wordmark and the coach, drains the colour.

## Status sentence

`resolveBusJourneyStatus(pass, now)` — pure, unit-tested. Bus tickets carry no live running
feed, so every line comes from the timetable; nothing prints a delay.

| State | Lead line | Detail |
|---|---|---|
| expired, or past arrival | Arrived **6:10 AM** | Journey complete |
| underway (10 min after departure) | Arrives in **3h 46m** | — |
| boarding (within 10 min after) | **Boarding now** | overnight line |
| before departure | Departs in **25 min** / **tomorrow** / **4 days** | overnight line |
| unknown departure | Departs at **8:30 AM** | overnight line |

Overnight line: "Overnight, arrives Sat 5:30 AM" when arrival falls on a later calendar day.
The countdown rules match the train's (`Departs tomorrow` only beyond 12 hours).

There is no cancelled state: `BusPass` has no field that could carry one.

## Ticket code

The face never draws a code — glance and detail render the same face. On the detail screen a
movie-style code row sits under the card: a white tile with the real `PassCodeView` and "Tap to
open full screen for scanning", opening `BusTicketCodeScreen`. Omitted entirely when the pass
has no `passCode`. The shared PNG keeps printing the code below the face.

## Files

| File | Change |
|---|---|
| `bus/bus_pass_theme.dart` | metrics, type ramp, glyph bearings for the new face |
| `bus/bus_brand_style.dart` | per-operator solid palette + wordmark; coach photo fields gone |
| `bus/bus_journey_status.dart` | new — pure status resolver, day offset, duration |
| `bus/bus_coach_painter.dart` | new — the flat coach watermark |
| `bus/bus_ticket_face.dart` | rewritten |
| `bus/bus_pass_detail_screen.dart` | train canvas, code row replaces the "Boarding code" card |
| `wallet_bus_card.dart` | train canvas at the 94% glance width |
| `history/archive_pass_deck.dart`, `share/pass_share_card.dart` | bus canvas |
| `assets/passes/redbus_coach.png`, `bus_coach.png` | deleted with their `AppAssets` entries |
| `test/bus_pass_face_test.dart` | rewritten |
| `test/bus_journey_status_test.dart` | new |

Mocks: the session's `bus_pass_vision_4.html` (not versioned).

## Verification (19 Nov 2026)

- `flutter analyze` on `lib/features/tickets` and the bus tests: no issues.
- `test/bus_pass_face_test.dart` + `test/bus_journey_status_test.dart`: pass, including edge
  checks (city, stop and time on the shared left/right edges, meridiem on the time baseline).
- Full suite: 841 pass, 2 fail — `add_menu_golden_test` and `passport_cover_art_test`, both
  rendering `passport_cover_art`, which this change does not touch.
- Rendered redBus, universal overnight, long-name and spent faces to PNG with bundled Geist and
  checked them against the mock.
- Not checked: a physical device, and the detail screen's code row against a real scanner.
