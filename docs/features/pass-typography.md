# Pass typography

One type ramp for every pass detail screen — train, movie and bus.
`lib/features/tickets/presentation/pass_typography.dart`.

## The problem it fixes

The three screens had drifted. Movie and bus settled on a tight 16/15/13 ramp; the train screen
accumulated **eleven distinct sizes between 11 and 21** for the same handful of roles. The same
kind of thing rendered at a different size depending on which pass you opened — a label was 13
on a movie ticket and 14 on a train one, a section title 15 or 18.

Every size was written inline as `GoogleFonts.inter(fontSize: …)` at the call site, 28 times in
the train screen alone, so there was nothing to drift *from*.

## The ramp

Five steps. Every role maps onto one of them.

| Role | Size | Weight | Used for |
|------|------|--------|----------|
| `screenTitle` | 16 | 700 | "E-Ticket" — one per screen |
| `sectionTitle` | 15 | 700 | Heading above a group of rows |
| `itemTitle` | 15 | 600 | A station, a cinema, a passenger |
| `label` | 13 | 500 | Muted left side of a pair |
| `value` | 13 | 600 | The value answering a label |
| `caption` | 12 | 500 | Secondary line — platform, date, route |
| `pill` | 12 | 600 | Text inside a chip, where the shape carries emphasis |
| `micro` | 11 | 500 | Footnotes — "All times are in IST" |

`label` and `value` are deliberately the same size and differ only in weight: a pair should read
as one line, not as a heading and a subordinate.

### One exception

`code` (17, tracked +2.2) for a PNR or booking reference. These are read character by character
against a physical ticket rather than as a word, so they keep open tracking and one step of
extra size. It is the only role off the body ramp, and it is called out in the source.

## What this does not cover

**Card faces.** `TrainPassType` (Geist + Instrument Serif), and the movie and bus faces, are
facsimiles of printed tickets with their own ramps. They are meant to look like documents, not
like the app, and unifying them would destroy the effect. `TrainPassMetrics` pins that face to a
fixed 366×630 canvas where the sizes are part of the artwork.

Archive and wallet chrome is also untouched for now; `history_pass_card` still sets 17/13
inline. Folding it in is a follow-up.

## Keeping it

`test/pass_typography_test.dart` asserts the ramp holds — every role on one of the five steps,
nothing larger than the screen title, label and value matched — and reads the three detail
screens to fail if any of them sets a raw `fontSize:` or calls `GoogleFonts.` directly. That
last check is what stops the drift coming back, since it catches a new inline style at the point
it is written rather than the next time someone compares two passes side by side.

`PassType.warmUp()` runs in `main()` beside `TrainPassType.warmUp()`, so these weights are in
the same `GoogleFonts.pendingFonts()` wait and the screens do not render in a fallback face and
reflow.
