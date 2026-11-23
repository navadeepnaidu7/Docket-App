# Detail typography and layout

One type ramp and one information-card shell for every detail screen: train, bus, movie and
flight passes, PAN/Aadhaar documents, and payment cards.

Status: implemented. Owners: `lib/shared/widgets/detail_typography.dart` (`DetailType`),
`lib/shared/widgets/detail_info_card.dart` (`DetailInfoCard`).
`lib/features/tickets/presentation/pass_typography.dart` keeps `PassType` as a typedef of
`DetailType` for existing pass call sites. Guard: `test/pass_typography_test.dart`.

## Why

The pass screens had drifted to eleven sizes between 11 and 21 for the same few roles (a
label was 13 on a movie and 14 on a train), all written inline as
`GoogleFonts.inter(fontSize: ...)`. Documents and payment cards later had their own lower
sections. One ramp in one file gives nothing to drift from.

## The ramp (Inter)

| Role | Size / weight | Used for |
|---|---|---|
| `screenTitle` | 17 / 700 | "E-Ticket", one per screen |
| `sectionTitle` | 16 / 700 | heading above a group of rows |
| `itemTitle` | 16 / 600 | a station, a cinema, a passenger |
| `label` | 14 / 500 | muted left side of a pair |
| `value` | 14 / 600 | the value answering a label |
| `caption` | 13 / 500 | secondary line: platform, date, route |
| `pill` | 12 / 600 | text inside a chip |
| `micro` | 11 / 500 | footnotes: "All times are in IST" |
| `code` | 17, open tracking | PNR / booking reference only |

`label` and `value` share a size and differ only in weight, so a pair reads as one line.
`code` is the single role off the body ramp: references are read character by character
against a physical ticket. The main roles moved up 1 dp on 19 Nov 2026; the source file is
authoritative if this table and it ever disagree.

## Layout rules

- Document and payment-card lower sections reuse the pass information card: 16 px inset,
  same border, same gutters and gaps as the pass screens.
- Eye/copy actions use filled rounded glyphs at 22 dp inside 48 dp touch targets.
- Narrow widths and large text stack label over value instead of clipping.
- Copy/reveal keeps its existing masking, timers and secure handling; copy feedback never
  repeats the copied value.
- `NetworkMark` applies a Discover-only optical size correction.
- Passports have no lower detail section; their booklet flips in place.

## Out of scope

Card faces. `TrainPassType` (Geist + Instrument Serif), the bus, movie and flight faces, and
the document faces are facsimiles with their own ramps; unifying them would break the effect.
Archive/wallet chrome is not on this ramp yet.

## Keeping it

`test/pass_typography_test.dart` asserts every role sits on the ramp, nothing exceeds the
screen title, label and value match, and that the pass detail screens set no raw
`fontSize:` and call no `GoogleFonts.` directly. That last check catches drift when it is
written. Detail goldens for documents and payment cards cover light and dark.
