# Current State of the App

What is built and verified in `docket_app`.

**Snapshot:** 19 Aug 2026 · **v0.1.0-alpha** (build 1) · `master` @ `5c2c05c` · `flutter analyze` 5 info-level lints, no warnings/errors · last measured release APK **93.0 MB** on 10 Aug (x86_64 slice still present); no release APK in the tree today.

> **Journey (§1.4) is a planned feature, not a shipped one.** A working v1 exists
> on the unmerged branch `worktree-journey-atlas` (PR #35, draft) and was parked
> on 19 Aug: it works, but it does not yet reach the product vision. It is not in
> the app on `master`, and its ~60KB of bundled assets are not in any build made
> from `master`. The 501-test / analyze-clean / APK-builds figures in §1.4 and
> §3.1b were measured **on that branch**, not here.

The app is **feature-complete on local documents and can connect to a remote server for server-backed passes**. `RemotePassRepository` fetches passes from `GET /v1/passes`, the API client handles session refresh on `401`, and debug builds can exchange a developer token against `POST /v1/auth/google` to obtain access and refresh tokens. Full Google Sign-In integration (via `google_sign_in`) is not yet implemented.

---

## 0. Alpha readiness

This is the pickup note for a documents-first alpha. Packaging work was started and then **reverted on purpose** — stay on `com.example.docket` and debug signing until the Passes input layer exists.

### What a tester can use today (sideload / debug)

Passport, Aadhaar, PAN, ID attachments, wallet organisation, trash, archive, theming, and the mock Passes tab. Documents never leave the device. Confirmed on hardware for attachments (10 Aug).

### What a tester cannot do

Add a pass to the wallet from a production backend. The Passes-tab `+` opens the input flow (train PNR / photo / PDF; bus and movie photo / PDF) but submit is refused while mock fixtures are active. `RemotePassRepository` fetches from `GET /v1/passes` when an API URL is configured. Extract (`POST /tickets/extract`) and PNR create (`POST /tickets`) work over `http` with a developer auth token (`DEV_AUTH_ID_TOKEN` or Settings → Developer → Dev auth token), exchanged for session tokens at `POST /v1/auth/google`. The API client includes a 401-refresh interceptor (`POST /v1/auth/refresh`). Full Google Sign-In integration (via `google_sign_in`) is not yet implemented.

A release build would also ship the 10 fixture passes **without** the purple MOCK chip (`DevConfig.defaultUseMockPasses` defaults to `true`; the badge is gated on `showDevMenu`, which is off in release). That is why a Play-track alpha is the wrong shape until either mocks are locked off or real data flows.

### Server (sibling repo)

`docket_server` on `hardening/deployment-readiness` @ `098ba79`, PR [#5](https://github.com/navadeepnaidu7/docket-server/pull/5) open. Containerised, deployable, poster path smoke-tested end to end. **Not hosted.** A documents-only alpha does not need it running.

### Deferred until after the Passes input layer

Explicit call on 13 Aug, do not pick these up early:

1. `applicationId` + `namespace` → `com.docket.wallet`, `MainActivity.kt` moved to `com/docket/wallet/`
2. Release `signingConfigs` from a gitignored `android/key.properties`, falling back to the debug key with a warning
3. `flutter build appbundle` + ABI verification inside the artifact
4. Play Console: privacy policy URL, data-safety answers

OAuth Android client registration needs the **final** applicationId and the SHA-1 of the cert that signs the delivered app (Play's key after first upload, not the upload key). Debug against the debug keystore is fine; do not build the production OAuth client until the rename lands.

### Hardware-only, still unverified

- NFC passport read from a **release** APK after R8
- Install over an existing build (`attachment_key_v1` + secure-storage migration)
- Trash → restore with attachments, walked in the app

### Critical path to a connected alpha

The input layer is in (`docs/features/pass-input.md`): train PNR / photo / PDF, bus and movie photo / PDF, plus `RemotePassRepository` and a 401-refresh interceptor. What is still missing is real Google Sign-In — debug builds exchange `DEV_AUTH_ID_TOKEN` (or Settings → Developer → Dev auth token) at `POST /v1/auth/google`. Local emulator:

```bash
--dart-define=USE_MOCK_PASSES=false
--dart-define=API_BASE_URL=http://10.0.2.2:8080
--dart-define=DEV_AUTH_ID_TOKEN=dev-google-token
```

(`isMockPassesActive` is `useMockPasses || apiBaseUrl.isEmpty`, so the first two defines are both required. The server must have `AUTH_DEV_BYPASS_TOKEN=dev-google-token`.)

---

## 1. Implemented

### 1.1 Shell & navigation
- First-run onboarding wizard (`features/onboarding/`, "fuse" flow); completion persists `has_seen_onboarding` in `SharedPreferences`.
- Two-tab dashboard behind a custom pill nav bar: **IDs** (index 0) and **Passes** (index 1). Nav icon styles are fixed (IDs classic, Passes vertical) — the style toggle was removed in #19.
- Portrait-locked at runtime (`main.dart`) and in both native manifests.
- Hand-driven light↔dark theme transition (`app.dart`): `ThemeData.lerp` over 620ms plus a veil overlay, so `MaterialApp.themeMode` stays pinned to `light` deliberately.
- Theme warm-up in `main()` caches `AppTheme.lightTheme`/`darkTheme` and caps `GoogleFonts.pendingFonts()` at 900ms so offline cold start still renders.

### 1.2 Documents — local-first, complete
- **Passports** (`features/passport/`): three entry paths — manual form, camera MRZ scan, and NFC chip read. `PassportProfile` records persist through `SecureDocumentStore` under `saved_passports`. The wallet card is a booklet (spec in `docs/features/passport-cover-redesign.md`): navy 2021/2024 cover on the front, cream English biodata page on the back. Ordinary vs e-passport differs by the ICAO chip mark.
- **MRZ scanning** (`features/mrz_scanner/`): ML Kit text recognition, `MrzParser` as the authoritative source for document number / DOB / expiry, plus `FullPageExtractor` regex heuristics for name, issuing country, date of issue, place of birth from the visual zone.
- **NFC e-passport** (`features/nfc/` + `MainActivity.kt`): BAC using number + DOB + expiry, reads **DG1** (MRZ), **DG2** (face image, JP2 decoded to JPEG then base64), **DG11**/**DG12** (additional personal and document details). Returns a flat map the passport draft consumes, including `photoBase64` for the card portrait.
- **ID documents** (`features/ids/`): Aadhaar and PAN, each with a bespoke card face and rendered QR (`qr_flutter`). `IdScannerService` combines barcode, text, and face detection; records persist under `saved_id_documents`.
- **ID media attachments** (`features/ids/presentation/attachments/`, issue #11): up to 3 images + 1 PDF per ID, reached by long-pressing the card — the tray occupies the dimmed space above the existing remove sheet. Add from the system picker, swipe between attachments, long-press a thumbnail to remove. The scanner's captured original is attached automatically on save. Bytes are **AES-GCM files** under `<app documents>/id_attachments/<docId>/`, keyed from `attachment_key_v1`; only metadata rides in `saved_id_documents`. PDFs render page one in-app from decrypted bytes via `pdfx` — nothing plaintext is ever written to disk. Design decisions in `docs/features/id-media-attachments.md`.
- **Pass share** (`features/tickets/presentation/share/`, `application/pass_share_service.dart`): every pass detail screen — train, bus and movie — carries a text-only `Save` / `Share` bar. Both render the wallet glance face plus a QR to a PNG off-screen via an `Overlay` + `RepaintBoundary`; Share hands it to the OS sheet with the booking details as text, Save writes it to the photo library through `gal`. The QR is drawn **only** when the pass carries a `codePayload` and never falls back to a PNR or booking ID. Movies export the title logo rather than the one-sheet, which is what glance density already selects. Design decisions in `docs/features/pass-share.md`.
- **Wallet organisation**: drag-to-reorder in Manage Cards (`ReorderableListView`), persisted order reconciled on add/remove, trash with restore/permanent delete, category filter, and a "Space" archive screen with counts, top category, milestones and peak month.

### 1.3 Passes — UI complete, data mocked
- Sealed `WalletPassItem` (`TrainPassItem | MoviePassItem`) with hand-written JSON models; parsers accept both the `{kind, train|movie: {...}}` envelope and a bare nested object.
- Train: wallet card, detail screen, ticket face with passengers, halts, live-status label and progress.
- **Train pass face rebuilt to the Figma export** (issue #20, spec in `docs/features/train-pass-redesign.md`): warm blush card on its own 366×630 canvas (`WalletCardMetrics.trainCanvas`), Instrument Serif station codes over Geist, two-column data grid, decorative code block. Absolute baseline layout — positions in `TrainPassMetrics` came off the export's path coordinates, not a screenshot. The same face now serves both the wallet card and the detail screen.
  - The old footer lockup is now a **dynamic status band**: a blurred operator wordmark bled off the bottom edge, with delay / platform / countdown / on-time messages cross-fading over it. Message selection is a pure function (`resolveTrainBandMessages`) over the pass and an injected clock, so it is unit-tested rather than eyeballed.
  - Backed by two new optional wire fields, `runState` and `delayMinutes` (see `docs/api/passes.md`). `liveStatusLabel` stays free text for the Live tab. A payload omitting both renders exactly as before.
  - Active train fixtures now date themselves relative to launch, so the countdown stays demonstrable instead of rotting into "Journey complete". Expired fixtures keep fixed dates — the archive tests assert their order.
- Movie: brand chrome for `bookMyShow` / `district` / `universal` (unknown brand → universal), ticket face, and a gate-code screen.
- **Movie posters come from the backend's TMDB image proxy**, rendered with `cached_network_image` (disk-cached; the proxy serves `immutable`). The three bundled poster JPEGs and the hardcoded Wikipedia URL table are gone. `MoviePass.resolvedPosterUrl` is nullable — no poster means the `posterHint` gradient, which is now painted permanently beneath the image rather than swapped in on error. A shimmer covers the download.
  - Fixed while here: the hero band's brand guard covered every `MoviePassBrand` value, so its `else` branch was unreachable and `_BrandChip` / `_StatusPill` — which had no other call site — never rendered on any movie pass. Both now show, over a scrim so they stay legible on bright art.
  - **The two densities size the poster differently on purpose.** Detail frames it at `MovieTicketMetrics.posterAspect` (2:3, TMDB's one-sheet) so the art is shown whole; the glance card keeps its fixed-height crop, because a full one-sheet there would push the ticket's actual information off a card that has to read at a glance. `test/movie_poster_ratio_test.dart` pins both so the difference is not "tidied up" into a single value.
- Fixtures: **6 train passes and 4 movie passes** in `mock_pass_fixtures.dart`. Movie fixtures point at the image proxy via `--dart-define=MOCK_POSTER_ORIGIN=http://10.0.2.2:8080`; with no origin set they render the gradient.
- Source selection via `devFlagsProvider` → `MockPassRepository` or `RemotePassRepository`; a purple **MOCK** chip shows in the Passes tab while mock mode is active.

### 1.4 Journey — the memory atlas (globe) · PLANNED, parked on a branch

> **Not on `master`.** Kept in this section rather than under §2 because it is
> built and green, not stubbed — but nothing described here is in the app today.
> Branch `worktree-journey-atlas`, PR #35 (draft), parked 19 Aug 2026.
> **`docs/features/journey.md` §10 is the pickup note** — read it before
> anything else.

Fourth dashboard view alongside Home / Manage / Trash, reached from the header's
view picker. Spec, revision log and resume guide in `docs/features/journey.md`.

- **A globe, not a map.** Four discrete levels — World, Country, Region, City.
  No free zoom: tapping a cluster flies the camera to it. Great-circle slerp for
  the heading plus an altitude arc that scales with ground covered, so a hop
  between two Bengaluru cinemas barely lifts while India to London pulls right
  back. All ~20 motion constants live in `journey_motion.dart`.
- **Land is a dot field, not polygons.** `assets/journey/atlas_v1.bin` (53KB)
  holds 12,125 land dots in three LOD bands plus 65 simplified India state rings,
  generated by `tool/generate_journey_atlas.py` from Natural Earth (public
  domain). Coastline polygons are consumed offline to decide which sphere points
  are land and then **discarded** — nothing polygonal ships. Land coverage
  measures 28.9% against Earth's actual 29.2%. Decoded off the UI isolate via
  `compute`, CRC-checked, with a wireframe fallback if the asset is unreadable.
- **Places come from a bundled table.** `assets/journey/places_v1.json`, 41
  hand-curated rows behind a `PlaceResolver` interface; a server-backed resolver
  would implement the same interface. Resolution is exact code, then exact name,
  then alias — **never fuzzy**. Country and region rows are deliberately not
  name-searchable so an address ending in a state name cannot resolve a whole
  state.
- **Every memory is an ordered list of stops.** One resolved stop draws a pin,
  two or more draw a route. A train whose destination will not resolve degrades
  to a point with no branch anywhere. Memories that resolve to nothing are
  **never dropped** — they surface as a "N memories without a place" row.
- **Coverage is pinned by test.** 100% of the place strings in
  `mock_pass_fixtures.dart` resolve — six trains, their halts, eleven cinemas —
  including the two known traps: `mock_t1` uses `BLR` (an airport IATA code) as a
  train endpoint, and one halt reads `Hyderabad Decan`.
- **Flights are mocked.** `PassKind` is still `{train, movie, bus}`; six
  `FlightItinerary` fixtures give the world level real arcs. When a real flight
  pass lands, the sealed switch in `buildJourneyIndex` stops compiling and one
  case is added — see "Flights are mocked" in `docs/features/journey.md`.
- Rendering is two `RepaintBoundary` layers. The whole planet costs five
  `drawRawPoints` calls (depth-bucketed) with no allocation in the hot loop.
- Replaced and deleted: `space_archive_screen.dart` (747 lines, unreachable) and
  `dot_globe_painter.dart` (a procedural noise sphere, not projectable).

**Unverified:** on-device frame timing (never measured — measure at *city*
level, where the full dot field is enabled; world level will look fine and prove
nothing), the feel of the camera flights on real hardware, and the globe's
full-bleed framing behind the header. No golden tests. The teaser page on
`user_card_detail_screen.dart` was not built.

### 1.5 Settings
Appearance (light / dark / device / scheduled with a custom time picker), haptics, experimental toggles (card shine border, card category filter), Account section, About / developer links (`url_launcher`), and a Developer section (debug/profile only, or `--dart-define=FORCE_DEV_MENU=true`) exposing mock passes, mock sign-in, card gradient scheme, API base URL, reload passes, and reset flags. Nav icon styles are no longer a setting (#19).

### 1.6 Design & sensory layer
3D card tilt and drag reactions, custom-drawn shine/holographic borders, `studio_*` shared widget set, entry-reveal motion curves, haptic service, sound triggers, and an easter-egg drawer.

### 1.7 Platform
Android `minSdk 26`, `applicationId`/`namespace` `com.example.docket`, NFC via `MethodChannel('com.docket/nfc_passport')` backed by JMRTD + scuba + BouncyCastle + JP2Decoder.

- `android.permission.INTERNET` is now declared in the **main** manifest. It previously reached release builds only because ML Kit / Play Services manifests merged it in — verified present in the packaged release manifest after this change.
- `res/xml/network_security_config.xml` permits cleartext for `10.0.2.2` / `localhost` / `127.0.0.1` only, so a local backend works on the emulator. Android 9+ blocks cleartext **silently** otherwise. Release traffic stays TLS-only.
- iOS has no ATS exception; plain-`http://` local backends are blocked on the simulator. Production is HTTPS, and iOS is not a current target.

### 1.8 Release build — size-optimised
Landed in `a3fe742` + `a66c039`. Universal release APK measured at **59.0 MB**, down from 90.3 MB.

> **Regressed as of 10 Aug 2026.** A release build on that date produced a
> **93.0 MB** APK still containing `lib/x86_64/` (engine, ML Kit OCR,
> `libopenjpeg.so`). `build.gradle.kts` is unchanged and the filter is still
> written as described below, so this is an environment or toolchain change
> rather than a config edit — most likely the Flutter Gradle plugin's
> evaluation order no longer matching what the filter depends on. Check the ABI
> list inside the APK before trusting a release size. Tracked in `CLAUDE.md`.

- R8 runs on release (`isMinifyEnabled` + `isShrinkResources`) with `android/app/proguard-rules.pro` keeping the reflection-heavy JMRTD / scuba / BouncyCastle / JP2 stack and ML Kit whole.
- ABI filtering pins `armeabi-v7a` + `arm64-v8a`, dropping a 33 MB `x86_64` slice. **This must sit on the `release` build type and call `abiFilters.clear()` first** — `FlutterPlugin.kt` clears the build type's filters and re-adds `DEFAULT_PLATFORMS` (arm32, arm64, **x86_64**) at `apply()` time, and AGP unions that with `defaultConfig`, so a `defaultConfig`-only filter is silently a no-op. Debug keeps x86_64 so emulators still work.
- ML Kit **face detection** and **barcode scanning** are excluded in favour of the `play-services-mlkit-*` variants, so their models are fetched by Play Services rather than bundled. **Text recognition stays bundled** (`assets/mlkit-google-ocr-models`, 1.3 MB + an 11.6 MB native pipeline per ABI) so MRZ/OCR works offline on a fresh install. `AndroidManifest.xml` declares `com.google.mlkit.vision.DEPENDENCIES = face,barcode` to prefetch at install.
- Assets are listed file-by-file in `pubspec.yaml` rather than by directory, so an unreferenced file cannot silently ship. Design-master SVGs live in `tool/design_src/` and are deliberately not bundled.

**Not yet verified:** an NFC passport read against real hardware after R8. The ProGuard keeps are reasoned, not runtime-proven — the JMRTD/scuba stack resolves providers and LDS handlers reflectively, so this is the one change that could fail only at runtime.

**Remaining headroom:** the 59 MB figure is a *universal* APK carrying both ABIs. `flutter build appbundle` lets Play deliver one ABI per device, roughly halving the download without further code changes.

---

## 2. Not implemented / stubbed

| Area | State |
|------|-------|
| **Remote passes** | `RemotePassRepository` calls `GET /v1/passes` when an API URL is set. Requires a session (via `DEV_AUTH_ID_TOKEN` or Settings → Developer → Dev auth token, exchanged at `POST /v1/auth/google`). |
| **Auth** | `authSessionProvider` returns a hardcoded `AuthSession.demo` when the `mockSignedIn` dev flag is on, `signedOut` otherwise. Session tokens (access + refresh) are stored in `flutter_secure_storage` under `docket_api_session_v1` and refreshed on `401` via `POST /v1/auth/refresh`. No `google_sign_in` dependency for full OAuth flow yet. |
| **Extract upload** | Wired: train PNR (`POST /tickets`) + photo/PDF (`POST /tickets/extract`), bus photo/PDF, movie photo/PDF. Submit is refused while mock fixtures are active. Full Google Sign-In is still missing. |
| **Push** | No FCM dependency and no `POST /v1/devices` registration, although the server's Phase D outbox is ready. |
| **iOS NFC** | Not implemented; `MainActivity.kt` is Android-only. |
| **Search** | `README.md` lists search among wallet features; there is no search UI in the codebase. |
| **Pass share on iOS** | Implemented and analyzed, but the photo-library permission prompt and save are unverified — no iOS toolchain in this repo's flow. The Android 26-28 `WRITE_EXTERNAL_STORAGE` path is likewise unexercised; the emulators in use are newer, where MediaStore needs no permission. |
| **Release signing** | `buildTypes.release` still uses the debug signing config (`TODO` in `build.gradle.kts`). |

---

## 3. Verification log

### 3.1 Static analysis — clean
```bash
flutter analyze
```
4 issues as of 25 Aug 2026, all `info` level and all pre-existing: one
`deprecated_member_use` (`settings_screen.dart:135`) and three
`use_null_aware_elements` (`chip_payload.dart:75-79`). No warnings or errors.

### 3.1b Journey globe — 19 Aug 2026 (on the parked branch, not `master`)

Verified on this machine, on `worktree-journey-atlas`:

- `flutter analyze` clean (the same 5 pre-existing infos; none in Journey).
- **501 tests pass**, 89 of them Journey's. Notable ones, because they cover
  things nothing visual would catch:
  - the fast batch projection agrees with the readable reference to a hundredth
    of a pixel over 4,000 random points
  - the decoded atlas is probed against real geography — India, Brazil, Nigeria,
    Australia, Siberia, Antarctica carry dots; mid-Pacific and mid-Atlantic do
    not; the Caspian is correctly subtracted as a polygon hole
  - a corrupted byte, a truncated file and a bad magic number each fail the
    decode rather than producing a plausible wrong planet
  - **100% of place strings in `mock_pass_fixtures.dart` resolve**, including
    `BLR` used as a train endpoint and the `Hyderabad Decan` misspelling
  - tap-to-descend is walked end to end, world through country and back
- `flutter build apk --debug` succeeds, so the two new bundled assets are wired
  correctly in `pubspec.yaml`.

**One bug this caught late, recorded because the class of it matters.** The
camera flight never ran: `_flyTo` took its origin by re-reading the navigator,
which already held the destination, so the guard returned early and every
descent snapped. The level changed, the globe redrew, the tap test passed and
analyze was clean — the only symptom was on screen. The fix extracts
`flightOriginFor` into the domain with three tests. Silent-failure work belongs
in pure functions where it can be pinned.

**Still unverified — needs a real device:**

- Frame timing. Never measured. Measure at **city** level; world level enables
  ~1,700 dots, will look fine, and proves nothing.
- The feel of the camera flights. The ~20 constants in `journey_motion.dart`
  were reasoned, not tuned on hardware, and no test can judge motion.
- The globe's full-bleed framing behind the dashboard header.

### 3.2 Tests

```bash
flutter test
# 473 tests, All tests passed! (~65s)   # 25 Aug 2026
```

| Suite | Covers | Result |
|-------|--------|--------|
| `test/passes_json_test.dart` | Train/movie JSON round-trips over fixtures, envelope parsing, brand fallback, poster URL resolution (null / blank / trimmed / round-tripped) and fixture poster hygiene | pass |
| `test/wallet_card_responsive_test.dart` | Card layout across device sizes down to 320×568, incl. short viewports (split screen) and `WalletCardMetrics.resolve` | pass |
| `test/movie_poster_ratio_test.dart` | Detail hero is a 2:3 one-sheet and derives its height from the width it is given; glance keeps its fixed-height crop; a pass with no poster still gets the one-sheet frame so the layout does not jump when art arrives | pass |
| `test/movie_hero_band_test.dart` | Hero band: brand chip + status pill present for all three brands (the dead-branch regression), gradient fallback with no network request when no poster, `CachedNetworkImage` when there is one, bundled asset still wins | pass |
| `test/train_pass_face_test.dart` | Station header anchoring (origin left, destination right, long names still flush to the content edge) and the connector rule's span + masking. Pins a silent layout bug: `RenderBaseline` lays its child out loose and pins it flush left, so `width` + `textAlign: right` did nothing and the destination column rendered from the wrong edge with no overflow reported | pass |
| `test/train_status_band_test.dart` | Status-band message resolution: cancelled suppresses everything, arrived/expired collapse to one line, delay wording and ordering, `delayMinutes: 0` is not a delay, "On time" only when claimed, platform normalisation and hand-off to `nextHalt`, countdown thresholds and the boarding grace window, `departAt` preferred over display strings, unparseable date yields no countdown. Widget: cycling, no timer for a single message | pass |
| `test/app_version_test.dart` | `kAppVersion` in Settings matches `pubspec.yaml` (the two are hand-synced — nothing reads the real version at runtime), and the pubspec keeps a `+<build>` suffix so AGP has a `versionCode` | pass |
| `test/pass_activity_date_test.dart` | Display and ISO date parsing, incl. rejection of overflow calendar dates (`2024-02-31`) that `DateTime.parse` silently rolls into the next month | pass |
| `test/pass_history_folders_test.dart` / `test/archive_layout_test.dart` | Archive foldering and layout | pass |
| `test/account_profile_provider_test.dart` | Profile persistence against a stubbed store: hydration, rejected read / write / delete, rollback, and write serialization | pass |
| `test/widget_test.dart` | Boot through onboarding into the dashboard shell | pass |
| `test/attachment_store_test.dart` | Encrypted attachment save/resolve round-trip, delete, `deleteAllFor`, orphan sweep keeping referenced files, and the key interlock — including a stored key of the wrong length being refused rather than replaced | pass |
| `test/id_attachment_limits_test.dart` | 3 images + 1 PDF counted independently, over-limit and oversize rejection, extension-to-kind mapping | pass |
| `test/id_attachment_model_test.dart` / `test/id_document_attachments_test.dart` | Attachment JSON round-trip and back-compat: a record written **without** the `attachments` key, and a malformed non-list value, both decode to an empty list | pass |
| `test/id_attachment_tray_test.dart` | Tray states: empty, counter at 2 attachments, add tile hidden at capacity, long-press remove callback, PDF placeholder | pass |
| `test/secure_document_store_test.dart` | Unreadable-key interlock: a failed read marks the key and `writeList` refuses rather than saving empty over live records | pass |
| `test/nfc_failure_test.dart` | Every platform channel code maps to a distinct, actionable `NfcFailure` (no collapsed "try again") | pass |
| `test/bac_key_format_test.dart` / `test/chip_payload_test.dart` / `test/document_validators_test.dart` | BAC date/number formatting, DG1/DG11/DG12 field mapping, passport-number and BAC-triple validation | pass |
| `test/passport_prompt_flow_test.dart` / `test/prompt_flow_controller_test.dart` | Prompted entry routes (e-passport vs regular) and controller gating | pass |
| `test/passport_profile_migration_test.dart` | v1 `imagePath`/`photoBase64` split on read | pass |

The whole suite terminates — the old `widget_test.dart` hang (unbounded `pumpAndSettle()` against
continuously animating screens) is fixed.

There is still **no on-device NFC test** and no MRZ-image fixture suite. The native JMRTD
bridge and ML Kit scanner are covered only by the failure/format unit tests above.

### 3.3 On-device — ID media attachments (10 Aug 2026)

Confirmed by the maintainer on hardware, which is the only place these paths are real: the
tray appears on long-press, images and PDFs can both be added from the picker, and the
scanner's captured original is attached to the new record. Functionally complete and in use.

Two things that still have not been exercised, so they should not be read as covered:

- **Install over an existing build.** This branch adds a new secure-storage key
  (`attachment_key_v1`) beside the existing passport and ID records. Per the gotcha in
  `CLAUDE.md`, secure-storage regressions only ever surface on an upgrade install, never on a
  clean one. Worth doing once before this reaches anyone else's device.
- **Restore from trash with attachments.** Trashed records deliberately keep their files so
  restore stays lossless; the logic is unit-tested but the round trip has not been walked
  through in the app.

Visual refinements are tracked separately and do not affect the above.

---

## 4. Backend integration checklist

The server (`../docket_server`, `master` plus open PR [#5](https://github.com/navadeepnaidu7/docket-server/pull/5) on `hardening/deployment-readiness`) is ready and waiting for deployment. Auth, passes, extract, and posters are on `master`; the PR is deploy/container hardening only. What remains to fully connect:

1. Add `google_sign_in` for production Google OAuth — replace the debug `DEV_AUTH_ID_TOKEN` developer-token exchange with a real Google Sign-In flow that obtains the `idToken` for `POST /v1/auth/google`. (`http` and `flutter_secure_storage` are already in place; `RemotePassRepository`, session storage, refresh interceptor, and extract upload are implemented.)
2. Map the membership card from `/v1/me`: `joinedAt` → `MMMM y`, `displayName`, `#publicId`.
3. Optional next: FCM token registration via `POST /v1/devices` (multipart extract upload with `429` handling is already implemented).

Full guide: `../docket_server/docs/flutter_auth_integration.md`. Contract: [`api/passes.md`](api/passes.md). Switching: [`dev-flags.md`](dev-flags.md).

---

## 5. Known issues

- `PLAN.md` still uses the old "SlickPort" name and predates the tickets/passes work — history, not spec. (`README.md` was corrected on 2 Aug 2026: absolute `passport_app` links, the PACE claim, and a non-existent search feature.)
- `applicationId` is still the scaffold default `com.example.docket`.
- `terminals/`, `build/`, `jmrtd-src/` and `jmrtd-sources.jar` are scratch, output, and vendored reference material — not build inputs.
