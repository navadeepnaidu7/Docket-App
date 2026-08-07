# Docket

Docket is a Flutter wallet app for storing personal documents on-device. It supports passports, national IDs, and ticket passes with a local-first architecture.

Docket was previously named `SlickPort` / `passport_app` in older docs.

## Current status

- Passport and ID flows are implemented and stored locally in encrypted storage.
- MRZ scanning and Android NFC passport chip reading are implemented.
- Passes UI (train and movie) is implemented.
- Passes backend integration is still in progress; mock fixtures are the default data source.

Details: [`docs/current_state.md`](docs/current_state.md)

## Features

### Documents (local-first)
- Passport records with manual entry, MRZ scan, and Android NFC chip read flows.
- ID records for Aadhaar and PAN.
- Encrypted on-device persistence using `flutter_secure_storage`.

### Wallet experience
- Interactive card-based dashboard with reorder, filters, archive, and trash flows.
- Light and dark themes with a custom transition system.
- Haptics and sound hooks integrated into key interactions.

### Passes
- Train and movie pass card layouts and detail screens.
- Movie posters fetched through the backend image proxy with cache support.
- Mock/remote switching through dev flags.

## Tech stack

- Flutter (Dart SDK `^3.11.5`)
- Riverpod 2
- Flutter Secure Storage
- Google ML Kit (text, face, barcode)
- Cached Network Image

## Requirements

- Flutter SDK compatible with Dart `^3.11.5`
- Android `minSdk 26`
- iOS 13+

## Getting started

```bash
flutter pub get
flutter run
```

### Useful commands

```bash
flutter analyze
flutter test
flutter build apk --release
```

### Run against a local backend (Android emulator)

```bash
flutter run \
  --dart-define=USE_MOCK_PASSES=false \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

More on flags: [`docs/dev-flags.md`](docs/dev-flags.md)

## Project layout

```text
lib/
  core/         app-wide services (dev flags, storage, theme, wallet primitives)
  features/     feature-first modules (dashboard, passport, ids, tickets, nfc, mrz)
  shared/       shared UI widgets
```

## Security and privacy

- Personal document data is intended to stay on device.
- Sensitive document payloads must not be logged.
- Storage is encrypted through platform-secure mechanisms.

## Release plan

The project is preparing for public distribution:

- GitHub Releases are planned soon for versioned release artifacts and notes.
- Google Play Store release preparation is in progress.

## Documentation

- [`docs/current_state.md`](docs/current_state.md): implementation status and verification notes
- [`docs/api/passes.md`](docs/api/passes.md): passes API contract
- [`docs/dev-flags.md`](docs/dev-flags.md): mock vs remote configuration
- [`CLAUDE.md`](CLAUDE.md): repository-specific contributor guidance
