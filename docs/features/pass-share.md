# Pass sharing

Status: implemented. Source reviewed 23 November 2026. Owners:
`lib/features/tickets/application/pass_share_service.dart`,
`presentation/share/pass_share_card.dart`, `presentation/share/pass_share_actions.dart`,
`presentation/pass_code_view.dart` and the pass detail screens.

## Actions and output

Train, bus, movie and flight detail screens expose Save/Share through the shared pass actions.
Actions sit at the end of the scroll content. The primary Save action is filled; Share is
secondary. Its local surface must stay distinguishable from the page without changing the
shared `AppTheme.surfaceElevated` role for unrelated consumers.

The label carries progress: Save → Saving → Saved, then resets after 1.6 seconds. Share uses
Preparing while rendering and does not claim Shared after a dismissible OS sheet. Disable
both actions while either operates; rendering two off-screen copies concurrently is wasteful.

Export is the glance face on a fixed dark plate, optional genuine code, and Docket wordmark.
The detail screen is not a screenshot target. Detail rows travel as selectable share-message
text. There is no version label or banner above the ticket. Each face uses `WalletCardCanvas`
with its own bounded design canvas, scaled to a common width. Force `useBrandColors` so an
expired pass exports its booking artwork rather than the wallet's muted spent palette.

Movie glance/export artwork prefers the transparent title logo with its normal fallback;
the opened detail hero uses the poster. See [movie artwork](movie-logo-glance.md).

## Scannable codes

Render through `PassCodeView` with the pass's original format: QR uses `qr_flutter`; other
symbologies use `barcode_widget`. Binary payloads are supported where the pass/code model
permits them. Keep black-on-white contrast and the quiet zone.

Absent payload means **no block, placeholder or caption**. Never substitute a PNR or booking
reference. `passShareCodePayload` resolves the usable code; code validation belongs to the
shared code model. See [code extraction](ticket-code-extraction.md).

The decorative `PassCodeBlock` and `TicketQrPainter` are gone. The current train face draws
no embedded code; the share card adds the genuine code separately. An exported pass must
contain one real code or none, never a second decorative/code-like mark. The old train-code
wart and suppression-flag proposal are resolved history, not work to implement again.

## Capture contract

`PassShareService.renderPng` inserts a real off-screen `OverlayEntry` at `left: -10000`,
waits two frames and captures its `RepaintBoundary`. `Offstage` does not paint and can produce
a blank PNG without throwing. Pre-warm network artwork with a bounded timeout; offline,
missing or failed artwork must use the normal fallback rather than block export.

`PassShareCard` supplies an explicit `DefaultTextStyle` with `TextDecoration.none`.
An overlay without Material otherwise inherits WidgetsApp's red/yellow debug underline.
The fixed style and plate make output independent of the user's light/dark theme; text
scaling is disabled for the export canvas. Tests pump it without MaterialApp to cover this.

Capture scale is `min(3.0, 2400 / logicalHeight)` to bound large PNGs and share-target failures.
Guard against overflow from long movie titles or other unbounded face content.

## Plaintext file lifetime

Sharing writes one PNG into the app's **cache**, never app documents. The OS receiver needs
a real file/content URI; the image contains ticket data and needs a bounded lifetime.

- Purge at the next share and at dashboard startup.
- Keep the file after the share sheet closes: dismissal does not mean the receiving mail/chat
  app finished reading it. Deleting on dismissal can break an unsent draft.
- Purge immediately when sharing fails, since no receiver acquired the file.
- Saving to the photo library hands bytes directly to `gal`; it creates no app temp file.

`Gal.requestAccess()` runs before saving: put methods throw on missing permission rather
than requesting it. Cancellation and permission rejection return `PassShareResult` values.

The external-attachment viewer has a different cleanup boundary; do not copy its close-time
purge to pass sharing. See [attachment lifecycle](id-media-attachments.md).

## Platform and verification

`share_plus` supplies its FileProvider through manifest merge; do not add a duplicate.
Android 26–28 needs `WRITE_EXTERNAL_STORAGE` with `maxSdkVersion=28`; API 29+ uses MediaStore.
iOS needs `NSPhotoLibraryAddUsageDescription` for saving. Its platform scaffold is ignored,
so configure and verify this on each iOS setup rather than assuming another machine's plist.

Existing suites: `pass_share_card_test.dart` (real PNG, canvas/style/code behavior),
`pass_share_text_test.dart`, `pass_code_view_test.dart` and `pass_action_bar_test.dart`.
The iOS photo-library prompt/save and Android 26–28 permission path still need device checks.
