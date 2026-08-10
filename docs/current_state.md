# Current State of the App

What is built and verified in `docket_app`.

**Snapshot:** 2 Aug 2026 · branch `master` (head `a66c039`) · `flutter analyze` clean (4 info-level lints) · 109 tests pass, 1 suite hangs (§3.2) · release APK builds at **59.0 MB** (universal, arm32 + arm64).

The app is **feature-complete on local documents and fully mock-driven on server-backed passes**. Nothing talks to `docket_server` yet.

---

## 1. Implemented

### 1.1 Shell & navigation
- First-run onboarding wizard (`features/onboarding/`, "fuse" flow); completion persists `has_seen_onboarding` in `SharedPreferences`.
- Two-tab dashboard behind a custom pill nav bar: **IDs** (index 0) and **Passes** (index 1). Nav icon style and labels are user-configurable.
- Portrait-locked at runtime (`main.dart`) and in both native manifests.
- Hand-driven light↔dark theme transition (`app.dart`): `ThemeData.lerp` over 620ms plus a veil overlay, so `MaterialApp.themeMode` stays pinned to `light` deliberately.
- Theme warm-up in `main()` caches `AppTheme.lightTheme`/`darkTheme` and caps `GoogleFonts.pendingFonts()` at 900ms so offline cold start still renders.

### 1.2 Documents — local-first, complete
- **Passports** (`features/passport/`): three entry paths — manual form, camera MRZ scan, and NFC chip read. `PassportProfile` records persist through `SecureDocumentStore` under `saved_passports`.
- **MRZ scanning** (`features/mrz_scanner/`): ML Kit text recognition, `MrzParser` as the authoritative source for document number / DOB / expiry, plus `FullPageExtractor` regex heuristics for name, issuing country, date of issue, place of birth from the visual zone.
- **NFC e-passport** (`features/nfc/` + `MainActivity.kt`): BAC using number + DOB + expiry, reads **DG1** (MRZ), **DG2** (face image, JP2 decoded to JPEG then base64), **DG11**/**DG12** (additional personal and document details). Returns a flat map the passport draft consumes, including `photoBase64` for the card portrait.
- **ID documents** (`features/ids/`): Aadhaar and PAN, each with a bespoke card face and rendered QR (`qr_flutter`). `IdScannerService` combines barcode, text, and face detection; records persist under `saved_id_documents`.
- **ID media attachments** (`features/ids/presentation/attachments/`, issue #11): up to 3 images + 1 PDF per ID, reached by long-pressing the card — the tray occupies the dimmed space above the existing remove sheet. Add from the system picker, swipe between attachments, long-press a thumbnail to remove. The scanner's captured original is attached automatically on save. Bytes are **AES-GCM files** under `<app documents>/id_attachments/<docId>/`, keyed from `attachment_key_v1`; only metadata rides in `saved_id_documents`. PDFs render page one in-app from decrypted bytes via `pdfx` — nothing plaintext is ever written to disk. Design decisions in `docs/features/id-media-attachments.md`.
- **Wallet organisation**: drag-to-reorder in Manage Cards (`ReorderableListView`), persisted order reconciled on add/remove, trash with restore/permanent delete, category filter, and a "Space" archive screen with counts, top category, milestones and peak month.

### 1.3 Passes — UI complete, data mocked
- Sealed `WalletPassItem` (`TrainPassItem | MoviePassItem`) with hand-written JSON models; parsers accept both the `{kind, train|movie: {...}}` envelope and a bare nested object.
- Train: wallet card, detail screen, ticket face with passengers, halts, live-status label and progress.
- Movie: brand chrome for `bookMyShow` / `district` / `universal` (unknown brand → universal), ticket face, and a gate-code screen.
- **Movie posters come from the backend's TMDB image proxy**, rendered with `cached_network_image` (disk-cached; the proxy serves `immutable`). The three bundled poster JPEGs and the hardcoded Wikipedia URL table are gone. `MoviePass.resolvedPosterUrl` is nullable — no poster means the `posterHint` gradient, which is now painted permanently beneath the image rather than swapped in on error. A shimmer covers the download.
  - Fixed while here: the hero band's brand guard covered every `MoviePassBrand` value, so its `else` branch was unreachable and `_BrandChip` / `_StatusPill` — which had no other call site — never rendered on any movie pass. Both now show, over a scrim so they stay legible on bright art.
- Fixtures: **6 train passes and 4 movie passes** in `mock_pass_fixtures.dart`. Movie fixtures point at the image proxy via `--dart-define=MOCK_POSTER_ORIGIN=http://10.0.2.2:8080`; with no origin set they render the gradient.
- Source selection via `devFlagsProvider` → `MockPassRepository` or `RemotePassRepository`; a purple **MOCK** chip shows in the Passes tab while mock mode is active.

### 1.4 Settings
Appearance (light / dark / device / scheduled with a custom time picker), haptics, navigation icon style and labels, experimental toggles (card shine border, card category filter), Account section, About / developer links (`url_launcher`), and a Developer section (debug/profile only, or `--dart-define=FORCE_DEV_MENU=true`) exposing mock passes, mock sign-in, card gradient scheme, API base URL, reload passes, and reset flags.

### 1.5 Design & sensory layer
3D card tilt and drag reactions, custom-drawn shine/holographic borders, `studio_*` shared widget set, entry-reveal motion curves, haptic service, sound triggers, and an easter-egg drawer.

### 1.6 Platform
Android `minSdk 26`, `applicationId`/`namespace` `com.example.docket`, NFC via `MethodChannel('com.docket/nfc_passport')` backed by JMRTD + scuba + BouncyCastle + JP2Decoder.

- `android.permission.INTERNET` is now declared in the **main** manifest. It previously reached release builds only because ML Kit / Play Services manifests merged it in — verified present in the packaged release manifest after this change.
- `res/xml/network_security_config.xml` permits cleartext for `10.0.2.2` / `localhost` / `127.0.0.1` only, so a local backend works on the emulator. Android 9+ blocks cleartext **silently** otherwise. Release traffic stays TLS-only.
- iOS has no ATS exception; plain-`http://` local backends are blocked on the simulator. Production is HTTPS, and iOS is not a current target.

### 1.7 Release build — size-optimised
Landed in `a3fe742` + `a66c039`. Universal release APK measured at **59.0 MB**, down from 90.3 MB.

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
| **Remote passes** | `RemotePassRepository` returns empty when disabled and throws `UnimplementedError` when enabled. No `http`/`dio` dependency in `pubspec.yaml`. |
| **Auth** | `authSessionProvider` returns a hardcoded `AuthSession.demo` when the `mockSignedIn` dev flag is on, `signedOut` otherwise. No `google_sign_in` dependency, no token storage, no refresh interceptor. |
| **Extract upload** | The server's `POST /tickets/extract` has no client. Passes cannot be added from the app — only fixtures exist. |
| **Push** | No FCM dependency and no `POST /v1/devices` registration, although the server's Phase D outbox is ready. |
| **iOS NFC** | Not implemented; `MainActivity.kt` is Android-only. |
| **Search** | `README.md` lists search among wallet features; there is no search UI in the codebase. |
| **Release signing** | `buildTypes.release` still uses the debug signing config (`TODO` in `build.gradle.kts`). |

---

## 3. Verification log

### 3.1 Static analysis — clean
```bash
flutter analyze
```
3 issues, all `info` level `curly_braces_in_flow_control_structures`
(`secure_document_store.dart:36`, `id_scanner_screen.dart:128`, `mrz_scanner_screen.dart:130`). No warnings or errors.

### 3.2 Tests

```bash
flutter test
# 293 tests, All tests passed! (~18s)
```

| Suite | Covers | Result |
|-------|--------|--------|
| `test/passes_json_test.dart` | Train/movie JSON round-trips over fixtures, envelope parsing, brand fallback, poster URL resolution (null / blank / trimmed / round-tripped) and fixture poster hygiene | pass |
| `test/wallet_card_responsive_test.dart` | Card layout across device sizes down to 320×568, incl. short viewports (split screen) and `WalletCardMetrics.resolve` | pass |
| `test/movie_hero_band_test.dart` | Hero band: brand chip + status pill present for all three brands (the dead-branch regression), gradient fallback with no network request when no poster, `CachedNetworkImage` when there is one, bundled asset still wins | pass |
| `test/pass_activity_date_test.dart` | Display and ISO date parsing, incl. rejection of overflow calendar dates (`2024-02-31`) that `DateTime.parse` silently rolls into the next month | pass |
| `test/pass_history_folders_test.dart` / `test/archive_layout_test.dart` | Archive foldering and layout | pass |
| `test/account_profile_provider_test.dart` | Profile persistence against a stubbed store: hydration, rejected read / write / delete, rollback, and write serialization | pass |
| `test/widget_test.dart` | Boot through onboarding into the dashboard shell | pass |
| `test/attachment_store_test.dart` | Encrypted attachment save/resolve round-trip, delete, `deleteAllFor`, orphan sweep keeping referenced files, and the key interlock — including a stored key of the wrong length being refused rather than replaced | pass |
| `test/id_attachment_limits_test.dart` | 3 images + 1 PDF counted independently, over-limit and oversize rejection, extension-to-kind mapping | pass |
| `test/id_attachment_model_test.dart` / `test/id_document_attachments_test.dart` | Attachment JSON round-trip and back-compat: a record written **without** the `attachments` key, and a malformed non-list value, both decode to an empty list | pass |
| `test/id_attachment_tray_test.dart` | Tray states: empty, counter at 2 attachments, add tile hidden at capacity, long-press remove callback, PDF placeholder | pass |

The whole suite terminates — the old `widget_test.dart` hang (unbounded `pumpAndSettle()` against
continuously animating screens) is fixed.

Coverage is still thin below that: `SecureDocumentStore`, MRZ parsing, and the NFC bridge have
**no automated tests**.

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

The server (`../docket_server`, branch `dev-auth_and_users`) is ahead of the app and waiting on it. To connect:

1. Add `http` (or `dio`) and `google_sign_in`; keep `flutter_secure_storage` for tokens.
2. Implement `RemotePassRepository.fetchPasses` / `fetchPassById` against `PassApiPaths` using `PassListResponse.fromJson`.
3. Replace `authSessionProvider` with a real session: `POST /v1/auth/google` with the Google `idToken`, store access + refresh in secure storage, attach `Authorization: Bearer`, and on `401` do a single `POST /v1/auth/refresh` + retry before signing out.
4. Map the membership card from `/v1/me`: `joinedAt` → `MMMM y`, `displayName`, `#publicId`.
5. Optional next: multipart extract upload from camera/gallery (handle `429` with `retryAfterSeconds` / `window`), and FCM token registration via `POST /v1/devices`.

Full guide: `../docket_server/docs/flutter_auth_integration.md`. Contract: [`api/passes.md`](api/passes.md). Switching: [`dev-flags.md`](dev-flags.md).

---

## 5. Known issues

- `PLAN.md` still uses the old "SlickPort" name and predates the tickets/passes work — history, not spec. (`README.md` was corrected on 2 Aug 2026: absolute `passport_app` links, the PACE claim, and a non-existent search feature.)
- `applicationId` is still the scaffold default `com.example.docket`.
- `terminals/`, `build/`, `jmrtd-src/` and `jmrtd-sources.jar` are scratch, output, and vendored reference material — not build inputs.
