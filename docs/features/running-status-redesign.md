# Running status redesign

Visual rework of the **Live Status tab** on a train pass (`_LiveStatusTab` in
`ticket_detail_screen.dart`). The Details tab is deliberately untouched.

## Goal

The old timeline was a thin mint spine with small dots and a 14px station name — it read as a
dense list rather than a journey. The new one gives each stop room to breathe and makes
progress legible at a glance:

| Piece | Treatment |
|-------|-----------|
| Spine | 6px rounded bar. Solid ink for the travelled portion, faint track for what's ahead |
| Node | Large hollow ring (11px radius, 3.5px stroke) filled with the surface color |
| Time | Small grey pill above the station name |
| Station | 21px bold, the loudest thing in the row |
| Sub-line | Platform / date, with a chevron when there is more to say |
| Status | Right-aligned pill — green when on time, amber when late, grey once departed |

Generous vertical rhythm (28px between stops) so the spine reads as distance covered.

## Honest status, not decorative status

The status pill follows the same rule the wallet card's status band already enforces: **only
claim "On time" when the backend actually said so.** `TrainRunState.onTime` is required — the
mere absence of a delay is not evidence, and inferring it would put a confident green pill on
every pass the server has never reported on.

Resolution order per halt, in `_resolveHaltStatus`:

| Halt state | Pill |
|-----------|------|
| `departed` | "Departed", neutral |
| `arriving` | "Arriving", live |
| `upcoming` + `isDelayed` | "<n> min late", warning |
| `upcoming` + `runState == onTime` | "On time", positive |
| `upcoming`, nothing known | **no pill** |

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
