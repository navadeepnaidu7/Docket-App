# Stacked pass deck

An alternative to the Passes tab's vertical roll carousel: a horizontal deck of
overlapping cards you shuffle sideways. Off by default, behind
Settings → Experimental → **Stacked pass deck**.

The existing vertical `PageView` + `RollingCardPage` is untouched. The toggle picks
between the two at the top of `TicketsTab`; nothing else in the tab changes.

## The idea

Cards sit on top of one another rather than beside one another. The active card is
centred and fully visible; upcoming cards fan out to the right, each one lower in the
stack showing only a narrow strip of itself. Depth comes from **X offset + overlap +
paint order + scale**, not from rotation — the cards stay flat and parallel, on a
shared vertical baseline.

```
        ┌───────────────┐
   ←────│               │┐              ← dealt off, sliding left and fading
        │   active      ││┐
        │               ││││
        └───────────────┘│││
                          ││└ +3  (a sliver)
                          │└─ +2
                          └── +1
```

## Paint order is fixed, and that is the whole trick

The obvious model — sort by *distance* from the active card so the active one is on
top — pops. Halfway through a swipe the outgoing and incoming cards are equidistant,
equally scaled and heavily overlapped, and the z-swap flips a few hundred pixels of
artwork in one frame.

So the deck never reorders. Cards paint in **descending index**: highest index
deepest, index 0 on top. Because `distance = index - position`, ordering by distance
*is* ordering by index, permanently — there is no crossover to pop. The active card
looks topmost because everything above it has already been dealt off to the left and
faded to nothing.

That also fixes the direction question. Cards you have passed do not stay stacked on
the left; they slide out and go. At the last pass you see one card, at the first you
see the whole deck — which is itself an honest "where am I" signal.

## Geometry (`DeckGeometry.slotFor(distance)`)

One pure function, continuous in `distance`, so a slot is defined mid-drag and not
only at integers.

| | Behind the active card (`d >= 0`) | Dealt off (`d < 0`, `a = -d`) |
|---|---|---|
| `dx` | `spread · (1 − falloff^d) / (1 − falloff)` — a geometric series, so the stack compresses with depth and is **bounded**: it can never run off to infinity | `−exitTravel · easeOutCubic(a)` |
| `scale` | `scaleStep^d` | `1 + exitLift · t` — a slight lift as it comes off the top |
| `opacity` | 1, fading over `depthFadeStart → depthFadeEnd` so a new card never pops in | `1 − a`, gone by `a = 1` |

Defaults: `spread 44`, `falloff 0.80` (offsets 44, 79, 107, 130 — increments 44, 35,
28, 23), `scaleStep 0.955`, fade 2.3 → 3.4, `exitTravel 120`, `exitLift 0.035`.

Slots at or below 1% opacity are not built at all. An `Opacity(0)` widget still
hit-tests, so a card that is invisible would otherwise sit over the active one and
swallow taps.

## Motion

`AnimationController.unbounded` holds the fractional position — it is the single
source of truth for both the drag and the settle, so the two can never disagree.

- **Drag**: `position -= dx / dragUnit`, `dragUnit = cardWidth · 0.62` so the gesture
  feels identical on any screen. Past either end the delta is damped to 32% — a
  rubber band, not a wall.
- **Release**: target is the nearest index, or one further along when fling velocity
  clears 1.6 cards/sec. Settles on a `SpringSimulation` seeded with the **gesture's
  own velocity**, damping ratio 0.86 — enough to overshoot a hair and come back
  rather than stopping dead. No `Curves.easeOut` here: a fixed curve ignores how hard
  the swipe was.
- A selection haptic fires as each index passes under, so the deck has detents.

## Interaction

- Drag horizontally anywhere on the deck.
- Tap a peeking card to bring it to the front.
- The active card keeps its own gestures — tap opens the detail screen, long-press
  runs the remove flow. Non-active cards are wrapped in `IgnorePointer`, so only the
  front card is live, and anything under 50% opacity is inert.
- Pass cards use a plain `GestureDetector`, not `CardTouchLayer` (that is the
  passport/ID tilt layer), so the tap-vs-drag contest resolves in the gesture arena
  with no changes to either side.

## Layout

`sideInset` (default 56) is reserved on each side, so the active card is narrower
than in roll mode — that reserve is what the peeking cards show through. Cards
deeper in the stack are allowed to run off the screen edge; the deck reads as
continuing past the viewport.

The dot indicator moves from the right edge (vertical) to under the deck
(horizontal). `DotIndicator` took an `axis` rather than being copied.

## What it does not do

- No rotation, no perspective, no fanning. Flat and parallel is the point.
- Does not touch the IDs tab, which keeps its own `PageView`.
- Does not change `WalletCardMetrics`, the card faces, or the remove flow.
- The preference is a plain `SharedPreferences` bool
  (`experimental_pass_deck`), same shape as `cardShineBorderProvider`. It is a user
  preference, not a `DevFlag`, so it survives in release builds.
