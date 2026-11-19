# Google Calendar import (app side)

Backend design, API and setup: `../docket_server/docs/calendar_import.md`. This note covers the
Flutter owner files and behaviour.

## Where it lives

| File | Role |
|------|------|
| `lib/features/tickets/domain/calendar_import.dart` | `CalendarConnectionStatus`, `CalendarLinkState`, `CalendarImportException`, `PassImportInfo`, reason copy |
| `lib/features/tickets/data/docket_api_client.dart` | `CalendarImportApi` (status / connect / sync / disconnect) on `DocketApiClient`; `extractFile(attachToPassId:)` |
| `lib/features/tickets/application/calendar_import_controller.dart` | `calendarImportProvider` (autoDispose) - phases `loading`, `authorizing`, `syncing`, `disconnecting`, `idle` |
| `lib/features/tickets/presentation/calendar/calendar_import_screen.dart` | Settings → Account → Google Calendar |
| `lib/features/tickets/domain/pass_catalog.dart` | `WalletPassItem.importInfo`, parsed from each pass's `importInfo` |

## Behaviour

- **Mock mode or no API URL:** `calendarImportApiProvider` is null, so the screen shows
  "Mock passes are on..." and never calls the server or pretends a link exists.
- **Unavailable server states** (`disabled`, `not_configured`, `shared_demo_account`,
  `google_sign_in_required`) render as plain explanations; there is no connect button.
- **Connect:** the server mints Google's consent URL; the client refuses anything that is not
  `https://accounts.google.com` and opens it with `LaunchMode.externalApplication` (system
  browser, never a web view). The app holds no Google token at any point and no token is ever in
  a URL the app sees. While `authorizing`, an `AppLifecycleListener` on the screen asks the
  server on resume; only the server's status decides whether it worked.
- **Sync:** after connect or **Sync now** the controller polls status (5s, at most 12 times)
  until a run newer than the request finishes, then refreshes `passListProvider`. The server
  rate-limits manual syncs (429 shown inline). Background sync continues without the app.
- **Disconnect:** confirmation dialog; imported passes stay in the wallet.
- **Needs details:** imports with essential or optional missing booking fields (including a
  missing entry code) are listed with **Add ticket**, which
  picks a JPG/PNG/WebP/PDF and uploads it through the normal ingest path with `attachToPassId`,
  completing that pass in place. The rest of the wallet is unaffected.
- Imported movies with no seat render `—` instead of the parser's `A1` default, and no
  certification/gate label is invented. No code is drawn without a real `codePayload`.
- Imported trains retain an empty passenger list when Google provides no travellers and
  do not gain default seat-confirmation, chart-prepared or on-time claims.

## Verification

`test/calendar_import_test.dart`: status parsing, imported-pass parsing (no synthetic seat,
round-trip), controller transitions (mock mode, connect → authorizing → resume → syncing →
idle + wallet refresh, server refusal, browser failure, throttled sync, disconnect), and the
API client paths/error codes with a mock HTTP client. The screen itself was verified by
`flutter analyze` and source review only - no rendered screenshot or device run, and no real
Google account was connected.
