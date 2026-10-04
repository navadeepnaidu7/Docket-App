# Startup performance and resilience

## Scope

Keep the first frame independent of network fonts and hidden screens. Preserve
encrypted records and the existing theme transition and onboarding behavior.

## Findings and approach

- `main` used to build both themes and warm fonts for Passes and Settings,
  then wait up to 900 ms for downloads. All 16 used font variants now ship
  with the app (2,807,840 font bytes, plus licences); runtime fetching is
  disabled. Only the active theme is constructed on launch and fonts no longer
  gate the first frame. The bundling tool validates pinned hashes and lengths.
- Dashboard schedules hidden Passes using an idle scheduler task, which the
  existing widget tests identify as a first-frame hang. Use cancellable,
  post-entry warm-up and guard disposal instead.
- Passport loading used to decode every JSON record twice. It now decodes once.
  Lists of at least 64 records or 64 KiB are parsed on a worker isolate, including
  the outer encrypted-store JSON list, so portrait-heavy wallets leave UI events
  free to run on Android/iOS.
- Wallet ordering and reconciliation are linear, preserve stable order for
  unlisted items, and remove duplicate/stale order ids. Reconciliation waits for
  both document lists and the persisted order to load; callbacks use fresh data.
- Startup loads are single-flight and check disposal after awaits. Early adds
  wait for original records before saving, and failed writes do not poison the
  next write. Trash operations likewise wait for the original trash contents.
- Malformed outer lists or individual records protect their storage key against
  partial overwrites. Legacy migration write failures retain and protect the
  plaintext originals. Orphan cleanup skips unreadable or disposed lists.
- Integration checks found the weather action clipped on a narrow screen at
  2x text. The panel now reserves sufficient extra height for wrapped text;
  its compact height at normal text size is preserved.
- Exercise corruption, slow reads, interrupted startup, repeated launches,
  and large collections. Do not weaken secure-storage write interlocks.

## Verification

### Android profile measurements (5 Oct 2026)

Motorola edge 30, Android 14, Flutter 3.44.9, profile APK. Existing app data and
font caches were preserved; no uninstall or clear-data command was used. The
original trace completed before changes; three optimized process launches used
the same optimized APK. Engine/device load varies substantially, so these are
observations on this device, not a production latency guarantee.

| Metric | Original (1 run) | Optimized (3 runs) | Optimized median |
|---|---:|---:|---:|
| First frame built | 1,955.607 ms | 1,288.583 / 1,801.329 / 652.301 ms | 1,288.583 ms |
| First frame rasterized | 2,068.233 ms | 1,441.622 / 1,947.996 / 693.675 ms | 1,441.622 ms |
| After framework init to first frame | 1,082.030 ms | 330.247 / 708.108 / 225.947 ms | 330.247 ms |

The optimized median is 34% lower for first-frame build and 30% lower for
rasterization. Raw metrics are preserved in `docs/performance/startup-profile.json`.
Flutter's first optimized tracing attempt lost its wireless VM-service
connection; the successful repeats used `--disable-dds` and the built APK.

### Regression coverage

- 12,000 wallet cards; 50,000 ordering ids; duplicate/stale/unlisted ids.
- 300 passports with 32 KiB portraits each; UI event responsiveness during parse.
- Ten immediate open/close cycles and twenty rapid/early tab switches.
- Pending secure reads during disposal; keystore errors; slow document reads
  preserving persisted order; adds during startup; a burst of 100 saves with
  an injected first-write failure.
- Invalid JSON, wrong outer types, mixed record types, partial record corruption,
  migration failure, successful storage retry, and malformed onboarding prefs.
- Weather location/loading actions stay inside the panel at 320/390 px widths
  and 1x/2x text, including disabled loading actions and permission errors.
- All font families resolve with network fetching disabled. Golden tests now
  load real fonts and icon assets instead of recording Ahem placeholder glyphs;
  all five refreshed menu images were visually inspected.

Final `flutter test --no-pub --reporter expanded`: **660 tests passed**, including
startup, storage, ordering, font, reordering, golden, and large-text checks.
Static analysis of the changed startup files, licences, sizing helper and tests
reports **no issues**. The final whole-project analyzer run reports four existing
info-level lints in Settings and NFC payload code, with no errors or warnings.
