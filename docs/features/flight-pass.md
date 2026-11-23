# Flight pass

Adds `flight` as a fourth wallet pass kind: a boarding-pass face in the train/bus family, a
Details tab like the bus and train screens, and an **Updates** tab, a Flighty-style feed of
real status changes (gate, delay, boarding, departed, landed, baggage belt).

Status, 23 Nov 2026: **phases 1, 2, 4 and 5 built; live status (phase 3) not started.** The
server mapper, itinerary extraction, airport time zones, barcode-first ingest and trips are on
`docket_server` branch `feat/flight-passes` (not yet deployed); the Flights add tile is on.
Uploading a real ticket needs that branch deployed. See phase 5 below.

### What is built

| File | What |
|---|---|
| `domain/flight_pass_models.dart` | `FlightPass`, `AirportTime` (instant + airport offset), `FlightLive`, `FlightUpdate` |
| `domain/flight_format.dart` | 24-hour airport-local times, block time on instants, day offset on walls |
| `domain/bcbp.dart` | IATA Res. 792 mandatory-items parser, multi-leg, strict |
| `presentation/flight/flight_journey_status.dart` | `resolveFlightJourneyStatus`, `flightUpdateFeed` — pure |
| `presentation/flight/flight_ticket_face.dart` + theme, brand style, aircraft painter | the face |
| `presentation/flight/flight_pass_detail_screen.dart` | Details / Updates |
| `presentation/flight/flight_ticket_code_screen.dart`, `wallet_flight_card.dart` | bus-pattern twins |
| `data/mock_flight_fixtures.dart` | delayed + gate change, timetable only, in the air, a foreign overnight (LH), two past (EK, VY); dated off the current instant |
| every `WalletPassItem` / `PassKind` switch | flight arms |
| `test/flight_pass_test.dart`, `test/flight_pass_face_test.dart` | 28 tests |
| `tool/flight_pass_preview_test.dart` | renders faces and screens to `build/flight-preview/` |

Updates tab, revision 2 (21 Nov 2026), built in Flutter against the fixtures:
`flight_updates_tab.dart` (status sheet, aircraft card, updates list), `flight_route_map.dart`
(sun-shaded dot map, zooms to fit short routes), `flight_map_land.dart` (generated land grid),
`flight_tones.dart`, `domain/flight_geo.dart` (airport table, great-circle distance, solar
elevation), `shared/widgets/faded_divider.dart`. The face now carries the airline logo, the
arc over the codes, and no corner aircraft.

Airline table (21 Nov 2026): `domain/airline_brands.dart` lists 85 airlines worldwide (IATA
code, name, surface colour, dark-ink flag, logo scale); `FlightBrand` is gone. Logos are not
bundled: the server serves them at `GET /img/airline/{IATA}.svg` (embedded in the binary,
`docket_server/internal/brands`, gzip, 30-day max-age, ETag), and
`presentation/flight/airline_logo.dart` keeps a disk copy (`flutter_cache_manager`, 90 days)
plus an in-memory copy. `PassListNotifier` warms disk copies before the first paint; a logo
not yet on the device shows the airline name in type and cross-fades in. Logos are sized by
area, not height, so a square emblem and a long wordmark look equally heavy.
**Deployed to staging on 23 Nov 2026** from `feat/airline-logos` (docket-server PR #7, not yet
merged); a server without the endpoint answers 404 and every face shows the name in type. Review sheet: `tool/airline_logo_sheet_test.dart`; sources and how to add an airline:
`docket_server/internal/brands/airlines/SOURCES.md`.

BCBP is wired into the upload (phase 5): `ticket_code_scanner` keeps every boarding pass
barcode across a PDF's pages and the server parses them.

## What already exists

| Where | What | State |
|---|---|---|
| `docket_server` `domain.FlightExtraction` | carrier, flightNumber, origin/destination IATA, departure/arrival RFC3339, terminal, gate, seat, passengers | extracted and stored today |
| `docket_server` validation | flight number regex + IATA codes | live |
| `docket_server` `pass_mapper.go` | `flight` falls into `default:` and is **dropped** from `/v1/passes` | the gap |
| `docket_server` train worker | durable job queue, shared `TrainRun` fanned out to tickets, outbox to FCM | the pattern to copy |
| app `ticket_code_scanner.dart` | decodes PDF417 / Aztec on device, the symbologies airlines use | live |
| app `PassHistoryCategory.flight`, `PassAddIcon.flight`, `HistoryGlyphKind.flight` | archive and add-menu slots | placeholders |
| app `WalletPassItem` | sealed: train, movie, bus | a new subclass makes the compiler list every switch site |

So the extraction half is done. What is missing is the wire mapping, the app model and UI,
and a live status source.

## Phase 1 — model, wire, fixtures (app + server mapper)

### Wire shape (`kind: "flight"`, nested `flight`)

Mirrors the bus pass: display strings the server formats, plus RFC3339 instants for maths.

| Field | Type | Notes |
|---|---|---|
| `id` | string | required |
| `airline` | string | display name, "IndiGo" |
| `airlineCode` | string | IATA 2-char, "6E"; drives the brand palette |
| `flightNumber` | string | "6E 2134", carrier code included |
| `bookingRef` | string | airline PNR, 6 chars |
| `origin`, `destination` | object | `{code, city, airport, terminal}`; only `code` required |
| `departAt`, `arriveAt` | RFC3339 | **scheduled**, with the airport's offset |
| `boardingAt` | RFC3339 | optional; printed boarding time |
| `gate`, `seat`, `cabin`, `boardingGroup`, `sequence` | string | all optional |
| `passengers` | array | `{name, seat}` |
| `status` | `active` \| `expired` | |
| `codePayload` / `codePayloadBase64` / `codeFormat` | | same as every pass |
| `live` | object | optional, phase 3 — see below |
| `updates` | array | optional, phase 3 — see below |

Times stay in the **airport's** zone, not the device's: a 06:10 departure from DEL is 06:10 on
the face even if the phone is in London. The model keeps the offset from the RFC3339 string.

### App

- `flight_pass_models.dart`: `FlightPass`, `FlightAirport`, `FlightPassenger`; `airline_brands.dart`: `AirlineBrand`.
- `FlightPassItem` in `pass_catalog.dart`; then fix every switch the compiler flags
  (share summary, activity date, history folder, weather glance, open_pass, tickets tab…).
- `PassKind.flight`, `PassHistoryCategory.flight` mapped 1:1.
- Fixtures: a delayed domestic with a gate change, a timetable-only one, one in the air, a
  foreign overnight with a +1 (Lufthansa), and two past flights (Emirates, Vueling) so the
  archive has a Flights folder. All date themselves relative to launch, like the trains.

### Server

- `mapFlightPass` in `pass_mapper.go`, plus the case in `MapTicketToPassItem`.
- Extend `FlightExtraction` with `bookingReference`, `cabin`, `boardingTime`,
  `arrivalTerminal`, per-passenger seat, and the extraction prompt to match.

## Phase 2 — on-device boarding pass parsing (BCBP)

Every airline boarding pass barcode is IATA Resolution 792 (BCBP). The scanner already decodes
PDF417 / Aztec off the upload; a pure Dart parser over that string gives, with **no AI and no
network**: passenger name, PNR, from, to, operating carrier, flight number, day of year,
cabin, seat, sequence number.

```
M1NAGELLA/NAVADEEP    EX7KQ2M BLRDEL6E 2134 325Y012A0042 100
^^ ^name (20)          ^^PNR(7)^fr^to^cx ^flt(5)^doy^c^seat^seq ^status
```

Use: when the decoded code starts `M1`/`M2`, send the parsed legs with the extract upload as
ground truth; the server prefers them over model output for the fields BCBP carries (it never
carries times, so those still come from the document). A mismatch between BCBP and the model
is a strong signal the model misread.

Pure function, fixture-tested, lives in `domain/bcbp.dart`. Silent-failure code: written by
hand, not delegated.

## Phase 3 — live status and the Updates feed (server first)

### Data source — decided 21 Nov 2026: free ADS-B feeds

Docket is personal and not monetised, so non-commercial terms are acceptable. Live status
comes from aircraft position (ADS-B) feeds, no paid provider:

| Source | Role | Terms |
|---|---|---|
| adsb.lol `/v2/callsign`, `/v2/hex`, `/v2/lat/lon/dist` | primary: position, altitude, speed, registration, type | free, no key (a key "fed by contributing" is announced), ODbL |
| adsbdb.com `/v0/callsign/{cs}` | callsign -> route (origin, destination), cached | free |
| OpenSky `/states/all` | fallback position | non-commercial; anonymous 400 credits/day, accounts use OAuth2 client credentials |

Probed 21 Nov 2026, 12:16 UTC, 150 km around DEL: adsb.lol returned 34 aircraft, 30+ of
them Indian carriers, with registrations. **OpenSky timed out on TCP connect** from the dev
machine (DNS resolves, port 443 never answers), so it stays a fallback until reachable from
the Railway host. OpenSky's `/flights/arrival` and `/flights/departure` are built by a
nightly batch, so they are useless for live status anyway.

What ADS-B **cannot** give, and so the app never shows from this source: gate, terminal,
boarding, airline-announced delay, cancellation, baggage belt. Those `live` fields stay
empty and the face falls back to what the ticket printed. `FlightUpdateType.departed` reads
"Took off", since ADS-B sees wheels-up, not pushback.

What it can give, as facts:

| Fact | From |
|---|---|
| took off, actual time | first airborne sample (altitude climbing, speed > 80 kt) near origin |
| in the air, progress | position along great circle origin -> destination |
| landed, actual time | last airborne sample, then on ground near destination |
| took off N min late | actual take-off minus scheduled departure minus a 15 min taxi allowance |
| aircraft type, registration | `t`, `r` |
| diverted | landed and on ground at an airport that is not the destination |

Estimated arrival from distance and ground speed is allowed only labelled as an estimate,
never as "On time".

### Matching a flight to an aircraft

The ATC callsign is usually the ICAO airline code plus the flight number, and that is where
this gets hard. From the same probe:

| Carrier | Callsigns seen | Derivable from the flight number? |
|---|---|---|
| IndiGo (IGO) | IGO6384, IGO112, IGO2323 … and IGO67AJ | mostly |
| Air India (AIC) | AIC1KB, AIC7CW, AIC5GZ, AIC6QN … and AIC2228 | **mostly not**: alphanumeric |
| Air India Express (AXB), SpiceJet (SEJ) | AXB1622, SEJ124 | yes |

IATA -> ICAO prefix: 6E IGO, AI AIC, IX AXB, QP AKJ, SG SEJ. So matching is two steps:

1. **Direct**: query `/v2/callsign/{ICAO}{number}`. Accept only if adsbdb's route for that
   callsign matches the ticket's origin and destination.
2. **Search**, when direct fails: from T-30m to T+60m, query aircraft within 40 km of the
   origin, keep the carrier's prefix, look up each unseen callsign's route on adsbdb
   (cached by callsign for a day), keep those whose route matches. Exactly one candidate
   that is climbing out of the origin after scheduled departure: match. Zero or several:
   no match, timetable only.

Once matched, store the aircraft's hex (`icao24`) on the run and track by `/v2/hex` from
then on, so a callsign change mid-flight cannot lose it. A wrong match is worse than none,
since it would put another flight's landing on the ticket, so ambiguity always means no
match.

### Shape on the server

Copy the train design: a shared `flight_runs` row keyed by `(flightNumber, departure date at
origin)`, fanned out to every ticket on that flight, polled by the durable job queue.

Poll ladder per run (free API, but be a polite client): nothing before T-30m; every 2 min
from T-30m until matched or T+60m (then give up); every 5 min in the air; every 1 min from
20 min before estimated arrival until on ground; stop 30 min after landing.

Each poll is diffed against the previous snapshot; **only a diff produces an update**, and
material ones (took off, landed, diverted, took off 15+ min late) go to the outbox for FCM.

`FlightStatusProvider` stays an interface, so a paid source for gates and delays can be
added later beside ADS-B without changing the wire.

### Wire additions

```json
"live": {
  "state": "scheduled|boarding|departed|enRoute|landed|arrived|cancelled|diverted",
  "departEstimatedAt": "...", "departActualAt": "...",
  "arriveEstimatedAt": "...", "arriveActualAt": "...",
  "departGate": "B12", "departTerminal": "1", "arriveTerminal": "3",
  "baggageBelt": "4",
  "aircraft": "A320neo", "registration": "VT-IJK",
  "lat": 16.65, "lon": 73.25, "altitudeFt": 21400, "groundSpeedKt": 386,
  "aircraftPhotoUrl": "https://upload.wikimedia.org/...",
  "aircraftPhotoCredit": "Pictured: VT-IJB, same type and livery. Photo ..., CC BY-SA 4.0",
  "updatedAt": "..."
},
"updates": [
  {"at": "...", "type": "gateChange", "from": "B12", "to": "B17"},
  {"at": "...", "type": "delay", "minutes": 25},
  {"at": "...", "type": "departed"}
]
```

`updates` types: `gateAssigned`, `gateChange`, `terminalChange`, `delay`, `earlier`,
`boarding`, `departed`, `landed`, `arrived`, `beltAssigned`, `cancelled`, `diverted`, and
from ADS-B `aircraftFound` (`to` = registration), `cruising` (`to` = feet), `descending`.
The client writes the sentence; the server sends facts.

`live.lat`/`lon` is the aircraft's last ADS-B position; no position means no plane on the
map. Airports may carry `lat`/`lon` too; the app falls back to a bundled table of ~30
Indian airports (`domain/flight_geo.dart`) and draws no map for an airport in neither.

## Phase 4 — face, detail, Updates tab (app UI)

Direction to be agreed against an HTML mock before any Flutter is written, as the bus was.
Motion and artwork direction: `flight-pass-design.md`, prototype `flight-pass-motion.html`.

### Face (382 x 560, the train canvas)

```
 IndiGo                               Sat, 21 Nov
 6E 2134 · PNR X7KQ2M

 Bengaluru                             New Delhi
 BLR          2h 50m          DEL              codes are the hero,
 06:10                              09:00         flight time between them
 Terminal 1                         Terminal 1D

 Boards in 40 min                                 status sentence
 Gate B12 · Boarding 05:30
◖·································◗  tear
 Gate            Seat            Boards
 [B][1][2]       12A              05:30          gate on flaps; seat centred
 Passengers
 Navadeep and 1 other
```

- One solid airline surface, as the bus does for operators. Brand palette resolved from
  `airlineCode`; unknown airlines get a neutral universal surface, never another airline's
  colour. The header carries the airline's real logo in the ink colour (decided 21 Nov 2026,
  see `flight-pass-design.md`); airlines without a logo fall back to the name in type. Light
  liveries (Vueling, Scoot, Jetstar, Pegasus) print in near-black ink.
- The flight time sits between the two codes, centred on their capitals, in one row with
  them so a wide pair squeezes it instead of overlapping it.
- The stub stays clean: no aircraft art on the face. The aircraft lives on the Updates and
  Details tabs, in its real livery.
- The route rule fills with ink as the flight progresses; the plane glyph rides the fill.
- Gate shows the **live** gate when there is one, and a dash (not "TBA") when there is not.
  A known gate is drawn on departure-board flaps, one tile per character with a hinge
  across the middle; a long gate narrows its tiles rather than crowd the seat. The stub
  reads left, centre, right: gate from the inset, seat centred on the card, boarding time
  to the right edge.

### Status sentence — `resolveFlightStatus(pass, now)`, pure, unit-tested

| State | Lead | Detail |
|---|---|---|
| cancelled | **Cancelled** | rebook through the airline |
| landed / arrived | Landed **09:12** | Belt 4 (when known) |
| in the air | Lands in **1h 12m** | 12 min late (only when live says so) |
| boarding | **Boarding now** | Gate B12 |
| delayed, before departure | Delayed **25 min** | Departs 06:35 |
| before departure | Departs in **40 min** / tomorrow / 3 days | Gate B12 · Boarding 05:30 |

Same honesty rule as the train band: "On time" only when live data says so. No live data
means timetable lines only.

### Detail screen

Face, code row (bus/movie pattern, omitted with no code), then `PillSegmented`:
**Details | Updates**.

- Details: `PassInfoCard`s: Flight (airline, number, aircraft, duration), Departure (airport,
  terminal, gate, boarding), Arrival (airport, terminal, belt), Passengers, Booking.
- Updates:
  1. Summary card: two columns, scheduled time struck through beside the revised one when
     they differ, progress arc with the plane, "1h 02m of 2h 50m".
  2. Feed, newest first: time, sentence, tone pill. "Gate changed B12 → B17", "Delayed 25 min",
     "Boarding started", "Departed 06:42, 32 min late", "Landed 09:31", "Bags on belt 4".
  3. Empty state: "Updates start 24 hours before departure." Never a fabricated row.

Not built, unless a provider gives the data: inbound aircraft, maps, seat maps.

## Phase 5 — real tickets: ingest, time zones, trips (23 Nov 2026)

Server design and the field-by-field "who wins" table: `docket_server/docs/flight_ingest.md`.
In short:

- **Barcode first.** The scanner sends every BCBP code it finds (`codes`, a JSON array, beside
  the legacy single-code fields). The server parses them and they override the model for
  PNR, airports, flight number, date, seat, sequence and cabin. A boarding pass whose flights
  are all already on the wallet is merged in with **no model call and no quota**: the
  e-ticket-at-booking, boarding-pass-at-check-in flow.
- **Times.** The model returns the printed wall clock with no offset; the server attaches the
  airport's IANA zone from an embedded table of 7,918 IATA airports (also city, name, lat/lon
  for the route map). Overnight arrivals and boarding times are sanity-checked against the
  departure.
- **Several flights per upload.** The model returns every flight on the document; each is
  its own pass. Re-uploading updates in place.
- **Trips.** `GET /v1/passes` adds `trip: {id, index, legs: [...]}` to flights that share a
  booking reference or an upload. The app reads it with `domain/flight_trip.dart`
  (`flightTripJourneys`, `placeInTrip`): a same-airport change within 24 hours is a
  connection; a later journey ending where the trip began is the return. The face tags the
  leg on the flight-number row ("Leg 1 of 2", "Return", "Outbound · 2 of 2") and, when the
  status has nothing else to say, names the onward flight ("Then 6E 6042 to SXR · 1h 45m in
  DEL"). The Details tab opens with **Your trip**: every leg, connection times, and a tap to
  open the other passes.
- Fixtures: `mock_f1` + `mock_f7` connect in Delhi; `mock_f8` (past) + `mock_f4` are a
  Lufthansa return. Tests: `test/flight_trip_test.dart`.

Not done: self-transfers booked separately (different PNRs, separate uploads) are not linked;
an e-ticket with no barcode is only as good as the model's read of the flight number.

## Order and ownership

1. Phase 1 app domain + fixtures + server mapper. Shippable alone with a plain face.
2. Phase 2 BCBP parser.
3. HTML mock of face + Updates, agreed with the user.
4. Phase 4 UI against the mock.
5. Phase 3 live, after the provider decision. The app side is ready for it from phase 1,
   since `live` and `updates` are optional.

Per `CLAUDE.md`: BCBP, the status resolver, timezone handling and the poll ladder are
silent-failure code and stay hand-written. Widget bodies and tests can go to `agy`.

## Open questions

- ~~Status provider~~: free ADS-B, see phase 3. Check OpenSky reachability from Railway.
- ~~Brand list for v1~~: 85 airlines in `airline_brands.dart`, logos served by the backend.
- ~~Multi-leg bookings~~: one pass per leg, linked by `trip`. Built in phase 5.
