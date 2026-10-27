# Wallet polish

Scope: show the automatic weather glance once at cold startup, retain manual
pull-to-open, and never interrupt navigation returns or file-picker returns.

PNR creation currently saves before worker enrichment. Give new PNRs a bounded
foreground lookup on the server, retain background recovery, and refresh pending
train details in the client. Pending imports must explain that journey details
are still being fetched instead of presenting an empty confirmed ticket.

Replace particle extraction with a calm ticket-shaped progress surface showing
real milestones. Show a saved-pass summary with route, date, archive destination
and explicit next actions. Keep errors actionable.

Remove the train face shadow inside the archive deck; the deck already overlaps
and dims cards. Give document menu entries recognisable miniature card artwork.
Match the unbranded bus illustration to the red coach's perspective and crop.

Validate with focused weather, ingestion, archive, document-menu and bus widget
tests, static analysis, backend tests, and install over the connected phone's
existing app without clearing data.

## Verification — 27 October 2026

- Full Flutter suite: 691 passing tests. Updated the recovery test's obsolete
  particle-loader copy assertion to the new journey milestone.
- Full static analysis: no errors or warnings; four pre-existing informational
  lints in Settings and NFC. Targeted analysis of changed tickets code was clean.
- Pending train refresh tests cover successful enrichment, retention during
  outages, and the six-attempt limit.
- Rendered import progress and saved/pending outcomes in both themes at 320 and
  390 logical pixels. Fixed dark headline contrast and miniature ID overflow.
- Rendered bus faces at 288 and 382 logical pixels; updated Documents goldens.
- Built Android arm64 debug and installed over the Motorola edge 30 app with
  `adb install -r`; checked Settings return, document-menu artwork and the train
  archive deck. The corrected train aspect removes the rectangular dimming area
  outside its shorter face.
- Backend internal tests passed, including HTTP/1.1 negotiation against an
  HTTP/2-capable TLS test server. API and worker staging updates deployed.
- **Still unverified:** successful lookup of a fresh valid PNR. Existing saved
  train refreshes encountered provider HTTP/2 resets; explicit HTTP/1.1 TLS
  negotiation now reaches a provider timeout instead. This is an upstream
  availability issue, not a successful end-to-end lookup. The user has no
  current PNR available and will check with a fresh booking afterwards.

## Redesign rollback

At the user's request, all visual redesign work from this session was reverted
to the original UI: PNR entry, particle progress, success/error screens, add menu,
document icons, bus artwork, theme, and pass detail titles. Redesign-only source,
assets and tests were removed from the app; a local backup remains under build.

The existing user weather work was preserved. Functional changes retained are
the once-per-startup weather guard, pending train data refresh, backend lookup
handling, and the train archive shadow/aspect correction. The upstream PNR
availability limitation remains as documented above.

Rollback verification: 691/691 Flutter tests pass and the Android arm64 debug APK builds successfully.
