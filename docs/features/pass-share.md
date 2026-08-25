# Pass share

Exporting a pass as an image plus text, to another app or to the photo library.

## Why

A pass detail screen used to be a dead end. The only "Share ticket" affordance in the tickets
feature was a stub whose `onTap` popped the sheet and did nothing, so the only way to forward a
ticket was a manual screenshot of a screen that was never composed to be one.

## Surface

Every pass detail screen — train, bus and movie — carries a bottom bar with two **text-only**
buttons, `Save` and `Share`. No icons: the same rule the boarding-code row already follows, and
for the same reason (these need to be the obvious thing to press, not a glyph to hunt for).

| Piece | Path |
|---|---|
| Bar chrome | `lib/shared/widgets/pass_action_bar.dart` |
| State + wiring | `lib/features/tickets/presentation/share/pass_share_actions.dart` |
| The exported card | `lib/features/tickets/presentation/share/pass_share_card.dart` |
| Capture / files / gallery | `lib/features/tickets/application/pass_share_service.dart` |
| Share text + QR rule | `lib/features/tickets/domain/pass_share_summary.dart` |

`PassActionBar` is a deliberate sibling of `_StickyCta` in `document_entry_scaffold.dart` rather
than a refactor of it — same 56pt height, 18pt radius and Inter 16/w700 — because that widget is
built around a single full-width CTA and widening its contract would complicate every document
entry screen for one caller's benefit.

The label is the progress indicator: `Save → Saving → Saved`, settling back after 1.6s. A
spinner on a two-second operation reads as a stall; a word that changes reads as a reply. Share
has a `Preparing` state but no `Shared` one — the OS sheet is its own confirmation, and a button
reading "Shared" would be a lie when the sheet was dismissed. Both buttons disable together
while either is working: they rasterise the same card, and letting the second start would put
two off-screen copies in the overlay at once.

## What the image is

The wallet **glance** face plus a code block on a fixed dark plate — not the detail screen.

The `PassInfoCard` rows on the detail screen are readable text, and they travel in the share
*message* instead, where they can be selected, searched and quoted. Burning them into pixels
would make them none of those things.

Every kind is drawn through `WalletCardCanvas` on its own design canvas and scaled to one shared
width, so a train and a movie shared into the same chat arrive the same size. That wrapper is
load-bearing for more than tidiness: the movie face sizes from its content, and handing it an
unbounded height lets a long title push it past its canvas. On screen that is a scroll; in an
export it would be an overflow banner burned into the PNG.

`useBrandColors` is forced on, so an expired pass exports as itself rather than in the drained
palette. A shared image is a record of the booking; the wallet's "this one is spent" tint is
wallet chrome.

### Movies use the title logo, not the poster

Glance density is what selects the transparent TMDB title logo over the full 2:3 one-sheet
(`_HeroBand`, and [`movie-logo-glance.md`](movie-logo-glance.md)). That was already the wallet
treatment; here it is also what keeps the exported PNG a fraction of what a one-sheet would
cost. No change to the face was needed.

## The QR rule

**A code appears only when the pass carries a `codePayload`.** When it does not, the block is
absent entirely — no placeholder, no caption, no decorative square.

`passShareCodePayload` is the single place this lives, and it never falls back to a PNR or a
booking ID. Those identify a booking; they are not what a gate scanner reads, and a QR that
scans to the wrong thing is worse at a turnstile than no QR at all.

This matters more than it looks, because the faces draw decorative code art of their own — a
hardcoded 7×7 grid in `PassCodeBlock`, a procedural `TicketQrPainter` on the movie chrome. Both
are documented as encoding nothing. A test asserts neither reaches the exported card.

The QR itself is `qr_flutter`'s `QrImageView`, pinned to black on white. A brand-tinted code
loses contrast when a phone screen is photographed by another phone, which is exactly how a
forwarded ticket gets scanned.

No API response emits `codePayload` yet, so **mock fixtures carry realistic values on their
active passes** and none on their expired ones. That keeps both paths visible in the running app
rather than only in tests.

## Capture

`PassShareService.renderPng` parks a `PassShareCard` in the root `Overlay` at `left: -10000`,
waits two frames, and captures its `RepaintBoundary`.

It has to be a real overlay entry. `Offstage` does not paint, and `toImage` over an offstage
subtree returns a **blank image rather than an error** — the kind of bug that ships because
nothing throws. `test/pass_share_card_test.dart` guards it by asserting the bytes are a real PNG
of non-trivial length.

Two frames, not one: the first lays out and paints, the second catches anything that resolved
during the first. Network art is pre-warmed before the entry is inserted, because the movie hero
is a `CachedNetworkImage` and a cold capture would export its shimmer placeholder forever. That
pre-warm swallows every failure on a timeout — offline, a blocked host, or a film with no
artwork are all normal, and the face already falls back to its `posterHint` gradient.

Capture scale is `min(3.0, 2400 / logicalHeight)`. A full 3× capture of a ~1000pt card is a
multi-megabyte PNG, and some share targets silently drop or recompress attachments past a few
megabytes.

## Files on disk

Sharing writes one plaintext PNG to the **cache** directory. This is the second such site in the
app after `AttachmentOpenService`, and it follows that class's written policy for the same
reasons: cache only, never app documents; one file at a time; bounded lifetime. A share sheet
needs a real path — it cannot take a buffer — so the tradeoff is bounded rather than avoided.

The lifetime ends at the **next share** and at **app start** (`dashboard_screen.dart`), not when
the share sheet closes. That is deliberate and it is the one place the attachment policy could
not be copied verbatim: `share` resolves on dismissal, which is not when the receiving app is
finished — a mail client can hold the `content://` URI until the draft is sent. Purging there
would yank a ticket out of a half-sent message. A share that *fails* still purges immediately,
since no receiver ever got the file.

Saving writes **no** file: `gal` takes the bytes straight to MediaStore / PHPhotoLibrary.

`Gal.requestAccess()` is called first, deliberately. `gal`'s `put*` methods *throw* on a missing
permission rather than asking for one, so without that call the first save on iOS would fail
with "no access" and the person would never actually be prompted. On Android 29+ it returns true
without showing anything.

Failures are returned as `PassShareResult` values rather than thrown. Refusing a photo permission
and dismissing a share sheet are ordinary things a person does, not exceptions.

## Platform

- `share_plus` ships its own `FileProvider` through manifest merge, so no `<provider>` is
  declared by hand.
- Android: `WRITE_EXTERNAL_STORAGE` with `maxSdkVersion="28"`. API 29+ needs no permission at
  all; `minSdk` is 26, so the 26–28 window is the only reason it is declared.
- iOS: `NSPhotoLibraryAddUsageDescription`. Saving is an *Add* operation and needs its own key —
  the existing read-framed `NSPhotoLibraryUsageDescription` does not cover it, and without it
  iOS terminates the app the moment a save is attempted.

  **This key is not in version control.** `.gitignore` excludes `/ios/` wholesale ("Android-only
  commits for now"), so the edit exists on one machine and will be absent from a fresh clone.
  Adding it is a required step whenever iOS work starts, alongside the `NSAllowsLocalNetworking`
  exception the main `CLAUDE.md` already flags.

## Not verified from a dev machine

The iOS photo-library prompt and save, and the Android 26–28 `WRITE_EXTERNAL_STORAGE` path.
