# CLAUDE.md — docket_app

Guidance for Claude Code when working in this repository.

## What this is

**Docket** (formerly "SlickPort" / `passport_app`) is a Flutter iOS/Android digital wallet for
personal documents: passports, national IDs (Aadhaar, PAN), and passes (train tickets, movie
tickets). It is **local-first** — passport/ID records never leave the device — with a
**server-backed passes wallet** (train + movie) that is still behind a dev flag.

Sibling repo: `../docket_server` (Go backend: AI ticket extraction, train PNR sync, push).
The two repos are developed together; the shared contract lives in `docs/api/passes.md`.

## Commands

```bash
flutter pub get
flutter run                      # debug, mock passes on
flutter analyze
flutter test                     # whole suite; runs in ~10s

# point at a real backend
flutter run \
  --dart-define=USE_MOCK_PASSES=false \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080   # Android emulator → host

flutter build apk --release
```

Targets: Dart SDK `^3.11.5`, Android `minSdk 26` (NFC needs hardware), iOS 13+.
Android `applicationId` / `namespace` is still `com.example.docket`.

## Architecture

Feature-first Clean Architecture. Each feature under `lib/features/<name>/` splits into
`domain/` (models, validation), `application/` (Riverpod controllers/services), and
`presentation/` (widgets, screens). Cross-feature code lives in `lib/core/` and `lib/shared/`.

```
main.dart          → prefs + theme warm-up, portrait lock, ProviderScope
app.dart           → DocketApp: hand-driven ThemeData.lerp light↔dark transition
lib/core/
  dev/             DevConfig (dart-defines) + DevFlags (runtime prefs)
  storage/         SecureDocumentStore — encrypted list storage + legacy prefs migration
  theme/           AppTheme (cream/navy light, graphite/amber dark), theme_provider
  wallet/          wallet ordering, filters, layout constants, palette, backdrop tilt
  motion/ haptics/ sound/ assets/ validation/
lib/features/
  dashboard/       shell: wallet carousel, tabs, settings (2.3k lines), trash, archive
  passport/        PassportProfile model + entry screens
  ids/             IdDocument model, per-brand card widgets (Aadhaar, PAN), scanner
  tickets/         passes wallet: domain models, mock/remote repos, train + movie faces
  nfc/             MethodChannel client for passport chip reads
  mrz_scanner/     ML Kit camera OCR + MRZ parsing
  onboarding/      first-run flow ("fuse" wizard)
lib/shared/widgets/  studio_* design system pieces, sheets, buttons, card shine border
```

### State management

Riverpod 2 only — no other DI. Controllers are `StateNotifier`/`AsyncNotifier`;
widgets observe, they don't own logic. Persistence goes through the controller, not the widget.

- `passportListProvider` / `idListProvider` — `StateNotifier` lists backed by
  `SecureDocumentStore` (`saved_passports`, `saved_id_documents`). Saves are serialized through a
  `_saveQueue` future chain so concurrent writes can't interleave.
- `passListProvider` (`AsyncNotifier`) + `passRepositoryProvider` — the passes wallet.
- `walletOrderProvider`, `trashProvider`, `spaceArchiveProvider`, `walletFilterProvider` —
  dashboard organisation state.
- `authSessionProvider` — **mock only** today (`AuthSession.demo` driven by a dev flag).

### Passes: mock vs remote

`passRepositoryProvider` picks `MockPassRepository` (fixtures) or `RemotePassRepository`
based on `devFlagsProvider`. The remote path uses `http` against `PassApiPaths` (`GET /v1/passes`).
The Passes-tab `+` can submit a train PNR (`POST /tickets`) or a photo/PDF
(`POST /tickets/extract`). Auth is still not Google Sign-In: debug builds exchange
`DEV_AUTH_ID_TOKEN` (or Settings → Developer → Dev auth token) at `POST /v1/auth/google`.
See `docs/features/pass-input.md`. Full OAuth is still open
(`../docket_server/docs/flutter_auth_integration.md`).

### Movie posters

Posters come from the backend's TMDB image proxy (`/img/poster/{size}/{file}`), rendered with
`cached_network_image` — `Image.network` has no disk cache, so every cold start would
re-download. `MoviePass.resolvedPosterUrl` is **nullable**: "no poster" is a normal state (TMDB
has no match, or the async lookup has not finished) and the `posterHint` gradient is the
fallback. Never substitute another film's artwork.

`posterAsset` is client-only — the server never sends it. It survives so fixtures can pin a
bundled image; with no `--dart-define=MOCK_POSTER_ORIGIN`, mock passes render the gradient.

Pass JSON models are hand-written (`ticket_models.dart`, `movie_pass_models.dart`,
`pass_catalog.dart`) — no codegen. `WalletPassItem` is a sealed class over
`TrainPassItem | MoviePassItem`, discriminated by `kind`. Parsers accept both the
`{kind, train: {...}}` envelope and a bare nested object. Unknown movie `brand` → `universal`.

### Native integration

- **NFC passport chip**: `MethodChannel('com.docket/nfc_passport')` →
  `android/app/src/main/kotlin/com/example/docket/MainActivity.kt`, which uses JMRTD +
  scuba + JP2Decoder to do BAC and read DG1/DG2/DG11/DG12. BAC key = passport number +
  DOB + expiry (both `YYMMDD`). `jmrtd-src/` and `jmrtd-sources.jar` are local-only
  reference sources — gitignored, not build inputs, and absent from a fresh clone.
  iOS side is not implemented.
- **OCR/MRZ**: Google ML Kit. Text recognition is **bundled** in the APK, so MRZ scanning
  works offline on a fresh install. Face detection and barcode scanning use the Play
  Services variants — models download on first use, and `id_scanner_service.dart` degrades
  silently (skips face crop / QR) until they arrive.

## Conventions

- **No emojis** in source, logs, exceptions, or console output. Never log document data,
  MRZ contents, or chip payloads.
- Keep widgets small and `const` where possible; business logic stays in providers.
- Design system: reuse `lib/shared/widgets/studio_*` and `AppTheme` tokens
  (`radiusCard`, `radiusSheet`, `background(brightness)`, …) rather than raw colors.
- The app is **portrait-only** — locked at runtime in `main.dart` and in both native manifests.
- Theme switching is animated by hand in `app.dart` (`ThemeData.lerp` + a veil overlay);
  `MaterialApp.themeMode` is deliberately pinned to `light` and `themeAnimationDuration` to zero.
  Don't "fix" that by reintroducing `themeMode: mode`.
- `AppTheme.lightTheme` / `darkTheme` are cached because `GoogleFonts` resolution is expensive;
  they're warmed in `main()` and font loading is capped at 900 ms so offline start still works.
- Heavy image/buffer parsing belongs off the UI isolate.

## Working style

### Read the graph before reading files

This repo is indexed by CodeGraph (`.codegraph/`). Reach for it **before** grep/Read when
locating code or tracing a flow — it returns verbatim source plus callers and blast radius in
one round trip.

The MCP tool is named **`mcp__codegraph__codegraph_explore`**. If it is deferred, load it with
that *exact* name (`ToolSearch("select:mcp__codegraph__codegraph_explore")`) — the bare name
`codegraph_explore` matches nothing, and the `codegraph` shell binary is not on PATH on this
machine. A session already lost the tool to that and fell back to a grep/Read loop for the
whole run.

### Delegating code to `agy`

Bulk code can go to the Antigravity CLI (`agy`), but two rules are load-bearing:

1. **Tell it explicitly to write code only and run no commands.** Left to itself it will start
   `flutter analyze`, then emit "waiting for analyze to finish" until it times out, producing
   nothing. With the instruction it reports promptly.
2. **Its self-report is not evidence.** It has reported "zero deviations" while shipping
   invented Flutter identifiers that do not compile, and a fixed-size widget that collapsed at
   thumbnail scale. Every claim needs independent verification.

Split the work by **how a mistake fails**, not by difficulty:

| Failure is | Example | Who writes it |
|---|---|---|
| Loud — compiler or a test catches it | widgets, test bodies, boilerplate | `agy` |
| Silent — wrong code still looks right | crypto, storage lifecycle, caching, perf | you |

Every serious bug delegated work has produced here was in the silent column: a key that
regenerated itself over encrypted data, a preview that re-decrypted every frame, an orphan
sweep that would have deleted trashed users' files. No test would have caught any of them.

A precise brief costs ~800 words, so below roughly 200 lines of output it is cheaper to write
the code than to delegate it. **Read everything that comes back** — if that is too much to
read, the task was too big to delegate.

### Verification is yours

`flutter analyze` and `flutter test` results only count when you ran them. Report what the
output actually said, and name what is still unverified — on-device behaviour and the
install-over-an-existing-build check cannot be done from a dev machine.

### Plans belong on disk

Write feature plans into `docs/features/<name>.md` before building, not only into the session.
A previous session planned this feature entirely in conversation, was lost, and left a branch
with zero commits and nothing to resume from.

## Docs

| Doc | Contents |
|-----|----------|
| `docs/current_state.md` | **Start here** — what is built, what is stubbed, verification log, backend checklist |
| `README.md` | Product overview, feature list, stack, setup |
| `docs/api/passes.md` | Passes API contract — field-by-field train/movie shapes |
| `docs/dev-flags.md` | Mock vs remote switching, dart-defines, Settings → Developer |
| `docs/features/id-media-attachments.md` | ID attachments (#11) — storage/encryption decisions, tray geometry, lifecycle |
| `PLAN.md` | Original phased build plan (historical; predates tickets/passes) |
| `../docket_server/docs/architecture.md` | Backend design, pass taxonomy |

## Gotchas

- `PLAN.md` still uses the old "SlickPort" name and predates the tickets/passes work; treat it as
  history, not spec. The package is `docket`; the directory is `docket_app`.
- Passes tab shows a purple **MOCK** chip when mock mode is on; the Developer section only
  exists in debug/profile (or with `--dart-define=FORCE_DEV_MENU=true`).
- `SecureDocumentStore.readList` silently migrates legacy `SharedPreferences` string lists
  into secure storage on first read and deletes the plaintext copy — keep that path intact.
- `flutter_secure_storage` is held at `>=10.3.1 <11.0.0` on purpose; it is not a stale
  constraint. v11 deleted the `RSA_ECB_PKCS1Padding` / `AES_CBC_PKCS7Padding` ciphers that
  9.2.4 wrote with, so a 9 -> 11 jump makes existing passport, ID, wallet-order and trash
  records unreadable — `readList` then reports an empty list and the next save overwrites
  them. The 10.x line re-encrypts that data on first read (`kDocketAndroidOptions` sets
  `migrateOnAlgorithmChange` + `migrateWithBackup`). Only move to v11 once shipped installs
  have run a 10.x build, and test it by installing **over** an old build, never a clean one.
- `kDocketAndroidOptions` also sets `resetOnError: false`, and it must stay that way. On
  Android the plugin implements `resetOnError` as "any exception on any operation calls
  `deleteAll()` and returns success" — the Dart side never sees the error. It defaulted to
  false in 9.2.4 and true from 10.x, so leaving it implicit silently arms a full wipe of every
  passport and ID. `SecureDocumentStore` pairs this with a write interlock: a key whose read
  threw is marked unreadable and `writeList` refuses it, so an empty list can never be saved
  over records that are still on disk.
- `reconcileWalletOrder` must be called whenever items are added/removed, or the persisted
  carousel order drifts and unknown ids sort to the end.
- ID **attachments** never go in secure storage — only their metadata does. Bytes are AES-GCM
  files under `<app documents>/id_attachments/<docId>/`, keyed from `attachment_key_v1`.
  Putting 6-15 MB of base64 back into `saved_id_documents` would drag it through every
  `readList` and through the 10.x re-encryption pass. `AttachmentStore` carries the same
  refuse-don't-regenerate interlock as `SecureDocumentStore`: a key that fails to read, fails
  to decode, **or is the wrong length** blocks further writes rather than minting a new key
  over files encrypted with the old one.
- `sweepAttachmentOrphans` deletes files no record points at, and is dangerous by nature. It
  must not run until both `idListProvider` and `trashProvider` report `loaded`, and must skip
  entirely when either key is `SecureDocumentStore.isUnreadable` — both lists start empty and
  a failed decrypt also surfaces as empty, so an ungated sweep deletes every attachment on the
  device. Trashed records count as live: they still own their files, and restore must stay
  lossless.
- `terminals/` and `build/` are scratch/output, not source. `tool/` holds the launcher-icon
  generator (Python) and `tool/design_src/` holds design masters (the full-resolution
  `emblem_of_india.svg`, logo shape variants) that are versioned but never bundled.
- Release builds run R8 (`isMinifyEnabled`/`isShrinkResources`). `android/app/proguard-rules.pro`
  keeps the JMRTD/scuba/BouncyCastle/JP2 stack whole because it resolves reflectively —
  test an NFC read against a real passport after touching those rules.
- `abiFilters` pins armeabi-v7a + arm64-v8a on the **release build type** (not `defaultConfig`,
  which AGP unions with what `FlutterPlugin.kt` re-adds at apply time). Flutter's
  `--target-platform` only constrains the engine; without the filter, plugin AARs re-add an
  x86_64 slice.
  **Currently not taking effect** — a release APK built 10 Aug 2026 contains `lib/x86_64/`
  (engine, ML Kit OCR, `libopenjpeg.so`), roughly a third of a 93 MB APK. `build.gradle.kts`
  is unchanged, so this is an environment/toolchain regression, not a config edit. Verify the
  ABI list in the APK before trusting the size of a release build.
- `android.permission.INTERNET` is now declared explicitly in the **main** manifest. It used to
  reach release builds only because ML Kit / Play Services manifests merged it in — too fragile
  once network images became a core feature. Don't remove it.
- `res/xml/network_security_config.xml` permits cleartext for `10.0.2.2` / `localhost` only, so
  `--dart-define=API_BASE_URL=http://10.0.2.2:8080` works on the emulator. Without it Android 9+
  blocks the request **silently**. Don't widen it to the base config.
- iOS `Info.plist` has no ATS exception, so plain-`http://` local backends are blocked on the
  simulator. Production is HTTPS; add `NSAllowsLocalNetworking` when iOS development starts.
