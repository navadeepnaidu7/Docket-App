# Pass share

Exporting a pass as an image plus text, to another app or to the photo library.

## Why

A pass detail screen used to be a dead end. The only "Share ticket" affordance in the tickets
feature was a stub whose `onTap` popped the sheet and did nothing, so the only way to forward a
ticket was a manual screenshot of a screen that was never composed to be one.

## Surface

Every pass detail screen — train, bus and movie — ends with two **text-only** buttons, `Save`
and `Share`. No icons: the same rule the boarding-code row already follows, and for the same
reason (these need to be the obvious thing to press, not a glyph to hunt for).

They are the **last item in the scroll view**, not a pinned bar. Sharing is something you decide
to do after reading the pass, not the first thing the screen should offer, and a sticky plate
over the ticket face would cost vertical space on every visit for an action most visits do not
want. So `PassActionBar` carries no plate, no hairline and no safe-area inset — it scrolls away
with everything else.

| Piece | Path |
|---|---|
| Bar chrome | `lib/shared/widgets/pass_action_bar.dart` |
| State + wiring | `lib/features/tickets/presentation/share/pass_share_actions.dart` |
| The exported card | `lib/features/tickets/presentation/share/pass_share_card.dart` |
| Capture / files / gallery | `lib/features/tickets/application/pass_share_service.dart` |
| Share text + QR rule | `lib/features/tickets/domain/pass_share_summary.dart` |

It borrows `_StickyCta`'s type and metrics from `document_entry_scaffold.dart` (56pt tall, Inter
16/w700) but not its chrome, and is a sibling rather than a refactor of it: that widget is built
around a single full-width CTA and widening its contract would complicate every document entry
screen for one caller's benefit. The corner radius is 24 rather than that CTA's 18 — sitting
inline on the page, they need more shape to read as buttons and not as another grouped row.

The label is the progress indicator: `Save → Saving → Saved`, settling back after 1.6s. A
spinner on a two-second operation reads as a stall; a word that changes reads as a reply. Share
has a `Preparing` state but no `Shared` one — the OS sheet is its own confirmation, and a button
reading "Shared" would be a lie when the sheet was dismissed. Both buttons disable together
while either is working: they rasterise the same card, and letting the second start would put
two off-screen copies in the overlay at once.

## What the image is

The wallet **glance** face, a code block, and a wordmark, on a fixed dark plate — not the
detail screen. Nothing sits above the face: a header naming the app and the pass kind was tried
and cut, because a banner across the top of someone else's ticket is the app talking over the
thing being shared.

Branding closes the image instead — one big translucent "Docket", the same treatment as the
watermark at the foot of Settings. It reads as a mark on the artwork rather than a line of text
competing with the pass's own type. No version string: Settings shows one because that screen is
about the app, and a build number on a forwarded ticket is noise.

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

Its white plate hugs the code rather than spanning the card, and the human reference sits below
it on the dark ground. A small code centred in a full-width white slab reads as a mistake, and
the quiet zone a scanner needs is only a few modules — the rest was empty paper.

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

### The card supplies its own text style

`PassShareCard` installs an explicit `DefaultTextStyle` at its root, and that is load-bearing.
An Overlay entry has no `Material` above it, so it inherits the fallback style `WidgetsApp`
installs for that case: red type under a **yellow double underline**. Every `PassType` role sets
colour, size and weight but not `decoration`, so the underline inherited straight through into
the exported PNG. The style is written out in full rather than read from the theme, because the
export must not change with the viewer's light/dark setting.

The test for this pumps the card **without** a `MaterialApp` on purpose — the other card tests
wrap it in one, which supplies a sane default, and that is exactly why they did not catch it.

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

## Known wart: the train face brings its own code square

The train face prints a decorative `PassCodeBlock` as part of its design, so a shared train pass
carries that square **and** the real QR below it — two code-like marks, one of them unscannable.
The movie and bus glance faces contribute none, so only trains are affected.

Fixing it means changing the train pass face (a flag to suppress the block when it is being
exported, or dropping it from the face outright), which is a wider decision than this feature.
A test in `pass_share_card_test.dart` pins the current behaviour deliberately, so the next
person meets the fact rather than finding it in a screenshot.

## Not verified from a dev machine

The iOS photo-library prompt and save, and the Android 26–28 `WRITE_EXTERNAL_STORAGE` path.
