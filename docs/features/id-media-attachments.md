# ID media attachments — build spec

Branch: `feature/id-media-attachments` · Issue: [#11](https://github.com/navadeepnaidu7/Docket-App/issues/11)

Status: **spec** — implementation delegated to `agy`, reviewed in Claude Code.

---

## 1. What this is

Let a saved ID card carry copies of the original document: up to **3 images + 1 PDF**.
They live in the space above the existing long-press "Remove ID Card?" action sheet — the
dimmed overlay that today shows nothing but the card behind a scrim.

Two ways in:

- **From the scan** — the ID scanner already captures a photo (`IdScanResult.capturedImagePath`).
  On save, that original is offered as the first attachment.
- **Manually** — the `+` tile in the attachment tray opens the system picker (photos or files).

Nothing here goes to a server. IDs are local-first and stay that way.

---

## 2. The interaction, screen by screen

Entry point is unchanged: **long-press an ID card** in the wallet carousel
(`ids_tab.dart` → `onDeleteId` → `dashboard_screen.dart:_showDeleteIdDialog`).

The overlay gains a tray above the action sheet. The card stays visible behind the scrim
exactly as it does today.

### 2.1 Empty state (mockup frame 1)

```
        You can add images or PDFs          ← hint caption
   ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
   │              +                │        ← dashed tile, accent-tinted fill,
   │        add image/pdf          │          sits over the card's position
   └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
   ┌───────────────────────────────┐
   │        Remove ID Card?        │        ← existing CupertinoActionSheet,
   │            Remove             │          unchanged
   │            Cancel             │
   └───────────────────────────────┘
```

No counter, no thumbnail strip, no swipe hint — there is nothing to swipe.

### 2.2 Populated state (mockup frame 2, and the tall render)

```
        You can add images or PDFs
   ┌───────────────────────────────┐
   │                               │
   │      hero preview (contain)   │        ← current attachment, large
   │                               │
   └───────────────────────────────┘
              1 of 2                        ← counter, only when count > 1
      [thumb] [thumb] [ + ]                 ← strip; + hidden once both
           Swipe to see more                  limits are reached
   ┌───────────────────────────────┐
   │        Remove ID Card?  …     │
```

- Horizontal **swipe** on the hero moves between attachments; the strip's selection follows.
- Tapping a thumbnail jumps the hero to it.
- The active thumbnail carries the dashed accent ring seen in the mockups; inactive ones sit
  plain and slightly desaturated.
- A **PDF** renders as its first page in both hero and thumb, with a small `PDF` badge
  (mockup frame 4).

### 2.3 Removing an attachment

Not in the mockups, but the feature is incomplete without it. **Long-press a thumbnail** →
small confirm popup → removes that attachment and its file. Deliberately long-press, not a
delete badge: the tray is already inside a destructive sheet and stray `x` buttons next to
"Remove" invite the wrong tap.

---

## 3. Architecture decisions

### 3.1 Attachment bytes go to the filesystem, not secure storage — **required**

Today every image in a document record is base64 inside the secure store
(`IdDocument.qrImageBase64`, sometimes `imagePath`). That must not be extended here.

`SecureDocumentStore` writes one JSON array per key through `flutter_secure_storage`. On
Android that is an encrypted value in SharedPreferences; on iOS it is a Keychain item.
Three phone photos plus a PDF is roughly **6–15 MB of base64**. Consequences:

- Every `readList('saved_id_documents')` would decrypt and JSON-parse that on startup.
- The 10.x `migrateOnAlgorithmChange` re-encryption would have to rewrite all of it —
  the exact path CLAUDE.md warns is most likely to throw, and where a throw now marks the
  key unreadable and blocks all future writes.
- Keychain items are not sized for multi-megabyte payloads.

**Therefore:** bytes go to app-private storage; only metadata goes in the record.

```
<app documents>/id_attachments/<idDocumentId>/<attachmentId>.<ext>
```

Both platforms sandbox this directory to the app. It is excluded from backup on Android
(`android:allowBackup` review below) and gets `NSFileProtectionComplete` on iOS.

### 3.1a Bytes are AES-encrypted — **decided**

Sandboxing alone is a weaker posture than the ID records these files belong to, which are
already encrypted. So each attachment is encrypted on write:

```
key:      256-bit, generated once, stored in flutter_secure_storage
          under 'attachment_key_v1' with kDocketAndroidOptions
cipher:   AES-GCM (authenticated — a truncated or tampered file fails loudly
          rather than rendering garbage)
on disk:  <app documents>/id_attachments/<docId>/<attachmentId>.enc
          layout: [12-byte nonce][ciphertext][16-byte tag]
```

Rules that follow from this:

- **Encrypt and decrypt off the UI isolate** (`compute`) — a 2 MB image is well past the
  frame budget. CLAUDE.md already requires this for heavy buffer work.
- **Decrypted bytes never touch disk.** Previews render from `Uint8List` in memory
  (`Image.memory`, `PdfDocument.openData`). Writing a plaintext temp file to hand to another
  app would defeat the whole decision — see §3.1b.
- Hold decrypted bytes in a small **per-session LRU cache** (cap ~4 entries) keyed by
  attachment id, so paging back and forth in the tray does not re-decrypt each time. Clear
  it when the sheet closes.
- The key is generated lazily on first attachment and **never rotated** in v1.
- Key loss means attachments are unreadable — the same risk profile the secure store already
  carries for ID records themselves. Do **not** add a "reset on failure" path: a decrypt
  failure surfaces as a broken-attachment placeholder, never as a silent delete. This mirrors
  why `resetOnError: false` is pinned in `secure_document_store.dart`.
- `attachment_key_v1` must be **read through the same unreadable-key interlock** as document
  records: if the key read throws, refuse to write new attachments rather than generating a
  fresh key over the top of files encrypted with the old one.

### 3.1b PDFs render in-app, not via an external viewer — **decided**

The fallback of "tap the PDF icon, let the device's viewer open it" needs a plaintext file at
a path another app can read, i.e. decrypted bytes written to a shared cache directory, where
they persist until the OS reaps them. That hands away exactly what §3.1a protects.

`pdfx` exposes `PdfDocument.openData(Uint8List)`, so it renders straight from the decrypted
buffer with no file involved. That is the primary path.

If `pdfx` cannot be made to build against `minSdk 26` / the pinned ABI filters, the fallback
is **not** the external viewer — it is a static PDF icon tile with the filename and page
count, and no open action. Flag it in review rather than quietly reaching for a temp file.

### 3.2 Metadata on the record, files reconciled against it

`IdDocument` gains `attachments: List<IdAttachment>`. The record is the source of truth;
files are addressed by id. A file with no metadata row is an orphan and is swept (§8).

### 3.3 Limits are enforced in the controller

Max 3 images, max 1 PDF, independently. The widget disables the `+` tile; the controller
rejects over-limit adds regardless of caller. Business logic does not live in widgets
(CLAUDE.md).

### 3.4 The overlay becomes a custom route, not `showCupertinoModalPopup`

`showCupertinoModalPopup` slides its entire child up from the bottom. With a tray attached,
the whole composition would fly up together — wrong for the "pop up" feel the issue asks for,
where the tray should bloom in place over the dimmed card.

Replace it with a `PageRouteBuilder(opaque: false, barrierColor: …)`, mirroring the existing
`showIdCardFullImage` in `id_wallet_shared.dart:358`. Then:

- scrim fades in,
- the action sheet slides up from the bottom (matching Cupertino timing),
- the tray fades + scales from `0.94` with a short stagger after the scrim.

The action sheet itself stays a real `CupertinoActionSheet` so its buttons, dividers and
haptics are untouched.

---

## 4. Data model

New file: `lib/features/ids/domain/id_attachment.dart`

```dart
enum IdAttachmentKind { image, pdf }

class IdAttachment {
  final String id;              // generated, also the filename stem
  final IdAttachmentKind kind;
  final String fileName;        // "<id>.jpg" — relative, never absolute
  final int sizeBytes;
  final DateTime addedAt;
  final String source;          // 'scan' | 'picker' — for future provenance UI
}
```

- `fileName` is **relative**. Absolute paths break across iOS reinstalls, where the app
  container UUID changes on every install; a stored absolute path silently stops resolving.
- `toMap` / `fromMap` / `copyWith`, matching the hand-written style of `id_document.dart`
  (no codegen anywhere in this repo).

`IdDocument` changes:

- add `final List<IdAttachment> attachments;` defaulting to `const []`,
- thread through the constructor, `.empty`, `copyWith`, `toMap`,
- **`fromMap` must treat a missing `attachments` key as `const []`** — every record already
  on disk lacks it. Round-trip and back-compat both covered by tests (§10).

---

## 5. Storage layer

New file: `lib/core/storage/attachment_store.dart`

```dart
Future<Directory> _dirFor(String docId);
Future<IdAttachment> save({required String docId, required File source, required IdAttachmentKind kind});
Future<File> resolve(String docId, IdAttachment a);
Future<void> delete(String docId, IdAttachment a);
Future<void> deleteAllFor(String docId);
Future<void> sweepOrphans(Iterable<IdDocument> live);
```

Rules:

- **Copy, never move.** The picker hands back a file in a cache dir the OS may reap; the
  scanner's capture is also temporary.
- **Downscale images on write** — long edge 2048 px, JPEG q85. A 12 MP phone photo is ~4 MB
  and gains nothing as a document copy. Do it **off the UI isolate** (`compute`) — CLAUDE.md.
- Writes are serialised through a future chain, same shape as the `_saveQueue` in
  `passportListProvider`, so a fast double-add cannot interleave.
- `sweepOrphans` runs once at dashboard start, not on every render.

---

## 6. State

`idListProvider` (`lib/features/ids/application/id_list_provider.dart`) gains:

```dart
Future<AttachResult> addAttachment(String docId, File file, IdAttachmentKind kind);
Future<void> removeAttachment(String docId, String attachmentId);
```

Both write the file first, then update the record, then persist — so a persist failure never
leaves a metadata row pointing at nothing. `AttachResult` carries the reject reason
(`limitReached`, `unsupportedType`, `tooLarge`, `ioError`) so the UI can show a precise
message instead of a generic failure.

The tray reads the document from `idListProvider` and rebuilds; it holds **no** attachment
state of its own beyond the current page index.

---

## 7. UI file map

```
lib/features/ids/presentation/attachments/
  id_attachment_tray.dart          tray shell: caption, hero, counter, strip, hint
  attachment_hero_pager.dart       PageView over attachments; swipe + scale falloff
  attachment_thumb_strip.dart      thumbs + dashed "+" tile, active ring
  attachment_add_tile.dart         dashed placeholder, both empty and strip variants
  attachment_preview.dart          renders image or PDF page 1 for a given attachment
  id_attachment_sheet.dart         the route: scrim + tray + CupertinoActionSheet
```

`dashboard_screen.dart:_showDeleteIdDialog` shrinks to a call into
`showIdAttachmentSheet(context, doc, onRemove: …)`. The remove/trash/wallet-order logic in
its `onPressed` moves across **unchanged** — that block already handles
`updateOrderOnItemRemoved`, which CLAUDE.md flags as easy to drop.

Styling comes from `AppTheme` tokens only: `radiusCard` (20) for the hero, `radiusControl`
(10) for thumbs, `accentOf(brightness)` for the dashed stroke and `+` glyph,
`tertiaryLabel` for the hint lines. No raw hex.

**Typography is the app's own.** The mockups' handwritten lettering and saturated purple are
placeholder art from an image generator — they are not the design direction. Both hint lines
use the existing theme's caption style, and the dashed tile takes its tint from
`accentOf(brightness)` (warm gold in light, amber in dark), not the mockup's purple. The
mockups are authoritative for **layout and flow**, not for colour or type.

### Geometry, derived from the mockup

Mockup is 853 px wide against a ~393 pt viewport, so scale ≈ 0.46.

| Element | Size |
|---|---|
| Hero | full width − 40 pt gutters, height 216 pt, `BoxFit.contain` |
| Counter | 13 pt, `tertiaryLabel`, 12 pt below hero |
| Thumb | 54 pt tall, ID-1 aspect (≈ 86 pt wide), 12 pt gaps |
| `+` tile | 54 × 56 pt, 1.5 pt dashed stroke, 6 pt dash / 5 pt gap |
| Swipe hint | 13 pt, 14 pt below the strip |
| Tray → action sheet | 24 pt clearance |

The tray is vertically centred in the space between the status bar and the action sheet,
and must survive a small screen: if free height drops below ~300 pt, drop the hero to 160 pt
and hide the swipe hint before anything overflows. Portrait-only, so no landscape case.

---

## 8. Lifecycle — where attachments must follow the ID

This is the part that rots quietly if missed. Every path that moves or destroys an
`IdDocument` needs a decision:

| Path | Behaviour |
|---|---|
| Long-press → Remove (`moveToTrash`) | Files **stay**. Trash is restorable; deleting bytes here makes restore lossy. |
| Restore from trash | Metadata comes back with the record; files are already in place. |
| Permanent delete / empty trash | `deleteAllFor(docId)`. |
| Archive (`spaceArchiveProvider`) | Files stay — archive is not deletion. |
| App start | `sweepOrphans` over live + trashed ids, so a crash mid-write cannot strand bytes forever. |

`trash_provider.dart` currently serialises the item to JSON; since `attachments` is part of
`toMap`, trashed records carry their metadata for free. Verify the round-trip in a test.

---

## 9. Dependencies and platform

Add to `pubspec.yaml`:

| Package | Why |
|---|---|
| `path_provider` | app documents dir — the repo has no such dependency today |
| `file_picker` | PDF picking, and images on the same sheet |
| `image_picker` | photo-library path; Android 13+ photo picker needs no runtime permission |
| `pdfx` | renders PDF page 1 to a bitmap for both thumb and hero, from bytes |
| `cryptography` | AES-GCM for §3.1a; pure Dart, so it runs inside `compute` unchanged |
| `cryptography_flutter` | optional — routes AES-GCM to platform hardware. Add only if profiling shows the pure-Dart path stutters. |

`pdfx` is the pick over `flutter_pdfview` because the mockup needs a **thumbnail**, which a
webview-style viewer cannot produce. Confirm it builds against `minSdk 26` and does not
re-add an `x86_64` slice — `defaultConfig.ndk.abiFilters` pins armeabi-v7a + arm64-v8a and
CLAUDE.md warns plugin AARs can widen it.

Platform work:

- **Android** — no new runtime permissions if the photo picker is used. Check
  `android:allowBackup`; document copies should not ride into a cloud backup.
- **iOS** — `NSPhotoLibraryUsageDescription` in `Info.plist` (absent today), and set
  `NSFileProtectionComplete` on the attachments directory.
- **R8** — if `pdfx` resolves anything reflectively it needs keep rules in
  `android/app/proguard-rules.pro`. Verify against a **release** build, not just debug.

---

## 10. Tests

Pure-logic first, matching the existing suite's shape:

- `id_attachment_model_test.dart` — JSON round-trip; a record written **without**
  `attachments` decodes to `const []`; unknown `kind` falls back safely.
- `id_attachment_limits_test.dart` — 3 images + 1 PDF accepted; the 4th image and the 2nd
  PDF are rejected with the right `AttachResult`; mixed order does not confuse the counts.
- `attachment_store_test.dart` — save/resolve/delete against a temp dir; `deleteAllFor`
  clears the folder; `sweepOrphans` removes an unreferenced file and **keeps** a referenced
  one.
- `id_attachment_tray_test.dart` — widget test: empty state shows only the add tile;
  2 attachments show counter "1 of 2" and hide nothing; at 3 images + 1 PDF the `+` tile is
  gone.
- Extend `secure_document_store_test.dart` only if the record shape assertion there breaks.

`flutter analyze` clean and the whole suite green before review.

---

## 11. Motion and feel

The issue's language is "pop up effect," "focus is on the current image." Concretely:

- Long-press already fires `HapticService.longPress()`; keep it.
- Tray entrance: 220 ms fade + scale 0.94 → 1.0, `smooth_curves.dart` easing, starting
  ~60 ms after the scrim so the card visibly dims *first*.
- Hero paging: the off-centre page scales to 0.92 and drops to 60 % opacity, so the current
  document is unambiguously the focus. `HapticService.select()` on page settle.
- Add tile press: reuse `BounceTap` — every other tappable in the app does.
- Attachment added: `HapticService.success()` and the new thumb fades into the strip; no
  toast, no snackbar. The app doesn't use them.
- Reduced-motion: the transitions are short and non-essential; honour
  `MediaQuery.disableAnimations` by cutting straight to the end state.

---

## 12. Out of scope

- Attachments on **passports** and **passes**. The issue says IDs; the tray is built
  generic enough to extend later, but wiring those is a separate branch.
- OCR or any parsing of attached files. They are copies, nothing more.
- Sharing/exporting an attachment out of the app.
- Any server sync. IDs are local-first.

---

## 13. Decisions — resolved

1. **Encryption at rest** — AES-GCM, key in `flutter_secure_storage`. See §3.1a.
2. **Hint typography** — **the mockup lettering is placeholder art, not a design direction.**
   Both hint lines use the app's own theme typography and design language. No new font
   family enters the warm-up path.
3. **PDF depth** — rendered in-app from decrypted bytes via `pdfx`. No external-viewer
   hand-off, because it would require writing plaintext outside the sandbox (§3.1b).

---

## 14. Delegation plan

Coding goes to `agy` in phases, each reviewed here before the next starts. Phases are
ordered so every one compiles and tests on its own.

| Phase | Scope | Gate |
|---|---|---|
| 1 | Model + store: `id_attachment.dart`, `IdDocument` fields, `attachment_store.dart`, deps | unit tests green, `flutter analyze` clean |
| 2 | Providers: `addAttachment` / `removeAttachment`, limits, lifecycle hooks | limits + lifecycle tests green |
| 3 | Tray UI: the six widgets under `presentation/attachments/`, empty + populated states | widget test green, matches §7 geometry |
| 4 | Route swap in `dashboard_screen.dart`, motion pass | manual run on device |
| 5 | Scan-flow hand-off, platform config, release-build check | release APK installs **over** an old build and old IDs still read |

Phase 5's gate is the one that matters most: per CLAUDE.md, secure-storage regressions only
show up when installing over an existing build, never on a clean install.
