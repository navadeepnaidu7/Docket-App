# Development flags and account configuration

Status: maintained configuration reference. Source reviewed 23 November 2026:
`lib/core/dev/dev_config.dart`, `dev_flags.dart`, `dev_flags_provider.dart`,
`lib/features/auth/application/`, and the pass/API providers.

## Source selection

Debug/profile reads compile-time defaults, then persisted **Settings → Developer**
overrides. Settings can change the mock source, API origin, mock account preview and
Developer auth token, reload passes, or reset flags to compile-time defaults.

Normal release (`FORCE_DEV_MENU=false`) ignores persisted overrides and uses
`DevFlags.lockedConsumer()`: remote passes, configured origin, no mock account and no
Developer token. `USE_MOCK_PASSES` is therefore a debug/profile default, not a way to
ship a fixture wallet in a normal release. `FORCE_DEV_MENU=true` explicitly enables
runtime overrides even in release; use only for intentional development builds.

`isMockPassesActive` is `useMockPasses || apiBaseUrl.trim().isEmpty`. An empty origin
activates the mock fallback in any mode. With a valid origin and no signed-in account
or Developer token, the remote repository selector returns an empty wallet until auth.
A genuine account session wins over the mock account preview.

## Compile-time configuration

| Define | Default | Meaning |
|---|---|---|
| `USE_MOCK_PASSES` | `true` | Initial debug/profile fixture source |
| `API_BASE_URL` | `https://api-production-5f3a7.up.railway.app` | Backend origin; do not include a trailing slash |
| `GOOGLE_SERVER_CLIENT_ID` | empty | Web OAuth client ID used as Google token audience / Android server client ID |
| `GOOGLE_IOS_CLIENT_ID` | empty | iOS OAuth client ID, when targeting iOS |
| `DEV_AUTH_ID_TOKEN` | empty | Local/staging developer bypass token; never embed production credentials |
| `FORCE_DEV_MENU` | `false` | Explicitly allow Developer controls outside debug/profile |

The configured origin does not prove deployment health. Backend deployment, allowed
Google audiences and Calendar credentials belong to the optional sibling server repo.

```sh
# Debug with fixtures (persisted Developer settings can override this)
flutter run

# Android emulator against a local server
flutter run --dart-define=USE_MOCK_PASSES=false --dart-define=API_BASE_URL=http://10.0.2.2:8080

# Real account picker against the configured backend
flutter run --dart-define=USE_MOCK_PASSES=false --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID
```

For real Google sign-in, register the Android package and signing certificate with
Google and configure the backend to accept the same audience. The gateway initializes
`google_sign_in`, handles cancellation and exchanges the returned ID token at
`POST /v1/auth/google`; the app securely stores session tokens and refreshes on `401`.
The account controller restores cached identity and validates it through `/v1/me`.

When no Web client ID is configured, debug/profile uses the Developer bypass token if
present, or enables the mock account preview. Normal release reports missing Google
configuration; it does not enable the preview/bypass path.

## Local networking and tests

Android cleartext exceptions are restricted to `10.0.2.2` / `localhost`; production
uses HTTPS. Do not broaden the base cleartext policy. iOS local HTTP and OAuth setup
need platform configuration and verification outside the tracked Android scaffold.

Tests override `devFlagsProvider` using `DevFlagsNotifier.fixed(DevFlags(...))`, and
replace the repository, Google gateway or API provider rather than making real requests.
See [auth tests](../test/auth_session_test.dart) and
[provider invalidation tests](../test/pass_provider_invalidation_test.dart).
