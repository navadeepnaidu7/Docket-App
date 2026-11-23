# Current state

Source reviewed: **23 November 2026**, maintenance-only commit snapshot. This is a capability
snapshot, not a release certification. Use the [README task map](../README.md#task-map)
to locate code and tests; do not load every feature plan as startup context.

## Implemented in source

| Area | Current behavior / owner |
|---|---|
| Local documents | Passports, Aadhaar/PAN IDs and payment cards; encrypted records, validation, editing, ordering, filters, search, archive and trash. Record loading/corruption guards live in `lib/core/storage/`; wallet startup/loading in `lib/core/wallet/`. |
| Passport capture | Manual/prompted entry, ML Kit MRZ OCR and Android NFC chip reading (BAC; DG1/DG2/DG11/DG12 mapping). iOS NFC is not implemented. |
| Attachments | Encrypted image/PDF files, metadata-only record storage, attachment limits, preview/share/open, and guarded orphan cleanup. Trashed documents retain their files. See [attachment contract](features/id-media-attachments.md). |
| Payment cards | Manual/scan/review flows, encrypted storage, guarded details/copy/reveal, and optional wallet stacking. See [payment cards](features/payment-cards.md). |
| Account auth | Google Sign-In gateway obtains an ID token; auth controller exchanges it with the backend, hydrates cached identity and fetches `/v1/me`. Session refresh is implemented by the API client. Requires OAuth client configuration; Developer mock/token bypass is a separate debug path. |
| Passes | Train, movie, bus and flight models, faces, details/code screens, archive, import from photo/PDF, train PNR input, pending/retry recovery, deletion and sharing. Mock and HTTP repositories are implemented. Flight work is active; [flight contract](features/flight-pass.md) records its verification limits. |
| Pass artwork / codes | Cached movie posters and airline logos with honest fallbacks; genuine payloads rendered in their original symbology. No invented gate codes. See [code extraction](features/ticket-code-extraction.md) and [share](features/pass-share.md). |
| Calendar | Connect/status/sync/disconnect providers and Settings UI using backend-managed Google consent. Requires a signed-in account and backend integration configuration. See [calendar import](features/calendar-import.md). |
| Shell | Onboarding, Settings, account card, themes, haptics/sound and weather glance. Existing document/pass faces retain their own design contracts. |
| Startup | Returning users prepare local records, saved order and initial artwork in one Riverpod container before `runApp`; fonts are bundled and runtime fetching is disabled. Optional network features stay outside this launch barrier. See [wallet startup](features/startup.md). |

## Configuration and platform limits

- Debug/profile normally uses mock passes and allows persisted Developer overrides.
  Normal release ignores those overrides and selects remote passes with no mock account
  or developer token. An explicitly empty API origin still activates the mock fallback.
  The default origin is configured in `DevConfig`; it is not evidence of current server
  uptime. See [dev flags](dev-flags.md) for exact configuration and sign-in requirements.
- Google Sign-In is implemented, but a valid `GOOGLE_SERVER_CLIENT_ID`, matching backend
  audience configuration, Android package/certificate registration and (for iOS) client
  setup are needed to exercise the real account picker. Local code does not prove those
  external registrations are configured correctly.
- Android is the tracked platform scaffold. NFC has only an Android implementation.
  OCR text recognition is bundled; face/barcode models use Play Services and may be
  unavailable on first use. Code scanning then degrades without inventing results.
- Release still uses `com.example.docket` and the debug signing configuration in
  `android/app/build.gradle.kts`. Production identity/signing, Play metadata and privacy
  disclosures remain release work. FCM device registration is not implemented in this app.
- R8 rules retain the reflective NFC libraries. Verify native NFC on a release APK and
  inspect ABI contents on a newly built artifact; old APK sizes are not current evidence.

## Verification

Record the command, date and scope. Source presence, automated tests and device checks
are separate evidence; a proposal or old passing count is not a current baseline.

- **23 November 2026, maintenance-only snapshot:**
  - `dart analyze --format machine lib test tool`: **no diagnostics**, exit 0.
  - `flutter test --no-pub --reporter expanded`: **937 passed**, 04:21 elapsed.
  - `python tool/check_docs.py`: repository-local Markdown link targets exist.
- Three stale golden baselines were reviewed and refreshed for the committed UI. Separate
  uncommitted flight-import, theme and motion edits were excluded. No device checks ran.
- Still require device/release checks: NFC after R8, install over pre-migration builds,
  attachment trash/restore, first-use ML Kit behavior, real Google sign-in/Calendar
  configuration, and iOS permission/share/viewer paths. See the relevant contract for
  narrower guarantees and [startup investigation](features/startup.md#measuring-startup)
  for measured build-mode/device caveats.
