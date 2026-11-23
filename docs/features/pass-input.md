# Pass input

How a pass gets into the wallet from the Passes-tab `+`. Menu layout is in
`add-menu-redesign.md`; import progress, failure recovery and search are in
`alpha-usability-polish.md`; Google Calendar import is in `calendar-import.md`; flights are in
`flight-pass.md`.

Status: implemented for train, bus and movie. Owners:
`lib/features/tickets/presentation/add/add_pass_flow.dart`,
`lib/features/tickets/application/pass_ingest_controller.dart`, `pass_ingest_service.dart`,
`pass_list_provider.dart`, `lib/features/tickets/data/docket_api_client.dart`,
`remote_pass_repository.dart`. Contract: `../api/passes.md`.

## Paths in

- **Train**: 10-digit PNR (`POST /tickets`), photo, or PDF (`POST /tickets/extract`,
  `category=train`).
- **Bus**: photo or PDF (`category=bus`). The server has no bus PNR path.
- **Movie**: photo or PDF (`category=movie`).

The client does not parse tickets; it uploads the same bytes the server accepts. The one
exception is the gate code, decoded on device before upload (`ticket-code-extraction.md`).

## Auth

Full Google Sign-In is still open. Extract and PNR need a Bearer token, so debug builds
exchange a dev Google id token (`--dart-define=DEV_AUTH_ID_TOKEN=...` or Settings ->
Developer) at `POST /v1/auth/google` (the server's `AUTH_DEV_BYPASS_TOKEN` path). Tokens live in
secure storage under `docket_api_session_v1`, never in document lists. A 401 triggers one
refresh. With no session and no dev token the repository is empty, not mock.

Submit is refused while mock fixtures drive the tab (`isMockPassesActive`): a ticket saved on
the server would never appear in a mock list.

## After a submit

- Extract returns a ticket blob, not the wallet envelope. The client takes its `id`, fetches
  `GET /v1/passes/:id`, and refreshes the list.
- A new PNR is saved before the server's worker finishes enrichment, so a train can arrive
  "awaiting journey". The wallet must say details are still being fetched, never present an
  empty confirmed ticket. `PassListNotifier` re-fetches remote lists that contain such a pass:
  up to six attempts at 3 s, 6 s, 9 s ... and keeps the saved wallet visible if the provider is
  temporarily down. The server also does a bounded foreground lookup.
- Upstream note (27 Oct 2026): fresh-PNR lookups hit provider HTTP/2 resets and then timeouts
  even with forced HTTP/1.1. A successful end-to-end lookup of a fresh valid PNR is still
  unverified.

## Not in scope here

Google Sign-In, Play packaging, and inventing tickets locally in mock mode.
