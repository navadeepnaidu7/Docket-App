# Passes API contract (client-ready)

This document is the contract between the app and `docket_server`. The Flutter Passes tab already consumes these shapes via `PassRepository` + `PassListResponse.fromJson`.

**Status (2 Aug 2026):** the server implements this envelope; the app does not call it yet.
Default client implementation is **`MockPassRepository`** (fixtures); **`RemotePassRepository`**
is still a stub that throws `UnimplementedError`. See [`../current_state.md`](../current_state.md).

**Backend (docket_server):** `GET /v1/passes` and `GET /v1/passes/{id}` implement this envelope. Movie tickets are extracted via `POST /tickets/extract` (`category=movie` optional) with brands `bookMyShow` | `district` | `universal`. See `docket_server/docs/architecture.md` for pass **family** taxonomy (travel vs event vs hotel).

**In-app switch:** Settings → Developer (debug/profile). See also [dev-flags.md](../dev-flags.md).

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/v1/passes` | List wallet passes — **live on the server** |
| `GET` | `/v1/passes/{id}` | Single pass (train or movie envelope) — **live** |
| `GET` | `/v1/passes/{id}/live` | Train live status only (`?force=1` to bypass cache) — **live** |
| `GET` | `/v1/passes/{id}/code` | *(not implemented)* gate code payload / image URL |

### Query params (`GET /v1/passes`)

| Param | Values | Notes |
|-------|--------|--------|
| `status` | `active` \| `expired` | Optional filter |

### Headers

```
Authorization: Bearer <access_token>
Accept: application/json
```

### Status codes

| Code | Meaning |
|------|---------|
| `200` | OK |
| `401` | Auth required / expired |
| `404` | Pass id not found |
| `500` | Server error |

Empty wallet → `200` with `"items": []` (preferred over `404`).

---

## List response

```json
{
  "items": [
    {
      "kind": "movie",
      "movie": { }
    },
    {
      "kind": "train",
      "train": { }
    }
  ],
  "updatedAt": "2025-04-12T10:00:00Z"
}
```

- **`kind`**: `"train"` | `"movie"` | `"bus"` (required discriminator)
- Nested object key matches kind: `train`, `movie`, or `bus`

### Detail response

Either the same envelope as one list item, or the nested object only. Client accepts both via `walletPassItemFromJson` / nested parse.

---

## Train object

| Field | Type | Required | UI use |
|-------|------|----------|--------|
| `id` | string | yes | identity |
| `operator` | string | yes | e.g. IRCTC |
| `trainNumber` | string | yes | header |
| `trainName` | string | yes | header |
| `fromCode` / `fromName` | string | yes | route |
| `toCode` / `toName` | string | yes | route |
| `departTime` | string | yes* | display e.g. `"07:10 AM"` |
| `arriveTime` | string | yes* | display |
| `date` / `arrivalDate` | string | yes* | display e.g. `"20 Jul 2025"` |
| `duration` | string | yes | e.g. `"7h 30m"` |
| `ticketClass` | string | yes | e.g. `"AC 2 Tier"` |
| `passengers` | array | yes | 1–6 |
| `pnr` | string | yes | |
| `bookingId` | string | yes | |
| `status` | string | yes | `active` \| `expired` |
| `bookingStatus` | string | no | default Confirmed |
| `chartStatus` | string | no | |
| `liveStatusLabel` | string | no | live tab, free text |
| `runState` | string | no | `scheduled` \| `onTime` \| `delayed` \| `arrived` \| `cancelled` |
| `delayMinutes` | integer | no | minutes late; **omit when unknown** |
| `progressFraction` | number | no | 0–1 |
| `halts` | array | no | live timeline |
| `departAt` / `arriveAt` | string (ISO-8601) | no | preferred machine times |
| `codeType` / `codePayload` | string | no | future scannable QR |

\*Client currently shows string fields; ISO fields are optional until formatters land.

### Live running state

`liveStatusLabel` is free text and stays that way — the detail screen's Live tab
prints it verbatim. It cannot drive styling, so the wallet card's status band reads
`runState` and `delayMinutes` instead.

- **`delayMinutes` absent and `0` are different answers.** Absent means the server has
  no live data; `0` means the train is running to schedule. The client never coalesces
  one into the other, and only draws the amber "delayed" line when the value is
  present and greater than zero.
- **`onTime` is a claim, not a default.** The card shows "On time" only when
  `runState` says so. A missing `runState` falls back to `scheduled`, and the band
  shows a countdown rather than asserting punctuality the server never reported.
- `cancelled` suppresses every other band message — a platform number or a countdown
  next to a cancelled train is worse than silence.
- Platform for the band comes from `halts[].platform`: the origin halt before
  departure, `nextHalt` once the origin reads `departed`. `"PF 3"`, `"3"` and
  `"Platform 3"` all normalise to `"Platform 3"`.

Both fields are optional, and a payload omitting them renders exactly as it did before
they existed.

### Passenger

```json
{
  "name": "Navadeep Naidu",
  "coach": "B2",
  "seat": "32",
  "berth": "Lower",
  "age": 28,
  "gender": "M"
}
```

### Halt

```json
{
  "time": "11:40",
  "actual": "11:48",
  "station": "Vijayawada Jn (BZA)",
  "platform": "PF 3",
  "state": "arriving",
  "dateLabel": "Sun, 20 Jul"
}
```

`state`: `departed` | `arriving` | `upcoming`

---

## Movie object

| Field | Type | Required | UI use |
|-------|------|----------|--------|
| `id` | string | yes | |
| `brand` | string | yes | `bookMyShow` \| `district` \| `universal` |
| `movieTitle` | string | yes | |
| `movieSubtitle` | string | no | genre line |
| `cinemaName` / `cinemaAddress` | string | yes | Place |
| `screen` | string | yes | |
| `showDate` / `showTime` | string | yes* | display |
| `showAt` | ISO-8601 | no | preferred |
| `format` / `language` | string | yes | |
| `seats` | array | yes | `{ "row", "number" }` |
| `bookingId` / `orderId` | string | yes | Booking Details |
| `status` | string | yes | `active` \| `expired` |
| `certification` / `runtime` | string | no | |
| `gateType` | string | no | e.g. QR Scan |
| `sourcePlatform` | string | no | universal footer only |
| `codeType` | string | no | `qr` \| `barcode` |
| `codePayload` | string | no | real code data |
| `posterUrl` | string | no | Absolute Docket image-proxy URL. **May be absent** — see Poster art |
| `posterHint` | string | no | UI fallback gradient family |

Unknown `brand` → client maps to **`universal`**.

Do **not** send logo assets; brand styling is client-side.

### Poster art

Movie posters are resolved server-side from TMDB and served through the Docket API:

```
GET /img/poster/{size}/{file}
```

- **Public** — no `Authorization` header. These are public movie posters and the URL carries
  no user identifier, so the client's image layer needs no token handling.
- `size` is one of `w185`, `w342`, `w500`, `w780`. Anything else is `400`.
- `file` is a TMDB poster filename (`^[A-Za-z0-9]{20,64}\.(jpg|png|webp)$`).
- Responses carry `Cache-Control: public, max-age=31536000, immutable` and an `ETag`. TMDB
  poster paths are content-addressed, so the bytes behind a filename never change.
- `404` means the poster could not be fetched; the client falls back to the `posterHint`
  gradient.

Images are **proxied rather than linked directly** because `image.tmdb.org` is blocked by
Indian ISPs. A raw TMDB CDN URL resolves fine on the server and then fails on the user's phone.

`posterUrl` is **absent** when the film has not been matched yet (lookup runs asynchronously
after extraction) or when TMDB has no confident match. Clients must treat a missing poster as
normal and render the `posterHint` gradient — never substitute a placeholder film's artwork.

---

## Example: movie list item

```json
{
  "kind": "movie",
  "movie": {
    "id": "movie_bms_1",
    "brand": "bookMyShow",
    "movieTitle": "Dune: Part Two",
    "movieSubtitle": "Sci-Fi · UA 13+",
    "cinemaName": "PVR INOX Phoenix Mall",
    "cinemaAddress": "Phoenix Marketcity, Whitefield, Bengaluru",
    "screen": "Screen 5 · IMAX",
    "showDate": "Sat, 12 Apr 2025",
    "showTime": "7:15 PM",
    "format": "IMAX 2D",
    "language": "English",
    "seats": [
      { "row": "H", "number": "12" },
      { "row": "H", "number": "13" }
    ],
    "bookingId": "BMS-8F2K9P1Q",
    "orderId": "ORD99763JS",
    "status": "active",
    "certification": "UA 13+",
    "runtime": "2h 46m",
    "codeType": "qr",
    "posterUrl": "https://api.docket.app/img/poster/w500/czembW0Rk1Ke7lCJGahbOhdCuhV.jpg",
    "posterHint": "sciFi"
  }
}
```

## Example: train list item

```json
{
  "kind": "train",
  "train": {
    "id": "mock_t1",
    "operator": "IRCTC",
    "trainNumber": "12932",
    "trainName": "Rajdhani Express",
    "fromCode": "HYB",
    "fromName": "Hyderabad",
    "toCode": "BLR",
    "toName": "Bengaluru",
    "departTime": "07:10 AM",
    "arriveTime": "02:40 PM",
    "date": "20 Jul 2025",
    "arrivalDate": "20 Jul 2025",
    "duration": "7h 30m",
    "ticketClass": "AC 2 Tier",
    "passengers": [
      {
        "name": "Navadeep Naidu",
        "coach": "B2",
        "seat": "32",
        "berth": "Lower"
      }
    ],
    "pnr": "1234567890",
    "bookingId": "IRCTC1234567890",
    "status": "active",
    "liveStatusLabel": "Running on time",
    "runState": "onTime",
    "delayMinutes": 0,
    "progressFraction": 0.48,
    "halts": []
  }
}
```

---

## Flutter integration points

| Piece | Path |
|-------|------|
| Repository interface | `lib/features/tickets/domain/pass_repository.dart` |
| Mock data | `lib/features/tickets/data/mock_pass_fixtures.dart` |
| Mock repo | `lib/features/tickets/data/mock_pass_repository.dart` |
| Remote stub | `lib/features/tickets/data/remote_pass_repository.dart` |
| List provider | `lib/features/tickets/application/pass_list_provider.dart` |
| JSON models | `ticket_models.dart`, `movie_pass_models.dart`, `pass_catalog.dart` |

**One-line switch to remote:**

```dart
// pass_list_provider.dart
final passRepositoryProvider = Provider<PassRepository>((ref) {
  return RemotePassRepository(
    baseUrl: 'https://api.example.com',
    enabled: true,
  );
});
```

Then implement HTTP inside `RemotePassRepository` using `PassListResponse.fromJson`.

---

## Conventions

- JSON **camelCase**
- Enums as **strings**
- Prefer additive fields; client ignores unknown keys
- Never require UI-only fields (`posterAsset`, brand colors). `posterAsset` is **client-only**
  — the server must never send it; it exists so fixtures can pin a bundled image.
