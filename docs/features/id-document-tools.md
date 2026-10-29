# ID document tools

Status: implemented locally and core flows checked on Android, 29 October 2026.

User scope: implement the first three ID-wallet recommendations: usable document
details, easier capture/import, and precise sharing. Preserve existing wallet card
faces, the tap-to-flip interaction, passes and other threads' working changes.

## Design and behaviour

- Add a visible Open document action to the active ID in the wallet. Details use
  Docket's existing Geist typography, neutral grouped surfaces and native controls.
- Show original files together with readable, individually copyable fields.
  Support editing without recreating the ID or losing attachment references.
- View images with zoom and PDFs with all pages inside the app. Password-protected
  PDFs are unlocked locally; passwords remain in memory for that viewing session.
- Add from camera, gallery, files, and Android's Share to Docket target. Imported
  content always goes through a type choice and review before persistence.
- Keep front/back/supporting labels on attachments, compatible with old metadata.
- Provide four-corner crop/perspective adjustment and image quality guidance.
  Originals remain unchanged; OCR operates on a temporary working image.
- Review extracted fields, retain missing-field hints, validate before saving,
  and offer to open an existing matching ID instead of silently duplicating it.
- Sharing offers selected text fields, an exact original, or a redacted copy.
  Redactions are flattened into newly rasterised output, never just PDF overlays.
  Optional purpose/date watermark applies to the copy. Preview the exact output
  bytes/text before opening the OS share sheet. Original bytes are never changed.

## Persistence and privacy

- Await durable record writes before completion feedback. Serialise operations
  against the latest state; do not let a failed write publish a successful state.
- Write attachment bytes before metadata and await metadata before reporting
  success. Delete files only after metadata removal succeeds. Preserve storage
  read/key interlocks and startup orphan-sweep gating.
- Initial record + selected originals commit together. Failed staging preserves
  the draft and offers retry. Successful saves update wallet order afterward.
- Keep import workspaces and outgoing exports in app cache, with bounded sizes,
  session cleanup and a startup sweep for stale temporary files. No ID data in
  logs, filenames exposed to other apps, analytics, or network requests.
- Keep existing image/PDF count and 25 MB per-file limits. Bound PDF page count,
  image decode dimensions and raster sizes to avoid memory exhaustion.
- Security/app-lock, backup/cloud sync, extra ID types and issuer verification are
  outside this slice. A scanned copy is never presented as issuer verification.

## Verification

Respect the user's instruction not to run automated tests. Run focused static
analysis and an Android build after source changes, then use the connected phone
if available for details, editing, import, PDF password, preview and sharing checks.
Use synthetic documents for destructive and sharing checks. Record actual results
and platform limitations here; do not infer runtime success from compilation.

The existing pdfx renderer documents password support as web-only, so the new
reader/import flow needs a mobile-capable local PDF engine. Native Android share
handling must support cold starts and already-running activity delivery, reject
unsupported/oversized content, and copy content URIs on a worker thread.

## Implementation checkpoint

- ID details are reachable through Open document in the ID wallet. Existing card
  artwork and tap-to-flip remain. Fields copy individually, editing preserves the
  record ID, and originals have zoom, PDF page reading, and explicit next/previous
  controls so zoom gestures cannot make another original inaccessible.
- Entry drafts belong to their route, not the old global draft provider. Opening
  an existing duplicate cannot overwrite the new document's draft identity.
- New and edited documents await durable writes. Attachment creation/removal is
  serialised; failed/unknown metadata commits retain ciphertext until the gated
  startup reconciliation can safely determine ownership.
- Camera, Photos, Files and Android incoming shares enter the same review flow.
  Four-corner adjustment and rotation affect the OCR working copy only. Imported
  files are size/header checked and stored byte-for-byte as encrypted originals.
  Scanned values are marked Check; conflicting scanned numbers get an explicit
  choice, and duplicate stored numbers offer Open existing.
- Password-protected PDFs use pdfrx locally. Passwords are session-only. The older
  pdfx attachment thumbnail implementation remains compatible and untouched.
- Sharing supports selected text fields (Aadhaar last-four masking by default),
  unchanged original files, and manually redacted/watermarked copies. All PDF pages
  are preserved in flattened copies, within the documented 20-page / 35 MB output
  limits. Preview renders the exact output bytes subsequently shared.
- Android outgoing ID files use a dedicated, non-exported FileProvider restricted
  to `cache/id_exports`, avoiding an extra share_plus file copy. Files are purged
  after an hour while running, or by a stale-file sweep after restart. Android
  incoming URI copies are owned by a token and released after review; abandoned
  incoming/import sessions are swept after 24 hours.
- New dependencies: image 4.12.0, pdf 3.13.1, pdfrx 2.4.8 and its PDFium engine.
  Secure-storage versions, key formats, legacy migration and encryption stay intact.

Platform scope: the incoming Share to Docket target is implemented on Android.
In-app import/view/edit and outgoing sharing use cross-platform Flutter libraries;
an iOS incoming share extension is not included. iOS compilation/runtime remains
unverified from this Windows workspace.

Validation:

- Focused `dart analyze` of the app integration, ID feature, wallet entry and shared
  review component: No issues found.
- Final ARM64 Android debug APK built successfully and installed on the connected
  Motorola Edge 30, including the gesture and Android activity refinements.
  APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check` passed. Automated tests were not run, as requested.
- Android incoming PNG import, crop/review, OCR, durable save, duplicate detection,
  opening the existing document, and editing with originals retained all passed
  using a synthetic PAN record.
- A password-protected two-page PDF was added to that record, unlocked locally,
  and read with both pages visible in the in-app viewer.
- Selected-field preview contained only the chosen fields. Original PNG sharing
  produced bytes with the same SHA-256 as the imported source. Redacted PNG and
  two-page PDF previews opened the Android chooser without selecting a recipient.
  The flattened PDF retained both pages and had no extractable text layer.
- Phone checks exposed an early image-descriptor disposal crash and a missing
  Material ancestor for grouped ListTiles. Both were fixed and the import/detail
  flows were then verified in the installed build. Redaction/crop gestures now use
  the initial touch position, with crop handles inset from Android's back edge.
- Android uses a single-task activity so incoming shares reuse the wallet engine
  rather than creating a second session with potentially stale document state.
- Removed the exact synthetic wallet record, its encrypted originals, public
  import fixtures and generated export files from the phone. Restored the original
  60-second screen timeout. Local synthetic review artifacts remain under ignored
  `build/id-tools-review`.
- After the final installation, the wallet reloaded its original seven documents
  without the synthetic record. Open document on an existing PAN opens the details
  screen with editing, sharing and originals controls. The terminal debug session
  is connected for hot reload.
- Live camera capture and iOS compilation/runtime were not manually verified in
  this pass. Gallery uses the platform picker; the checked image path was Android
  incoming sharing, and the checked PDF path was the Android file picker.
