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
- **Wallet organisation**: drag-to-reorder in Manage Cards (`ReorderableListView`), persisted order reconciled on add/remove, trash with restore/permanent delete, category filter, and a "Space" archive screen with counts, top category, milestones and peak month.

### 1.3 Passes — UI complete, data mocked
- Sealed `WalletPassItem` (`TrainPassItem | MoviePassItem`) with hand-written JSON models; parsers accept both the `{kind, train|movie: {...}}` envelope and a bare nested object.
- Train: wallet card, detail screen, ticket face with passengers, halts, live-status label and progress.
- Movie: brand chrome for `bookMyShow` / `district` / `universal` (unknown brand → universal), ticket face, and a gate-code screen.
- Fixtures: **6 train passes and 4 movie passes** in `mock_pass_fixtures.dart`.
- Source selection via `devFlagsProvider` → `MockPassRepository` or `RemotePassRepository`; a purple **MOCK** chip shows in the Passes tab while mock mode is active.

### 1.4 Settings
Appearance (light / dark / device / scheduled with a custom time picker), haptics, navigation icon style and labels, experimental toggles (card shine border, card category filter), Account section, About / developer links (`url_launcher`), and a Developer section (debug/profile only, or `--dart-define=FORCE_DEV_MENU=true`) exposing mock passes, mock sign-in, card gradient scheme, API base URL, reload passes, and reset flags.

### 1.5 Design & sensory layer
3D card tilt and drag reactions, custom-drawn shine/holographic borders, `studio_*` shared widget set, entry-reveal motion curves, haptic service, sound triggers, and an easter-egg drawer.

### 1.6 Platform
Android `minSdk 26`, `applicationId`/`namespace` `com.example.docket`, NFC via `MethodChannel('com.docket/nfc_passport')` backed by JMRTD + scuba + BouncyCastle + JP2Decoder.

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
4 issues, all `info` level `curly_braces_in_flow_control_structures`
(`secure_document_store.dart:36`, `id_scanner_screen.dart:128`, `mrz_scanner_screen.dart:130`, `test/widget_test.dart:28`). No warnings or errors.

### 3.2 Tests

```bash
flutter test test/passes_json_test.dart test/wallet_card_responsive_test.dart
# 109 tests, All tests passed!
```

| Suite | Covers | Result |
|-------|--------|--------|
| `test/passes_json_test.dart` | Train/movie JSON round-trips over fixtures, envelope parsing, brand fallback | pass |
| `test/wallet_card_responsive_test.dart` | Card layout across device sizes down to 320×568, incl. short viewports (split screen) and `WalletCardMetrics.resolve` | pass |
| `test/widget_test.dart` | Boot through onboarding into the dashboard shell | **hangs** |

> ⚠️ **`flutter test` (whole suite) does not terminate.** `widget_test.dart` runs for 5+ minutes
> at full CPU and does not finish, even with `--timeout 90s`. It calls `pumpAndSettle()` three
> times against screens that have continuous animation (onboarding background, shine, theme
> lerp), and `pumpAndSettle` spins until the frame queue is empty — which never happens. Run the
> other two suites explicitly until this is fixed (replace the `pumpAndSettle()` calls with
> bounded `pump(Duration)` loops, as the earlier part of the same test already does).

Coverage is thin regardless: providers, secure storage, MRZ parsing, and the NFC bridge have
**no automated tests**.

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
