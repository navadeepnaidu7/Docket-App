# Startup investigation — 23 November 2026

## Measurements

Tested the Motorola Edge 30 using its existing app data. Cold launches used
`adb shell am start -S -W -n com.example.docket/.MainActivity`; Android's
`TotalTime` measures launch to the first displayed frame, not network completion
or every subsequent interaction. No uninstall or clear-data operation was used.

The original installed APK opened in **4,060 / 3,759 / 3,700 ms**.
After restoring that same APK at the end, its first launch took **9,895 ms** and
the next process-cold launch took **6,659 ms**. This also reproduces the reported
delay on the original build and demonstrates substantial variation. Installation,
runtime caches, device load and temperature were not controlled; the timing
probes do not isolate their individual contributions.
Both connected phones' original APKs contain `kernel_blob.bin`; the Edge 30 APK
also has no `libapp.so`, confirming a debug build. Android's `DEBUGGABLE` flag
alone is insufficient to distinguish Flutter debug from profile mode.

A temporary copy of `main.dart` added Stopwatch milestones around the existing
startup calls, without changing their order or wallet readiness behavior. A
profile APK of that entrypoint opened in **2,310 / 1,744 / 1,618 ms**.
The debug APK of the timing entrypoint opened in **8,305 / 5,684 / 5,616 ms**,
reproducing the reported delay. The diagnostic builds use the current workspace;
the original installed debug APK is a separate baseline, not an identical-source
control. Other UI work was in progress in the shared workspace during testing.
No source optimization is being claimed from this comparison.

Milestones, measured from Dart `main()`:

| Stage | Debug, three launches | Profile, three launches |
|---|---:|---:|
| Binding, preferences and system chrome ready | 412–456 ms | 170–209 ms |
| Local wallet records/order ready | an additional 421–452 ms | an additional 297–342 ms |
| Initial artwork and bundled fonts ready | an additional 512–530 ms | an additional 27–34 ms |
| `runApp` to first frame rasterized callback | an additional 2,378–2,459 ms | an additional 108–134 ms |
| Total Dart main to first frame rasterized | 3,738–3,899 ms | 624–710 ms |

In profile mode, subtracting the Dart elapsed time from Android's launch time leaves roughly
**1.0–1.6 seconds before Dart main**. This includes process/activity, Flutter
engine and plugin initialization. These milestones do not identify a particular
native plugin as responsible. Device scheduling and filesystem caches vary
between process-cold launches; these were not device-reboot/cache-cold tests.

## Findings

- Build mode is a major contributor on the Edge 30. Profile mode is substantially
  faster while retaining the complete-wallet launch barrier. A release build has
  not been measured; profile results are not a release timing guarantee.
  The largest measured Dart-side difference is after `runApp`: about 2.4 seconds
  in debug versus 0.11–0.13 seconds in profile. The probes do not separate JIT,
  debug framework checks, widget building/layout/painting and scheduling within
  that interval, so attributing it to one widget or shader would be unsupported.
- `lib/main.dart:54` waits for `prepareWalletStartup` before `runApp`.
  `lib/core/wallet/wallet_startup.dart:37` waits concurrently for passports, IDs,
  payment cards and saved order, then line 67 waits for initial artwork/fonts.
  This intentionally keeps the native splash visible until complete content is
  ready, as specified in `wallet-startup.md`.
- That barrier costs about **0.33–0.38 seconds** for records and artwork on this
  phone in profile mode. Asset preparation is not the measured multi-second
  bottleneck. Larger or different wallets, especially on the Nothing phone,
  could have different costs; its launch stages were not measured.
- Fonts are bundled and runtime fetching is disabled. Pass fetching, weather
  and optional artwork are outside the pre-`runApp` barrier. No API timeout was
  found on the path that holds the native splash.
- The October profile results in `startup-performance.md` predate the current
  complete-wallet barrier; they are not a current launch-time guarantee.

## Direction

Use profile/release APKs for startup acceptance measurements. Keep the requested
complete first wallet frame while evaluating them. Further native startup
optimization needs a native trace separating engine startup and plugin
registration; the current evidence does not justify removing a particular
plugin, weakening encrypted storage or changing document-loading safety gates.

The diagnostic entrypoint and APK backups are under the ignored
`build/startup-investigation/` directory. No product source was changed for this
investigation. Other in-progress UI changes in the workspace were preserved.
Raw timing logs are in `docs/performance/startup-edge30-2026-11-23.json`.
The Edge 30's original APK was restored with `adb install -r`, its on-device
SHA-256 was verified against the backup, and the app was opened successfully.
