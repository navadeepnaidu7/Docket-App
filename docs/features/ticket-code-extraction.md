# Ticket code extraction

Status: implemented in the app and sibling server; source reviewed 23 November 2026,
including the active flight work. This is the maintained code-handling contract.

## Owners

- `lib/features/tickets/application/ticket_code_scanner.dart`: ML Kit decode, PDF rasterization,
  non-ticket filtering, `selectTicketCode`, `boardingPassCodes`, `scanAll` and compatibility `scan`.
- `application/pass_ingest_service.dart`: scan before extraction upload.
- `data/docket_api_client.dart`: text/binary payload, original format and extra boarding codes.
- `domain/pass_code.dart`: shared code model/validation; `presentation/pass_code_view.dart`:
  rendering for code screens and shared PNGs.
- `../docket_server`: extraction persistence and pass mapping; wire details in
  [passes API](../api/passes.md) and [flight contract](flight-pass.md).

## Decode genuine data

Decode the symbol on device before uploading the ticket. A vision model cannot reliably
recover barcode data from an image; asking it to invent a payload can produce a plausible
code rejected at the gate. The server stores the decoded payload in ticket metadata so
it survives reinstall and reaches another device. Never log payloads or document data.

ML Kit's barcode model comes through Play Services. A fresh install can lack it; PDF render
failures, absent symbols, unsupported bytes and decode errors degrade to upload without a
code. Extraction still proceeds. Do not add a synthetic fallback to hide a missing model.
PDF rasterization uses bounded temporary work and cleanup; see the scanner's implementation.

## Formats and binary payloads

Preserve `codeFormat` with the payload. Wire formats: `qr`, `aztec`, `dataMatrix`, `pdf417`,
`code128`, `code39`, `code93`, `codabar`, `ean13`, `ean8`, `itf`, `upcA`, `upcE`.
An absent format retains the legacy QR interpretation. A Code 128 payload re-encoded as a
QR is not the original gate code; format is not a styling preference.

Text travels in `codePayload`; raw bytes, when supported, use `codePayloadBase64`.
The scanner preserves QR bytes when ML Kit has no UTF-8 `rawValue`, rather than corrupting
them through text conversion. `PassCode` validates the supported format/payload combinations;
unsupported data remains absent. QR rendering uses `qr_flutter` (including its byte-oriented
API); other supported symbologies use `barcode_widget` through the same `PassCodeView`.

## Selecting among symbols

Screenshots can include marketing, payment and app-store codes alongside the gate code.
The non-flight selection function:

1. Drops unusable payloads.
2. Rejects known non-ticket hosts (Google/Apple app stores, social/video/messaging sites)
   and `upi:` payment intents.
3. Prefers the largest bounding-box area, with document order as tie-breaker.
4. Returns a usable candidate from the first page with one; a general multi-booking
   selection UI is not implemented.

Flight boarding passes are an explicit exception. `scanAll` retains distinct, parseable
BCBP payloads across PDF pages, ordered by page and symbol area. Ingest sends the first
code and `moreCodes` for the rest; the backend maps legs and grouped-trip details as described
in [flight passes](flight-pass.md). Compatibility `scan` returns the first result.
Do not generalize this into a guarantee that every multi-person/non-BCBP document imports
all its bookings or that one code covers every passenger.

## Rendering and absence

### Unified scan UI (24 November 2026)

Train, movie, bus and flight codes use one fullscreen `PassCodeScreen`, with
the same close action, typography, responsive code plate and labelled reference.
Category adapters supply the title/route, timing, reference label and optional
absence message; they do not own separate layouts. Trains use this route too,
replacing their former bottom sheet. Short screens and enlarged text can scroll;
the plate fits the available width without changing the symbol's proportions.

`PassCodeRow` owns the detail-screen scan affordance. Its default surface sits
under train/bus/flight faces; its embedded variant fits the existing movie face.
All omit the affordance when the pass has no genuine code. Category artwork,
journey fields and live-status behavior remain owned by their existing widgets.
This consolidation does not add brightness control or new passenger-code selection.

Related detail chrome now shares `PassDetailHeader` across all four categories
and `PassDetailTabContent` for train/flight transitions. Header titles, copy
targets and tab contents remain category-owned. Further reuse candidates are
bus/flight passenger seat rows and optional theme defaults in `PassInfoCard`.
Keep train booking-state rows and airport-local date calculations separate;
similar-looking fields do not imply the same domain rules.

A code appears only when the pass carries genuine usable data, in its original symbology.
No payload means no code-like artwork, fake grid or fallback made from a PNR/booking ID.
Code screens can explain absence and display a human reference; that reference must not
be drawn as a scannable code. Shared PNGs omit the code block entirely when absent.

The decorative `TicketQrPainter` / `PassCodeBlock` implementations are deleted. The current
train face has no embedded code; detail screens open the code view and exported passes
add their genuine code separately. Do not reintroduce decorative symbols or duplicate
code blocks. See [sharing](pass-share.md).

## Remaining scope and verification

Re-scanning an old saved pass to add a missing code is not implemented; that needs an
explicit update API and detail-screen flow. Automatic screen brightness on code screens
is also separate work. Keep decoder input quality: reducing ticket resolution before
scanning can destroy a valid symbol.

Existing suites: `pass_code_test.dart`, `pass_code_view_test.dart`,
`pass_ingest_controller_test.dart`, `flight_pass_test.dart`, `pass_share_card_test.dart`
and `pass_share_text_test.dart`. Test absence, payload round-trips, format preservation,
non-ticket filtering and multi-boarding-code handling. Fresh-model download behavior and
real gate-scanner acceptance still need device/physical-ticket checks.
