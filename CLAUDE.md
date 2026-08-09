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
based on `devFlagsProvider`. **`RemotePassRepository` is still a stub** — it returns empty
when disabled and throws `UnimplementedError` when enabled with a base URL. There is no HTTP
client dependency in `pubspec.yaml` yet.

Wiring it to the backend is the main open task and means: add `http`/`dio`, implement
`fetchPasses`/`fetchPassById` against `PassApiPaths`, and replace the mock
`authSessionProvider` with real Google Sign-In (`../docket_server/docs/flutter_auth_integration.md`
is the pickup guide: `POST /v1/auth/google` → access JWT + refresh, tokens in secure storage,
401 → single refresh + retry).

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

## Docs

| Doc | Contents |
|-----|----------|
| `docs/current_state.md` | **Start here** — what is built, what is stubbed, verification log, backend checklist |
| `README.md` | Product overview, feature list, stack, setup |
| `docs/api/passes.md` | Passes API contract — field-by-field train/movie shapes |
| `docs/dev-flags.md` | Mock vs remote switching, dart-defines, Settings → Developer |
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
- `reconcileWalletOrder` must be called whenever items are added/removed, or the persisted
  carousel order drifts and unknown ids sort to the end.
- `terminals/` and `build/` are scratch/output, not source. `tool/` holds the launcher-icon
  generator (Python) and `tool/design_src/` holds design masters (the full-resolution
  `emblem_of_india.svg`, logo shape variants) that are versioned but never bundled.
- Release builds run R8 (`isMinifyEnabled`/`isShrinkResources`). `android/app/proguard-rules.pro`
  keeps the JMRTD/scuba/BouncyCastle/JP2 stack whole because it resolves reflectively —
  test an NFC read against a real passport after touching those rules.
- `defaultConfig.ndk.abiFilters` pins armeabi-v7a + arm64-v8a. Flutter's `--target-platform`
  only constrains the engine; without the filter, plugin AARs re-add an x86_64 slice.
- `android.permission.INTERNET` is now declared explicitly in the **main** manifest. It used to
  reach release builds only because ML Kit / Play Services manifests merged it in — too fragile
  once network images became a core feature. Don't remove it.
- `res/xml/network_security_config.xml` permits cleartext for `10.0.2.2` / `localhost` only, so
  `--dart-define=API_BASE_URL=http://10.0.2.2:8080` works on the emulator. Without it Android 9+
  blocks the request **silently**. Don't widen it to the base config.
- iOS `Info.plist` has no ATS exception, so plain-`http://` local backends are blocked on the
  simulator. Production is HTTPS; add `NSAllowsLocalNetworking` when iOS development starts.
