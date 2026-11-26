# Docket contributor guide

Docket is a Flutter document wallet: local passports, IDs and payment cards, plus
server-backed train, movie, bus and flight passes. Package: `docket`.

## Start with the task

Read the [README task map](README.md#task-map), then the relevant source and tests.
[Current state](docs/current_state.md) records capability and verification limits;
feature docs describe contracts or proposals, not automatically shipped behavior.
Current source and the user's latest direction take precedence over historical notes.
Do not read every feature document for an unrelated change.

## Commands

```sh
flutter pub get
flutter run                                  # debug defaults to mock passes
flutter analyze --no-pub lib test tool
flutter test --no-pub test/auth_session_test.dart  # choose the affected suites
flutter test --no-pub                         # full suite; duration varies
python tool/check_docs.py
flutter build apk --release --split-per-abi  # install app-arm64-v8a-release.apk
```

Dart constraint: `^3.11.5`; Android minimum SDK: 26. Android is the versioned platform.
API origin, Google client IDs and mock/release behavior: [dev flags](docs/dev-flags.md).
The optional sibling `../docket_server` owns backend deployment and OAuth configuration.
Do not assume that its files, a local backend, or ignored platform scaffolds exist.

## Source ownership

- `main.dart` / `app.dart`: entry, complete-wallet launch barrier, onboarding, theme transition.
- `core/`: shared storage, theme, motion, device feedback and wallet primitives.
- `features/<feature>/`: domain models, application providers/services, data adapters
  where needed, and presentation. This is feature-first organization, not strict layer isolation.
- `features/auth/application/`: app-wide account session and Google sign-in. The HTTP
  client/session adapters are currently in `features/tickets/data/`.
- `features/dashboard/presentation/settings/`: independent Settings components;
  `settings_screen.dart` composes them.
- `shared/`: reusable widgets and prompted-entry infrastructure.

Use Riverpod 2 (`StateNotifier` / `AsyncNotifier`). Keep persistence and reusable
business operations in controllers/services. Split by responsibility; keep closely
related private widgets together. Preserve the existing Flutter design and reuse
`AppTheme`, `AppFonts` and the relevant shared widget variants; see [AGENTS.md](AGENTS.md).

## Navigation and working style

- When `.codegraph/` exists, call `mcp__codegraph__codegraph_explore` first for indexed
  code. Use exact symbols. If lookup misses, returns unrelated code, or reports stale
  entries, read the missing source directly; do not spend a session retrying the index.
- Preserve existing uncommitted work. Keep changes scoped and review every delegated diff.
- For substantial new behavior, record scope and decisions in its existing feature doc
  before implementing; create a doc only for a distinct durable contract. Routine fixes
  need no standalone plan file. Mark proposals, implemented contracts and historical notes.
- Run the affected checks yourself. Report failures, timeouts and device-only gaps honestly.
  Do not replace goldens solely to obtain a passing suite.
- No sensitive document, MRZ, chip, account-token or payment-card data in logs. No emojis
  in source, logs or exceptions. Move heavy image/record parsing off the UI isolate.

## Invariants to preserve

- **Document storage:** `SecureDocumentStore` migrates legacy preferences only after a
  successful secure write, and blocks writes after unreadable/corrupt records. Keep
  `kDocketAndroidOptions.resetOnError: false`. Secure storage stays on 10.x until existing
  9.x installs have migrated; a jump to 11 can strand encrypted documents.
- **Attachments:** only metadata goes in secure record lists; encrypted bytes live in
  `AttachmentStore`. Never regenerate an unreadable/invalid key over existing files.
  Orphan cleanup waits for ID and trash hydration, skips unreadable stores, and includes
  trashed documents as live owners. See [attachment contract](docs/features/id-media-attachments.md).
- **Codes:** render only genuine payloads in their original symbology via `PassCodeView`.
  An absent code stays absent on faces, code screens and shared PNGs; never invent one
  from a PNR/booking reference. See [code contract](docs/features/ticket-code-extraction.md).
- **Artwork:** a missing movie poster or airline logo is normal. Keep its fallback;
  never substitute another film's artwork. Logo cache belongs in tickets/data.
- **Wallet:** preserve document identity and saved order on mutations, trash and restore.
- **Startup/theme:** fonts are bundled; runtime Google Fonts fetching is disabled.
  Returning users prepare local wallet records/order and first artwork before `runApp`.
  Keep network work outside this barrier. `app.dart` owns the hand-driven theme lerp;
  do not replace it with MaterialApp's automatic theme animation.
- **Platform:** portrait lock, main-manifest INTERNET permission and local-only cleartext
  exceptions are intentional. R8 must keep the reflective NFC stack. NFC reads, upgrade
  installs and release ABI contents require device/artifact checks beyond unit tests.
