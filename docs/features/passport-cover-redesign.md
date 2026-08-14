# Passport cover redesign

Rebuilds `WalletPassportCard` as a booklet: navy 2021/2024 cover on the front,
cream biodata page on the back. Tap still flips.

Status: **implemented**. Glance card only — there is no separate passport detail
face.

References (layout, not bundled assets):

- [Indian Passport.svg](https://commons.wikimedia.org/wiki/File:Indian_Passport.svg) (ordinary, 2021)
- [Indian Passport (e-Passport, 2024).svg](https://commons.wikimedia.org/wiki/File:Indian_Passport_(e-Passport,_2024).svg)

Both are CC BY-SA 4.0 mock-ups. The app recreates the composition in Flutter with
the existing bundled emblem PNGs; the Wikimedia SVGs stay out of `assets/`.

## What changes

| Before | After |
|---|---|
| Wallet-card header (small emblem + English titles, chip in the corner) | Centred official lockup: Hindi then English at the top, emblem, motto, Hindi then English at the bottom |
| Holder name + number + "Tap to view details" | Cover only. Identity lives on the back; tap still flips |
| Tricolour strip + Ashoka Chakra watermark | Clean navy field, brushed-leather grain only |
| Mid navy `#1E3163` → `#0F1A38`, gold `#D4A843` | Cover navy `#070930`, foil gold `#F4CA81` |
| Outlined chip glyph | Filled ICAO e-passport mark, shown only when `profile.isEPassport` |

Ordinary and e-passport share one layout. The chip is the only extra; it sits
under `PASSPORT` and does not shift the rest of the lockup.

## Tokens

Card-local units on the existing `382 × 570` canvas (`WalletCardMetrics.passportCanvas`).
Y values are scaled from the 400 × 568 Commons artboards.

| Token | Value | Use |
|---|---|---|
| `navy` | `#070930` | cover field |
| `navyLift` | `#12184A` | top-left leather light |
| `navyShade` | `#04061C` | bottom-right shade |
| `gold` | `#F4CA81` | foil type, emblem, chip |

Outer radius stays **40** so the flip matches the data page.

### Type

| Element | Face | Size | Weight | Approx. y |
|---|---|---|---|---|
| `भारत गणराज्य` | Noto Sans Devanagari | 28 | 700 | 72 |
| `REPUBLIC OF INDIA` | Inter | 20 | 700 | 108 |
| Emblem | `passportEmblemLarge` | 176 | — | 178 |
| `सत्यमेव जयते` | Noto Sans Devanagari | 16 | 700 | 362 |
| `पासपोर्ट` | Noto Sans Devanagari | 28 | 700 | 436 |
| `PASSPORT` | Inter | 20 | 700 | 470 |
| Chip | custom paint | 42 × 26 | — | 516 |

Noto Sans Devanagari is warmed in `main()` next to Geist / Instrument Serif so
offline start does not flash tofu then reflow.

## Data page (back)

Reference: [Indian Passport Bio Page 2021.jpg](https://commons.wikimedia.org/wiki/File:Indian_Passport_Bio_Page_2021.jpg)
(layout only — the photo is redacted and is not bundled).

Flip goes from navy leather to a cream polycarbonate page, which is how a real
booklet opens. Same 382 × 570 canvas, same r40.

| Before | After |
|---|---|
| Navy wallet chrome, flag emoji, pill badges | Cream page, English field labels, hairline rules |
| One name block + number | Surname / given names split the same way the MRZ already does |
| `1992 August 15` | `15/08/1992` |
| "MACHINE READABLE ZONE" caption | Bare two-line MRZ band, hidden when there is no real MRZ |
| Header only if nationality was exactly `IND` | Header always reads REPUBLIC OF INDIA |

### Page tokens

| Token | Value | Use |
|---|---|---|
| `paper` | `#F6F2E8` | page field |
| `paperShade` | `#EBE4D4` | MRZ band, photo well |
| `ink` | `#1A2744` | values, emblem |
| `label` | `#3D6A78` | bilingual captions (official teal) |
| `rule` | `#C5D0D4` | field underlines |
| `wash` | `#D7E8EE` | security tint / ghost |

Photo is still `photoBase64` only (`imagePath` is the data-page capture, not a
portrait). Missing fields stay `—`. The MRZ generator is unchanged: no
synthesised line for a passport that does not exist.

## Out of scope

- Entry / review screens
- Bundling the Commons SVGs or the bio-page JPEG
- Changing `passportCanvas` / aspect
- Splitting the single `name` field in storage (display-only split)
