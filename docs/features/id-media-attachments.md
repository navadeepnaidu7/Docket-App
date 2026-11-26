# ID attachments: storage and lifecycle

Status: implemented; maintained storage contract. Source reviewed 23 November 2026.
UI/import/reader and redaction behavior lives in [ID document tools](id-document-tools.md).
This replaces the original build/delegation plan for issue #11.

## Owners and scope

- `lib/core/storage/attachment_store.dart`: encrypted files, key interlock, mutation queue,
  decrypted-byte cache, deletion and orphan reconciliation.
- `lib/features/ids/domain/id_attachment.dart` and `attachment_limits.dart`: metadata and limits.
- `lib/features/ids/application/id_list_provider.dart`: durable document/attachment changes.
- `attachment_providers.dart`: shared store and startup sweep gates.
- `attachment_open_service.dart`: deliberate external-viewer plaintext window.
- `lib/features/ids/presentation/attachments/`: long-press tray, paging, thumbnails and route.

Attachments belong to IDs and remain local. Passport/pass attachment support is a separate
feature; payment-card scans use their own `CardScanStore` and key.

## Record and file contract

Only `IdAttachment` metadata goes in the encrypted document record: id, kind, relative
fileName, sizeBytes, addedAt, source and label. Missing attachment metadata in older records
decodes to an empty list. Preserve IDs and metadata through edit, trash and restore.

```text
<app documents>/id_attachments/<documentId>/<attachmentId>.enc
```

Use relative filenames, never an absolute container path: iOS container paths can change.
The `.enc` file holds ciphertext; image/PDF kind is metadata. Multi-megabyte originals must
not be base64-embedded in `saved_id_documents`, where every record read and secure-storage
migration would decrypt and parse them again.

Picker/scanner inputs are temporary: copy their bytes, never move the source. Current ID
import preserves original bytes; crop/rotation/OCR processing uses a separate working copy.
The old 2048px/JPEG-q85 downscale proposal is not an implemented attachment-store guarantee.

Limits are enforced in the controller independently of UI affordances: **3 images + 1 PDF**,
with a **25 MiB** maximum per file (`kMaxAttachmentSizeBytes`). Reject unsupported types,
over-limit and oversized input with an actionable `AttachFailure`.

## Encryption and key safety

- AES-GCM with a 256-bit key stored under `attachment_key_v1` using
  `kDocketAndroidOptions`. On disk: **12-byte nonce + ciphertext + 16-byte tag**.
- Encrypt/decrypt through worker isolates; authenticated decryption rejects corrupt or
  truncated files. Surface unavailable/broken originals without silently deleting them.
- Generate the key lazily for a new store. A read failure, invalid encoding, wrong-length
  key, or missing key over existing encrypted files blocks writes/key creation. Never mint
  a replacement key over existing ciphertext; v1 does not rotate keys.
- Keep `resetOnError: false` and the secure-record unreadable interlock. Secure-storage
  upgrades need an install-over-existing-data test; a clean install cannot exercise migration.
- The shared mutation queue serializes writes and deletes across store instances. A failed
  operation must not permanently poison later queued operations.
- Previews use `resolveBytes`, with an LRU of at most four decrypted entries keyed by both
  document and attachment IDs. Invalidate the relevant entries on deletion and clear the
  preview cache when the viewing session ends. Do not cache document screenshots.

## Durable mutations and cleanup

Creation writes ciphertext first, then awaits the metadata commit before reporting success.
If that commit fails or its outcome is unknown, retain ciphertext: a later successful record
read lets the gated sweep determine ownership. If the document disappeared during the write,
the just-created unreferenced file can be removed. Attachment removal persists metadata
removal before deleting its ciphertext; failed metadata commits must not destroy live bytes.

| Operation | File lifetime |
|---|---|
| Move ID to trash | Keep files; trashed metadata still owns them |
| Restore / archive | Preserve files and metadata |
| Permanent delete / empty trash | Delete only the removed document's files |
| Startup orphan reconciliation | Remove only files proven unreferenced by hydrated stores |

`sweepAttachmentOrphans` waits for both ID and trash `loaded` futures, checks disposal,
and skips when either secure-record key is unreadable. Initial empty lists and failed reads
are not proof that files are orphaned. Live **and trashed** IDs count as references. Schedule
maintenance at startup, never as render-time work or as an early empty-list sweep.

## Viewing, export and platform boundaries

Image/PDF previews render from decrypted memory. `pdfx` provides tray thumbnails; the newer
reader/import flow uses `pdfrx` for full and password-protected PDFs. See the
[ID tools contract](id-document-tools.md) for labels, redacted exports and cleanup.

External opening is an explicit exception to memory-only viewing: `AttachmentOpenService`
writes one plaintext file to **cache/attachment_open**, never app documents. Purge before
another open, when the attachment sheet closes, at app start, and immediately after an open
failure. A receiving app needs a real path/content grant; do not broaden this into a bulk
plaintext export or indefinite cache. Redacted sharing has its own `cache/id_exports` policy.

The tray retains the real Cupertino destructive sheet, current theme typography, focus/paging
and reduced-motion behavior. Geometry and motion values belong to the widgets/tokens;
image-generator mock lettering and colors are not product specifications.

Android backup restrictions and scoped file grants are intentional. iOS file protection
(including the intended complete-protection policy), backup exclusions, picker permissions
and external-viewer behavior need platform configuration and device verification; ignored
iOS scaffolds are not a portable guarantee.

## Verification

Run the relevant existing suites: `attachment_store_test.dart`, `id_attachment_limits_test.dart`,
`id_attachment_model_test.dart`, `id_document_attachments_test.dart`, `id_attachment_tray_test.dart`,
`document_startup_race_test.dart` and `secure_document_store_test.dart`.

Hardware attachment picking/tray/scanner paths were checked on 10 August 2026. That historical
check does not certify later releases, upgrade migration or trash/restore. Verify those on a
device using synthetic documents; record current results in [current state](../current_state.md).
