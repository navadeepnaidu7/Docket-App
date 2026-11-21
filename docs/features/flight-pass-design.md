# Flight pass — design direction

Companion to `flight-pass.md`. The data plan lives there; this is how the flight should feel.
Interactive prototype: `flight-pass-motion.html` (open in a browser; `#t=452` opens paused at
a minute of the IST day, 280-580).

Status, 21 Nov 2026: direction proposed with a working prototype, not yet agreed.

## The idea

A flight is the one pass that is *moving* while you hold it. The face is the boarding pass
you know; the Updates tab answers "where is it and when do I land" at a glance. Every pixel
that moves is driven by a real fact (ADS-B position, the sun, the clock), never by decoration.

## Updates tab, revision 2 (21 Nov 2026)

Revision 1 (a painted sky with telemetry, cards per update) was rejected as skeletal. Revision 2
is modelled on Flighty's flight sheet (App Store screenshots, studied 21 Nov 2026): a map up
top, then plain data with strong type and status colour, no decoration.

| Block | Design | Reference |
|---|---|---|
| Map | Dot-matrix land (coastlines only, no national borders), each dot shaded by the real sun at that place and time, so dawn visibly sweeps across India during a morning flight. Route bowed like a great circle: flown part solid in the live blue, the rest dotted. Airports as ringed dots with code tags. The aircraft is the plane glyph with a slow pulse. Glass chips top-left: Live, ground speed, altitude | Flighty map sheet |
| Status sheet | A headline sentence with the key number coloured ("Landing in ~1h 02m"), one muted explanatory sentence, then one block per airport: code and airport name, a 36 pt time in status colour with the scheduled time struck through beside it, a sub-line ("21 min late · Took off"), and a right-aligned chip (gate with a departure arrow, terminal). A clock line between them: flown time and distance left | Flighty "Gate Departure in 1h 42m" sheet |
| Your aircraft | Section header plus card: photo of the airline's aircraft of that type, "Airbus A320neo · VT-IPZ" with the registration in accent, operator and how it was found, photo credit | Flighty "Where's My Plane?" |
| Updates | iOS grouped list: tinted circular icon per event type, title, one-line detail, time right-aligned; newest first; inset separators | iOS Settings / Wallet lists |

Status colours (iOS system palette): green landed or early, amber late or changed, blue live
or estimated, red cancelled. Light: #248A3D #B25000 #0066CC #D70015; dark: #30D158 #FFB340
#0A84FF #FF453A.

Built in Flutter the same day, with the user's review applied:

- **One type family.** Everything under the face uses the detail screens' Inter ramp
  (`DetailType`): 22/700 headline, 34/700 times, 16/700 card titles in sentence case,
  16/600 row titles, 14 and 13 secondary. No monospace and no uppercase labels anywhere
  on the tab. The face keeps Geist, as every pass face does.
- **Two dividers, both fading.** `FadedDivider.section` spans the card and fades at both
  ends (headline from the airports); `FadedDivider.item` starts under the text and fades
  towards the trailing edge (rows of the updates list). No square-ended rules.
- **Few middle dots.** Clauses are sentences ("Gate 12, boarding 05:30", "Now departs
  22:15, gate 17"), and the face's flight line spaces "6E 2134" from "PNR X7KQ2M" instead of
  dotting them.
- **Alignment.** 16 dp card padding everywhere; chips right-aligned on the time's bottom
  edge; list dividers inset to the text column (icon 32 + gap 12); times and clocks in
  tabular figures so columns do not jitter.

Map data: land mask rasterised from `johan/world.geo.json` country polygons, all countries
merged so no border is drawn (Indian maps with foreign-sourced borders are a known problem).
17,182 points on a 2 dp grid, stored as run-length rows; the map samples every third
point at full view and every point at 3x, so dots stay about 6 dp apart on screen while a
short route (Mumbai to Goa) is zoomed to fit. Shading is recomputed once a minute.

## Signature moments

| Moment | What happens | Driven by |
|---|---|---|
| Real daylight | Map dots shaded by solar elevation per dot; a warm band at the terminator | solar position maths |
| Your aircraft, by name | Once matched, the aircraft card fills and Details gets its Aircraft card; a soft tick haptic | ADS-B `t`, `r` |
| Arc flight path | The face's route is an arc over the codes; the plane rides it, the contrail fills behind it, dotted ahead | progress along the great circle |
| Take-off | Scheduled time strikes through beside the actual one in amber, light impact haptic | first airborne sample |
| Touchdown | The destination code glows once, the end dot fills, success haptic and a short chime | landing sample |
| Split-flap | A gate that changes flips through the drum on the face; the sheet's gate chip turns amber | a diff from the server |
| Lock screen | Live Activity (iOS) / ongoing notification (Android) mirroring the face sentence and the progress rail | same resolver |

Rules carried from the plan: nothing claims gate, boarding or delay without a source; an
airborne landing time is labelled "Estimated landing"; before a match the map shows the
route and "Tracking from 05:40", no plane.

## Asset tracks

Decided 21 Nov 2026: real airline logos and liveries are in (Docket is personal and
non-commercial). The face keeps no aircraft art; the aircraft appears on Updates and Details.

1. **Airline logos**: served by the backend, never bundled (the app download stays the same
   however many airlines are added). Revised 21 Nov 2026 from four bundled files to 82 logos
   on the server, chosen per airline from Wikimedia Commons or English Wikipedia (Wikidata's
   logo property first), then minified and converted to one-colour silhouettes: every shape
   becomes ink, and white knockouts inside a mark (the Swiss cross, the Turkish crescent)
   become holes through a mask, because the app tints the whole logo with `srcIn`. CSS
   classes are inlined since the renderer ignores `<style>`. About 500 KB in total, 1-3 KB
   gzipped per airline. Not shipped, name in type instead: Scoot (a solid disc in one
   colour), PIA (Urdu script only), Virgin Australia (a 78 KB trace).
2. **Liveries**: the sky aircraft is painted per airline from a few layers: body, belly,
   sweep, fin, engine. IndiGo: white body, #001B94 belly, fin and engines, a #3D63E6 sweep.
   Each new airline is a five-colour entry, checked against a photo, never guessed.
3. **Aircraft silhouettes** by ICAO type, side profile: A20N/A320, A21N/A321, B38M/B737,
   B789/B788, ATR 72. The livery layers sit on these.
4. **Aircraft photos**: Details shows a photo of the airline's aircraft of that type, credited
   under it. Wikimedia Commons has CC BY-SA photos searchable by registration and by
   "airline + type" (IndiGo VT-IJB A320neo, Akasa VT-YAO, Air India Express VT-BXY…). When
   the exact registration is not pictured, the caption says which sister aircraft is.
   planespotters.net has a free photo-by-registration API, but it requires a User-Agent with
   a contact URL, so it belongs on the server. adsbdb's `url_photo` was null for VT-IPZ.
5. **Airport glyphs** (later): monoline landmark per top-20 Indian airport.
6. **Sound**: one touchdown chime, under 400 ms, through `core/sound`, off when silent.

## Building it in Flutter

| Piece | Approach |
|---|---|
| Map | `CustomPainter` over a const dot list; per-dot shading recomputed once a minute, not per frame; the pulse alone animates; repaint boundary |
| Arc + plane | `CustomPainter` with `PathMetric.getTangentForOffset` |
| Split-flap | small `AnimatedWidget` per cell, two clipped halves and a `Transform` leaf; reduced motion swaps instantly |
| Updates list | `AnimatedList` inside one card, new rows rise in from the top |
| Haptics | existing `core/haptics` |
| Lock screen | `live_activities` (iOS) and a foreground-service notification (Android); a separate phase |

All motion honours `MediaQuery.disableAnimations`.

## Open choices for the user

- Chime on landing: on by default?
- Which airport glyphs first.
