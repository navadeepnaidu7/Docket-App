# Dev flags — mock vs consumer

Docket uses a **layered config** so you can switch mock fixture data and the real API path without rebuilding for every change.

```
--dart-define (compile-time)
        ↓
devFlagsProvider (runtime prefs, debug/profile only)
        ↓
passRepositoryProvider → MockPassRepository | RemotePassRepository
        ↓
Passes UI (same cards)
```

## In-app (debug / profile)

**Settings → Developer**

| Control | Effect |
|---------|--------|
| **Use mock passes** | On → fixtures. Off → remote (needs API URL). |
| **API base URL** | e.g. `https://api.staging.example.com` (no trailing slash). Empty forces mock. |
| **Reload passes** | Re-fetch current source. |
| **Reset dev flags** | Clear prefs; back to compile-time defaults. |

Passes tab shows a purple **MOCK** chip when mock mode is active (dev menu only).

Release builds hide Developer and ignore runtime overrides.

## Compile-time

```bash
# Default local (mock)
flutter run

# Consumer / staging API
flutter run \
  --dart-define=USE_MOCK_PASSES=false \
  --dart-define=API_BASE_URL=https://api.staging.example.com

# Show dev menu in a release-like build (rare)
flutter run --release --dart-define=FORCE_DEV_MENU=true
```

| Define | Default | Meaning |
|--------|---------|---------|
| `USE_MOCK_PASSES` | `true` | Initial mock-on |
| `API_BASE_URL` | `""` | Remote base URL |
| `FORCE_DEV_MENU` | `false` | Show Developer outside debug |

## Code map

| File | Role |
|------|------|
| `lib/core/dev/dev_config.dart` | Defines + `showDevMenu` |
| `lib/core/dev/dev_flags.dart` | `DevFlags` model |
| `lib/core/dev/dev_flags_provider.dart` | Riverpod + SharedPreferences |
| `lib/features/tickets/application/pass_list_provider.dart` | Repo switch + list |

## Tests

```dart
ProviderScope(
  overrides: [
    devFlagsProvider.overrideWith(
      (ref) => DevFlagsNotifier.fixed(
        const DevFlags(useMockPasses: true, apiBaseUrl: ''),
      ),
    ),
  ],
  child: ...
)
```

## When backend is ready

1. Implement HTTP in `RemotePassRepository` (`docs/api/passes.md`).
2. Set base URL in Developer or via `--dart-define`.
3. Turn **Use mock passes** off.
4. Ship release with `USE_MOCK_PASSES=false` and production `API_BASE_URL` in CI.
