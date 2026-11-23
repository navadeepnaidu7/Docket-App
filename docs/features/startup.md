# Startup

How Docket opens, what it waits for, and what has been measured. This replaces the
separate calm-startup, wallet-startup, startup-performance and 23 Nov 2026 investigation
notes.

Status: implemented. Owners: `lib/main.dart`, `lib/core/wallet/wallet_startup.dart`
(`prepareWalletStartup`, `warmInitialWalletAssets`), `DashboardScreen` initState.
Tests: `test/wallet_startup_test.dart` plus the dashboard startup, onboarding and font tests.

## Contract

- **Complete wallet on the first frame.** A returning user sees finished document faces:
  no spinner, no fallback-font swap, no missing emblem, no reordered first card. The native
  launch surface stays up until `runApp` can present that wallet.
- **What the barrier waits for.** `prepareWalletStartup` runs before `runApp`, in the same
  `ProviderContainer` the UI uses (so nothing is read twice). It waits concurrently for
  passports, IDs, payment cards and saved wallet order, applies the saved filter, then warms
  fonts and bundled artwork for the first two pages (all payment cards when the first page is
  the card stack).
- **What it never waits for.** Network passes, weather, add-menu artwork, maintenance and
  onboarding state stay outside the barrier. Hidden Passes is not built until selected; its
  data is fetched after the first frame on a cancellable timer, not an idle scheduler task
  (idle tasks starve under continuous animation and hang widget tests).
- **Asset failure is best-effort.** A damaged or missing bundled asset is swallowed; it must
  not strand a usable wallet.
- **No screenshots, no new plaintext.** Do not cache document renders or write new
  plaintext records to speed startup. Launch-only portrait bytes are held in memory (at most
  four encoded images) and cleared after the first frame.
- **Fonts are bundled.** All used variants ship in `assets/fonts/` and
  `GoogleFonts.config.allowRuntimeFetching = false` (`main.dart`). Only the active theme is
  constructed at launch. Saved theme settings are used at construction rather than animated
  in from device defaults.
- **Calm opening.** No automatic movement after launch: the dashboard entrance controller
  starts complete (no fade), and the weather glance does not open by itself (see
  `weather-glance.md`). The passport data page and DG2 portrait mount on first flip, then
  stay mounted.

## Storage safety on the startup path

These came out of the startup work and are load-bearing; do not weaken them for speed.

- Startup loads are single-flight and check disposal after every await.
- Adds made during startup wait for the original records before saving; a failed write does
  not poison the next write. Trash operations wait for the original trash contents.
- Malformed outer lists or individual records mark their key unreadable so a partial list is
  never written over them. Legacy migration write failures keep and protect the plaintext
  originals. Orphan cleanup skips unreadable or disposed lists.
- Passport JSON is decoded once. Lists of 64+ records or 64+ KiB (including the outer
  encrypted-store list) parse on a worker isolate.
- Wallet ordering/reconciliation is linear, keeps stable order for unlisted items, drops
  duplicate/stale ids, and waits for both document lists and the persisted order.

## Measuring startup

Use **profile or release** APKs for any acceptance number. Debug mode is several times
slower and reproduces "slow startup" complaints on its own.

Cold launch: `adb shell am start -S -W -n com.example.docket/.MainActivity` (`TotalTime` is
launch to first displayed frame). Never uninstall or clear data to get a cleaner number.

Latest measurements, Motorola Edge 30, 23 Nov 2026 (existing app data, process-cold,
not reboot-cold). Raw logs: `docs/performance/startup-edge30-2026-11-23.json`.

| From Dart `main()` | Debug | Profile |
|---|---:|---:|
| Binding, prefs, system chrome | 412-456 ms | 170-209 ms |
| + wallet records and order | +421-452 ms | +297-342 ms |
| + initial artwork and fonts | +512-530 ms | +27-34 ms |
| + `runApp` to first frame rasterized | +2,378-2,459 ms | +108-134 ms |
| Total | 3,738-3,899 ms | 624-710 ms |

Android `TotalTime` for the profile build was 1,618-2,310 ms, leaving roughly 1.0-1.6 s
before Dart `main()` (process, engine, plugin registration). Conclusions:

- The complete-wallet barrier costs about 0.33-0.38 s in profile on this phone. It is not
  the multi-second bottleneck.
- Debug's extra time is almost all after `runApp`; the probes cannot split JIT, debug
  checks and build/layout, so do not blame one widget or shader.
- Further native gains need a native trace separating engine start from plugin
  registration. Current evidence does not justify removing a plugin, weakening encrypted
  storage or changing document-loading gates.
- Release builds and the Nothing Phone 3a have not been measured.

Older measurements (5 Oct 2026, before the complete-wallet barrier) cut first-frame build
from 1,956 ms to a 1,289 ms median in profile; raw data in
`docs/performance/startup-profile.json`. They are history, not a current guarantee.

## Still unverified

iPhone startup timing (needs a Mac/iOS device), release-mode timing, and installing over an
existing build after future startup changes.
