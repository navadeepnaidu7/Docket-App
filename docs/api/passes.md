# Passes API contract (client-ready)

This document is the handoff for backend implementers. The Flutter Passes tab already consumes these shapes via `PassRepository` + `PassListResponse.fromJson`.

Default client implementation: **`MockPassRepository`** (fixtures).  
Swap to **`RemotePassRepository`** when `baseUrl` + auth exist.

**In-app switch:** Settings → Developer (debug/profile). See also [dev-flags.md](../dev-flags.md).

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/v1/passes` | List wallet passes |
| `GET` | `/v1/passes/{id}` | Single pass (train or movie envelope) |
| `GET` | `/v1/passes/{id}/live` | *(optional)* train live status only |
| `GET` | `/v1/passes/{id}/code` | *(optional)* gate code payload / image URL |

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

- **`kind`**: `"train"` | `"movie"` (required discriminator)
- Nested object key matches kind: `train` or `movie`

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
| `liveStatusLabel` | string | no | live tab |
| `progressFraction` | number | no | 0–1 |
| `halts` | array | no | live timeline |
| `departAt` / `arriveAt` | string (ISO-8601) | no | preferred machine times |
| `codeType` / `codePayload` | string | no | future scannable QR |

\*Client currently shows string fields; ISO fields are optional until formatters land.

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
| `posterUrl` | string | no | network image |
| `posterHint` | string | no | UI fallback gradient family |

Unknown `brand` → client maps to **`universal`**.

Do **not** send logo assets; brand styling is client-side.

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
    "posterUrl": "https://example.com/posters/dune.jpg"
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
- Never require UI-only fields (`posterAsset`, brand colors)
