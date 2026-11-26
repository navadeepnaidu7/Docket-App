# Wallet search and import recovery

Alpha usability contract: in-memory wallet search, persistent import outcomes, sample-data
labelling, and the upcoming-pass selector. Absorbs the 27 Oct 2026 session-polish note.

Status: implemented. Owners: `WalletSearchScreen` (opened from `dashboard_screen.dart`),
`lib/features/dashboard/application/search_button_provider.dart`,
`lib/features/tickets/presentation/add/pass_ingest_outcome.dart`,
`pass_ingest_particle_card.dart`, `lib/features/tickets/domain/pass_display.dart`
(`nextUpcomingPass`, `passStartTime`). Tests: `test/upcoming_pass_test.dart` and the search and
ingest-controller tests.

## Search

- Header search, enabled from Settings -> Navigation -> Search button; **off by default**.
- One route covering documents, active passes and archive, with All / Documents / Passes /
  Archive filters. Matching stays in memory (holder names, document numbers, routes, movie
  titles, passengers, booking references); nothing is sent anywhere.
- Documents reveal their existing wallet card; train, movie and bus results open their
  existing detail route. The query survives opening and returning from a pass.

## Import outcomes

- Loading and success use the particle card. Loading text names real phases, with no fake
  percentage. Success closes a ring, draws a tick, names the ticket ("Your train ticket is
  added"), mentions a missing boarding code, then clears. An archived pass says it went to
  Archive and clears on its own.
- **Only a failure stays up** until the user retries, replaces the input, or dismisses it.
  Retry reuses the original request (the file path, not the bytes). Cancelling a replacement
  picker or PNR editor keeps the failed request; PNR edits are prefilled and an invalid edit
  never replaces it.
- Demo-mode errors use product wording rather than pointing testers at Developer settings.

## Labelling and selection

- Sample passes are labelled as samples in **all** build modes, not only developer builds.
- `nextUpcomingPass` combines date and time fields and ignores unknown timestamps and past,
  expired, cancelled or arrived journeys. It feeds the weather glance and account summary.
  The "Up next" glance above the Passes deck was removed at the owner's request
  (12 Sep 2026); so was the "Attachments - N" strip under ID cards (it read "Attachments - 0"
  on almost every card).

## Controls

Shared filled/outlined buttons share type, shape and 48 px minimum targets. Header/menu chrome
uses theme tokens. Card artwork and motion were deliberately not changed by this work.

## Rolled back

A 27 Oct 2026 visual redesign of PNR entry, import progress, success/error screens, the add
menu, document icons, bus artwork, theme and pass titles was reverted to the original UI at the
user's request. Functional changes kept from it: pending train refresh (`pass-input.md`), the
backend lookup handling, and the train archive shadow/aspect fix (the archive deck already
overlaps and dims cards, so the train face draws no shadow there). Do not resurrect the
reverted visuals from build backups without a new decision.

## Tools and limits

`tool/alpha_polish_preview_test.dart` renders the real theme at 390x844 (1x) and 320x640 (2x)
in light and dark into `build/alpha-preview`; it is a manual tool, not part of the suite.
Unverified on hardware: native camera/file-picker permissions, real gate-code scanning, NFC,
and end-to-end imports against the configured backend.
