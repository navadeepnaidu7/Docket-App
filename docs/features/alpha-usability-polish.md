# Alpha usability and visual polish

Scope: complete import recovery, searchable wallet browsing, visible attachment
access, upcoming-pass hierarchy, explicit demo labeling, and consistent controls.
Auth and animation tuning are excluded. Another session owns animation polish;
do not edit its sky/weather files or shared motion primitives.

## Implementation

- Persistent import outcomes with retry, replace input, dismiss, and view-pass
  actions. Preserve request data until dismissed. Explain missing boarding codes.
- One wallet browse/search route covering documents, active passes, and archive.
  Search stays in memory and opens existing card/detail routes.
- Visible attachment access on ID cards, and actionable empty states.
- Upcoming pass summary, based on the actual journey/show time, with unknown
  dates excluded. Explicit sample-data notice in all build modes.
- Theme tokens for header/menu chrome; accessible control targets and flexible
  list layouts. Preserve card artwork and existing motion behavior.

## Validation

Meaningful tests for search matching/scope, upcoming selection, persistent import
recovery and navigation. Render small/large-text light/dark states for new UI.
Run analyzer and relevant existing suites. Record device-only limits honestly.

## Implemented

- Header search opens `WalletSearchScreen`, added from Settings -> Navigation ->
  Search button and off by default; documents reveal their existing
  wallet card, and train/movie/bus results open their existing detail route.
  Results retain their query while opening and returning from pass details.
- Import failures and successes remain visible until acted on. Retry keeps the
  original request. Cancelling a replacement file picker or PNR editor keeps the
  failed request. PNR edits are prefilled; invalid edits never replace it.
- Success explains whether a boarding code exists; archived passes have a direct
  View pass action. Loading text names real phases, without a fake percentage.
- Sample pass labeling is visible outside developer builds. Demo import errors
  use product wording rather than sending alpha testers into Developer settings.
- Upcoming selection combines date/time fields and ignores unknown timestamps,
  past, expired, cancelled, or arrived journeys.
- The attachment-only sheet has Done and does not offer removal of the ID itself.
- Shared filled/outlined buttons use the same type, shape, and 48px minimum
  targets. Dark input hints, header/menu tokens, and profile target are aligned.

Removed at the owner's request (2026-09-12):

- The "Up next" glance above the Passes deck. `UpcomingPassGlance` is deleted;
  `nextUpcomingPass` / `passStartTime` remain in `tickets/domain/pass_display.dart`
  and stay covered by `test/upcoming_pass_test.dart`.
- The "Attachments - N" strip under ID cards and in search results. Attachments
  are still reached from the ID card's own detail route. Both surfaces read
  "Attachments - 0" for the common case of an ID with no files, which was noise
  on every card.

No auth, backend, storage schema, or animation primitive changes were made for
this work. Existing card artwork is retained. The import particle widget remains
the loading presentation; persistent outcomes are a separate functional surface.

Visual review: `tool/alpha_polish_preview_test.dart` renders the actual theme and
Inter fonts at 390×844 (1x text) and 320×640 (2x text), in light and dark modes.
PNG output is under `build/alpha-preview`. That manual rendering tool permits
font downloads into a build-only cache; it is not part of the normal test suite.

Hardware checks still needed: native camera/file picker permissions, actual gate
code scanning, NFC, and end-to-end imports against the configured backend. No
mobile device was attached during this pass.
