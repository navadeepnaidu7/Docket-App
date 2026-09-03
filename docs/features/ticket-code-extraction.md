# Ticket code extraction

Decode the real scannable code off an uploaded ticket and render it, replacing the decorative
`TicketQrPainter` / `PassCodeBlock` grids that never encoded anything.

Status: in progress. Sibling changes land in `../docket_server`.

## The problem

Every code drawn on a pass today is fake:

| Where | What it draws |
|---|---|
| `movie_ticket_code_screen.dart` | `TicketQrPainter` — a seeded-LCG 13x13 grid, commented "not scannable" |
| `bus_ticket_code_screen.dart` | the same painter |
| `ticket_detail_screen.dart` (train) | `Icons.qr_code_2_rounded`, a Material glyph |
| `train_ticket_face.dart` | `PassCodeBlock` — a fixed 7x7 grid from the design export |

Meanwhile the field to hold a real one has existed end to end since the pass contract was
written — `MoviePass.codePayload`, `TrainPass.codePayload`, `BusPass.codePayload`,
`domain.MovieExtraction.CodePayload`, `pass_mapper` — and **nothing ever populates it**. The
OpenRouter prompt says "Leave codePayload empty unless clearly present as text/URL", which is
correct: a vision model cannot read a QR bitmap, and asking it to would produce a confident
hallucination that fails at a turnstile.

Share already behaves correctly (`passShareCodePayload`, `docs/features/pass-share.md`): real
QR when a payload exists, nothing when it does not. This feature makes the payload exist and
brings the in-app screens up to the same rule.

## Decision: decode on device

Decoding happens in the Flutter app with `google_mlkit_barcode_scanning`, before the upload.

- **Cost**: zero marginal. No LLM tokens, no server CPU, no extra network. ML Kit's barcode
  models run on-device.
- **Accuracy**: a decoded symbol is ground truth. Re-encoding the same payload in the same
  symbology produces a code that scans identically at a gate.
- **Already here**: `google_mlkit_barcode_scanning` is a direct dependency and
  `id_scanner_service.dart:93` already runs exactly this call for Aadhaar/PAN. `pdfx` is a
  direct dependency and rasterises PDF tickets. `qr_flutter` renders.

Rejected: decoding server-side in Go. It needs a zxing port *plus* a PDF rasteriser
(pdfium/poppler) in the image, burns CPU per extract, and is strictly less accurate than
decoding before the client's own JPEG re-encode.

The decoded payload is **uploaded** with the extract request and stored in the ticket's
`metadata` JSONB, so it survives reinstall and reaches a second device. Metadata is schemaless,
so this needs no migration.

## Symbologies

All of them, not just QR. BookMyShow and PVR print Code 128 strips as often as QR; airline
boarding passes are PDF417 or Aztec. Re-rendering a Code 128 payload *as a QR* produces a
symbol no gate reads, so the format has to travel with the payload.

Wire values (`codeFormat`): `qr`, `aztec`, `dataMatrix`, `pdf417`, `code128`, `code39`,
`code93`, `codabar`, `ean13`, `ean8`, `itf`, `upcA`, `upcE`. Absent means `qr` — that matches
what the client already assumed for train and bus.

Rendering: `qr_flutter` for `qr`, `barcode_widget` (new dependency) for the rest.

### Binary payloads

ML Kit returns `rawValue == null` when the symbol's bytes are not valid UTF-8. That is rare on
Indian tickets but real, and truncating to text would corrupt the code silently. When it
happens **and the format is QR**, the raw bytes travel as `codePayloadBase64` and render via
`QrCode.fromUint8List` + `QrImageView.withQr`. For linear symbologies a non-text payload is
meaningless, so a null `rawValue` there is treated as "no code found".

## Picking the right code

A ticket screenshot often carries more than one symbol: the gate code, plus an app-store QR, a
"rate us" link, a UPI intent, an operator logo QR. Choosing wrong is worse than choosing
nothing. The selection rule, kept as a pure function so it is unit testable without ML Kit:

1. Drop candidates with no usable payload.
2. Drop known non-ticket payloads — `play.google.com`, `apps.apple.com`, `itunes.apple.com`,
   `facebook.com`, `instagram.com`, `twitter.com`, `x.com`, `youtube.com`, `youtu.be`,
   `wa.me`, `whatsapp.com`, and `upi:` intents.
3. Prefer the largest `boundingBox` area. The code a gate scans is the one printed big.
4. Tie-break on document order.

## Degrading

ML Kit barcode scanning uses the **Play Services** variant, so on a fresh install the model may
not have downloaded yet — the same caveat `id_scanner_service.dart` already carries. Every
failure path (model absent, PDF render failure, no symbol found, decode throw) resolves to
"upload without a code", never to an error the user sees. Extraction is unaffected; the pass
simply arrives without a scannable code, which is the state every pass is in today.

## No fake fallback

When a pass has no code, nothing draws a code. This extends the rule already written down in
`docs/features/pass-share.md` to the in-app screens, for the same reason: a user cannot tell a
decorative grid from a real one, and finding that out at a turnstile is the worst possible
moment. The code screens show an explicit empty state with the booking reference instead.

`TicketQrPainter` and the decorative branch of `PassCodeBlock` are deleted, not kept behind a
flag.

## Shape of the change

### App

| File | Change |
|---|---|
| `pubspec.yaml` | add `barcode_widget` |
| `domain/pass_code.dart` | new — `PassCodeFormat` enum, `PassCode` value object, `passCodeFor(WalletPassItem)` |
| `domain/ticket_models.dart`, `movie_pass_models.dart`, `bus_pass_models.dart` | add `codeFormat` + `codePayloadBase64` alongside the existing `codePayload` |
| `application/ticket_code_scanner.dart` | new — ML Kit decode, PDF rasterise via `pdfx`, pure selection function |
| `application/pass_ingest_service.dart` | scan in `submitFile` before `api.extractFile` |
| `data/docket_api_client.dart` | send `codePayload` / `codePayloadBase64` / `codeFormat` multipart fields |
| `presentation/pass_code_view.dart` | new — renders `PassCode` as QR or barcode; one widget for every surface |
| `movie_ticket_code_screen.dart`, `bus_ticket_code_screen.dart`, `ticket_detail_screen.dart` | real code or empty state |
| `movie_ticket_chrome.dart`, `pass_code_block.dart`, `train_ticket_face.dart` | real code when present, hidden when not; delete `TicketQrPainter` |
| `data/mock_pass_fixtures.dart` | payloads on some fixtures, none on others, so both states are exercised in mock mode |

### Server

| File | Change |
|---|---|
| `internal/domain/code.go` | new — format allowlist, size caps, `NormalizeScannedCode` |
| `internal/http/handlers/ticket.go` | read the three new multipart fields |
| `internal/service/ticket.go` | merge the scanned code into `extracted.Metadata` for **any** category, after normalisation |
| `internal/service/pass_mapper.go` | emit `codePayload` / `codeFormat` / `codePayloadBase64` on train, movie and bus |
| `docs/api/passes.md` | contract |

The merge is category-agnostic on purpose: it writes generic metadata keys rather than adding
`CodePayload` to `TrainExtraction`, `BusExtraction` and `FlightExtraction` one at a time. Flight
and event passes inherit it for free the day they get UI.

**Client-scanned wins over the model's guess.** The extractor only ever copies a string it saw
printed as text; a decoded symbol is the code itself.

Validation is not optional — these fields are client-supplied and land in a JSONB column read
back by every device on the account: format must be in the allowlist, payload is capped at 4096
bytes (above every symbology's own capacity), base64 must decode, and the payload is **never
logged** (`CLAUDE.md`: never log full booking payloads).

## Not in this change

- **Re-scanning an existing pass.** A pass that arrived before this shipped, or arrived while
  the ML Kit model was still downloading, has no way to gain a code. That wants a
  `PATCH /tickets/:id/code` endpoint plus an entry point on the detail screen.
- **Max screen brightness on the code screens.** Standard for a gate-scan view and worth doing,
  but it is a separate concern from extraction.
- `image_picker` keeps `imageQuality: 85`. Full-resolution JPEG at q85 does not measurably hurt
  ML Kit on ticket-sized symbols, and raising it costs upload bytes against a 12 MB cap.
