# Pass input layer

Wire the Passes-tab `+` so a user can add a ticket. Replaces
`TicketsComingSoonSheet`.

## What this is

- **Train** — three ways in: 10-digit PNR (`POST /tickets`), photo, or PDF
  (`POST /tickets/extract` with `category=train`).
- **Bus** — photo or PDF (`category=bus`). No PNR path; the server has none.
- **Movie** — photo or PDF (`category=movie`), same extract endpoint. Included
  because the wallet already renders movie passes.

Images and PDFs are the same bytes the server already accepts. The client does
not parse tickets.

## Auth (this slice)

Full Google Sign-In is still out of scope. Extract and PNR require a Bearer
token, so debug builds can exchange a **dev Google id token**
(`--dart-define=DEV_AUTH_ID_TOKEN=…` or Settings → Developer) against
`POST /v1/auth/google`. That is the existing `AUTH_DEV_BYPASS_TOKEN` path on
the server. Tokens live in secure storage under `docket_api_session_v1`, not
in document lists.

Submit is refused while mock fixtures are driving the tab (`isMockPassesActive`).
A file saved on the server would not appear in a mock list.

## After a successful extract

The extract handler returns a ticket blob, not the wallet envelope. The client
takes the ticket `id`, then `GET /v1/passes/:id`, and refreshes the list.

## Bus on the wallet

`GET /v1/passes` used to drop `bus` rows. The mapper now emits
`{ kind: "bus", bus: {…} }` and the app has a `BusPassItem` so an uploaded
bus ticket is visible. The bus card is a first cut, not a Figma lockup.

## Not in this slice

Google Sign-In, flight input, mock-mode local inventing of tickets, Play
packaging.
