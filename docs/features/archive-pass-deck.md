# Archive pass deck

Opening a folder in the Passes-tab **Archive** used to push a scrolling
`CustomScrollView` of date-sectioned rows (or, for movies, a poster grid).
`HistoryCategoryScreen` now pushes `ArchivePassDeck` instead: one overlapping
deck of full pass faces, a ruler dial under it, and the month/year of whatever
sits under the needle.

Not to be confused with `pass-deck.md`, which is the *live* Passes tab's
experimental horizontal carousel. Different screen, different file, no shared
code.

## Position is measured in passes, not pixels

`AnimationController.unbounded` holds a fractional pass index, and the deck,
the dial and the date readout all render from that one value. Nothing can
disagree about where the archive is, mid-drag or mid-spring.

Everything else is derived per frame: card transform from `index - position`,
ruler offset from `position * passSpacing`, the two date labels cross-faded on
the fractional part.

## One gearing, shared by the drag, the ruler and the tap

`_dialStep` is the pixels of finger travel per pass, and it is the **only**
number in play: the drag divides by it, the painter draws its ticks at it, and
tap-to-jump converts a tap offset with it.

That sounds obvious and it was not the first design. The dial originally drew
its scale at a fixed 54px per pass while the drag geared to
`(width - 48) / (count - 1)`, so on a three-pass folder the ruler crawled at a
third of the fingertip and on a ten-pass folder it ran ahead of it. Both still
"worked" — the needle landed on the right pass — but a scale sliding at a rate
the finger is not driving reads as slipping, which is exactly the thing that
separates a dial from a slider.

So the archive still spreads over one comfortable sweep and the ruler is drawn
to match, rather than the other way round:

```
_dialStep = max(minPassSpacing, (dialWidth - 48) / (count - 1))
```

Tick density then follows the gearing instead of being fixed:
`subdivisionsFor()` puts a tick roughly every 18dp whatever `_dialStep` turns
out to be. A shallow folder gets more marks *between* passes rather than a
wider gap; a deep one falls back to a plain per-pass ruler rather than smearing
into a grey band.

Below the `minPassSpacing` floor of 7dp — past roughly fifty passes — the sweep
gives out before the archive does and it takes a second pull. That is the price
of keeping the grip, and it is the right side of the trade: a 3dp-per-pass dial
is unusable whether or not it fits.

## Detents

`_detent()` fires a selection haptic on every notch crossed: once per pass on
the deck, once per **drawn tick** on the dial, so what the ruler shows going by
is what the fingertip feels going by. A fast scrub crosses ticks quicker than
the actuator can resolve them, so detents are rate-limited to one per 28ms —
without that a long scrub is a buzz, not a ruler.

`_landingDetent()` clicks on arrival only when the drag did not already click
past that notch. A detented control is felt as it passes the notch, not again
when it stops moving; two pulses a fifth of a second apart read as a stutter.

Running off either end fires a heavier `HapticService.impact()` once, so the
rubber band has a floor you can feel.

## The deck moves one pass per gesture

Release velocity decides **whether** a drag that stopped short of halfway still
commits to the next pass. It does not decide how far you travel.

The first version projected velocity forward (`position + v * 0.42`) and let a
flick cross several passes. On a real phone an ordinary flick clears
2000-4000px/s, which is 3-5 passes at a 288px card step — you lose your place
faster than you save time, and you cannot flick "gently" enough to move one.

A long *drag* still travels exactly as far as the finger does; only the
velocity projection is gone. Crossing an archive is the dial's job, and that
division is now honest rather than nominal.

## Tap targets

Every card the viewport shows takes a tap and settles the deck onto it.
Wrapping non-focused cards in `IgnorePointer` — the obvious way to keep the
remove flow on the front card — also silently ate taps on the neighbour that is
sitting half in view looking exactly like a button. Removal is gated on
`interactive` at the callback instead: a long press on a half-covered card is
far more likely a mis-grab than an intent to delete.

## Accessibility

The two ways to move through the archive, dragging the deck and scrubbing the
dial, are both gestures a screen reader cannot perform, and every card but the
focused one is `hidden`. So the dial carries `Semantics(slider: true)` with
increase/decrease actions and a "3 of 17" value — it is the adjustable control
that moves the archive, and without it the whole folder is one unreachable
card. `_focused` is a separate `ValueNotifier` so that node rebuilds once per
pass rather than once per frame of a scrub.

## Known gaps

- The folder tile still flies `Hero(tag: 'history-category-<name>')`, but the
  landing pad went away with `_CategoryIntro`. One-sided Heroes do not throw;
  the flight just silently does not happen. Either give the deck a mark to land
  on or drop the tag.
- The pass count is only in the semantics label — nothing on screen says how
  deep the folder is.
- `_MovieArchiveCard`'s 76dp title band and `_DateReadout`'s 62dp column are
  fixed, so past roughly 1.4x text scale they clip rather than grow.
