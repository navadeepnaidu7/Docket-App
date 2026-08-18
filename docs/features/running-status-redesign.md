# Running status redesign

Visual rework of the **Live Status tab** on a train pass (`_LiveStatusTab` in
`ticket_detail_screen.dart`). The Details tab is deliberately untouched.

## Goal

The old timeline was a thin mint spine with small dots and a 14px station name — it read as a
dense list rather than a journey. The new one gives each stop room to breathe and makes
progress legible at a glance:

| Piece | Treatment |
|-------|-----------|
| Spine | 5px rounded bar. Solid ink for the travelled portion, faint track for what's ahead |
| Node | Hollow ring (9px radius, 3px stroke) filled with the surface color |
| Time | Small grey pill above the station name |
| Station | `PassType.itemTitle` — the loudest thing in the row, but on the shared ramp |
| Sub-line | Platform / date, with a chevron when there is more to say |
| Status | Right-aligned pill — green when on time, amber when late, grey once departed |

Every size comes from `PassType` (see `pass-typography.md`). The first cut of this screen set
the station name at 21px with a 6px spine and 11px rings, which made a four-stop journey feel
like a poster: correct in shape, far too loud next to the movie and bus passes. The ramp now
tops out at 16 across all three.

## Honest status, not decorative status

The status pill follows the same rule the wallet card's status band already enforces: **only
claim "On time" when the backend actually said so.** `TrainRunState.onTime` is required — the
mere absence of a delay is not evidence, and inferring it would put a confident green pill on
every pass the server has never reported on.

Resolution order per halt, in `resolveHaltStatus`:

| Precedence | Condition | Pill |
|-----------|-----------|------|
| 1 (highest) | `runState == cancelled` | "Cancelled", warning — for every halt state |
| 2 | Completed journey + `arriving` | "Departed", neutral |
| 3 | Completed journey + `upcoming` | **no pill** |
| 4 | `departed` | "Departed", neutral |
| 5 | `arriving` (active journey) | "Arriving", live |
| 6 | `upcoming` + `isDelayed` | "<n> min late", warning |
| 7 | `upcoming` + `runState == onTime` | "On time", positive |
| 8 (fallback) | `upcoming`, nothing known | **no pill** |

A halt whose `actual` differs from `time` shows both: the scheduled time struck through in the
pill, the actual beside it in the status tone. Null `actual` is normal and means "no revision",
which is different from "on time".

## Scope

In: `_JourneyTimeline`, `_HaltRow`, the spine painter, and the dock beneath the timeline.

Out: the Details tab, the dark journey summary card at the top of the tab (it carries the
duration and progress the timeline does not), and the pass models — this is presentation only,
no new fields.

## Not adapted from the reference

The reference screenshot carries controls this app has no data or feature for. They are
deliberately **not** built, rather than faked with dead UI:

- **Line badges** ("L95", "Airport T1") — no transit-line data on `TicketHalt`
- **"View map"** — there is no map feature
- **"Alerts"** — there is no alerts feature
- **City vs station split** ("Hyderabad" / "Secunderabad Junction") — `TicketHalt.station` is a
  single string; the sub-line uses platform and date instead

## Theming

The reference is a light design. Both themes are supported: the spine's travelled color is
`onSurface`, the ring fill is the card surface, and the status pill tones resolve per
brightness. Nothing is hardcoded to a light palette.
