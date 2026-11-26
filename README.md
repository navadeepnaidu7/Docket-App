# Docket

A Flutter wallet for passports, national IDs, payment cards and ticket passes.
Personal documents stay on the device; passes and account integrations use a backend.
Older history calls the app SlickPort / passport_app. The Dart package is `docket`.

## Run and verify

Requires Flutter compatible with Dart `^3.11.5` and Android SDK tooling (minimum
Android SDK 26). Android is the platform scaffold tracked in this repository.

```sh
flutter pub get
flutter run
flutter analyze --no-pub lib test tool
flutter test --no-pub
python tool/check_docs.py
```

Debug/profile defaults to mock passes. Normal release builds use the remote source,
ignore runtime developer overrides, and need Google OAuth configuration for sign-in.
See [dev flags](docs/dev-flags.md) for origins, client IDs and local-backend setup.

[Current state](docs/current_state.md) distinguishes implemented code, configuration
requirements, verification results and remaining release work.
[Contributor guidance](CLAUDE.md) contains the short working rules and safety invariants.

## Task map

Start with the row that matches the change. Read its source and focused tests;
open a feature contract when its behavior is involved. Paths below are entry points,
not an instruction to read every dependency. Run a listed suite with
`flutter test --no-pub test/<name>_test.dart`.

| Task | Source owner / entry point | Focused tests | Contract |
|---|---|---|---|
| App startup and first wallet frame | [main](lib/main.dart), [wallet startup](lib/core/wallet/wallet_startup.dart) | [wallet_startup](test/wallet_startup_test.dart), [main_startup](test/main_startup_test.dart), [document_startup_race](test/document_startup_race_test.dart) | [Wallet startup](docs/features/startup.md) |
| Theme, typography and system chrome | [AppTheme](lib/core/theme/app_theme.dart), [app transition](lib/app.dart) | [system_overlay_style](test/system_overlay_style_test.dart), [bundled_fonts](test/bundled_fonts_test.dart), [motion_audit](test/motion_audit_test.dart) | [UI scope](AGENTS.md#ui-work) |
| Dashboard navigation, gestures and tabs | [dashboard](lib/features/dashboard/presentation/dashboard_screen.dart), [widgets](lib/features/dashboard/presentation/widgets) | [dashboard_startup](test/dashboard_startup_test.dart), [home_tab_transition](test/home_tab_transition_test.dart), [alpha_wallet_controls](test/alpha_wallet_controls_test.dart) | [Motion and navigation](docs/features/motion-audit.md) |
| Settings and account card UI | [Settings composition](lib/features/dashboard/presentation/settings_screen.dart), [Settings components](lib/features/dashboard/presentation/settings) | [settings_scroll_rebuild](test/settings_scroll_rebuild_test.dart), [membership_card_material](test/membership_card_material_test.dart), [app_version](test/app_version_test.dart) | [Current state](docs/current_state.md) |
| Account sign-in and session hydration | [auth providers](lib/features/auth/application/auth_session_provider.dart), [Google gateway](lib/features/auth/application/google_auth_gateway.dart), [API session store](lib/features/tickets/data/api_session_store.dart) | [auth_session](test/auth_session_test.dart), [pass_provider_invalidation](test/pass_provider_invalidation_test.dart) | [Dev flags / OAuth](docs/dev-flags.md) |
| Notifications, reminders and account deletion | [notifications](lib/features/notifications), [notification Settings](lib/features/dashboard/presentation/settings/notification_settings.dart), [auth cleanup](lib/features/auth/application/account_cleanup.dart) | [planner](test/notification_planner_test.dart), [preferences](test/notification_preferences_test.dart), [scheduler](test/notification_service_test.dart), [account cleanup](test/notification_account_cleanup_test.dart), [auth lifecycle](test/notification_auth_lifecycle_test.dart) | [Notifications](docs/features/notifications.md) |
| Passport entry, MRZ and NFC | [passport flow](lib/features/passport/presentation/flow/passport_prompt_flow.dart), [field IDs](lib/features/passport/domain/passport_fields.dart), [NFC mapping](lib/features/nfc/application/chip_payload.dart), [MRZ scanner](lib/features/mrz_scanner) | [passport_prompt_flow](test/passport_prompt_flow_test.dart), [chip_payload](test/chip_payload_test.dart), [bac_key_format](test/bac_key_format_test.dart), [scan_accuracy](test/scan_accuracy_test.dart) | [Contributor invariants](CLAUDE.md#invariants-to-preserve) |
| IDs, encrypted attachments and external viewers | [ID application](lib/features/ids/application), [AttachmentStore](lib/core/storage/attachment_store.dart) | [attachment_store](test/attachment_store_test.dart), [id_attachment_limits](test/id_attachment_limits_test.dart), [id_document_screen](test/id_document_screen_test.dart) | [Attachments](docs/features/id-media-attachments.md), [ID tools](docs/features/id-document-tools.md) |
| Payment cards, scanning and card stack | [cards](lib/features/cards), [card list](lib/features/cards/application/card_list_provider.dart) | [payment_card](test/payment_card_test.dart), [payment_card_stack](test/payment_card_stack_test.dart), [card_copy_details](test/card_copy_details_test.dart) | [Payment cards](docs/features/payment-cards.md) |
| Persistence, corruption or startup loading | [secure storage](lib/core/storage/secure_document_store.dart), [record decoder](lib/core/storage/document_record_decoder.dart), [loading state](lib/core/wallet/wallet_loading_provider.dart) | [secure_document_store](test/secure_document_store_test.dart), [document_record_decoder](test/document_record_decoder_test.dart), [document_startup_race](test/document_startup_race_test.dart) | [Contributor invariants](CLAUDE.md#invariants-to-preserve) |
| Wallet ordering, filters, search, trash and archive | [wallet primitives](lib/core/wallet), [dashboard providers](lib/features/dashboard/application), [wallet search](lib/features/dashboard/presentation/wallet_search_screen.dart) | [manage_view](test/manage_view_test.dart), [wallet_search](test/wallet_search_test.dart), [trash_view](test/trash_view_test.dart), [archive_layout](test/archive_layout_test.dart) | [Manage / trash](docs/features/manage-trash-redesign.md), [Archive](docs/features/archive-pass-deck.md), [Search](docs/features/alpha-usability-polish.md) |
| Pass import, pending/retry and API requests | [ingest controller](lib/features/tickets/application/pass_ingest_controller.dart), [API client](lib/features/tickets/data/docket_api_client.dart), [pass list](lib/features/tickets/application/pass_list_provider.dart) | [pass_ingest_controller](test/pass_ingest_controller_test.dart), [pass_ingest_outcome](test/pass_ingest_outcome_test.dart), [pending_train_refresh](test/pending_train_refresh_test.dart) | [Pass input](docs/features/pass-input.md), [API](docs/api/passes.md) |
| Pass kinds, JSON and journey state | [pass catalog](lib/features/tickets/domain/pass_catalog.dart), [domain models](lib/features/tickets/domain) | [passes_json](test/passes_json_test.dart), [train_booking_state](test/train_booking_state_test.dart), [bus_journey_status](test/bus_journey_status_test.dart), [flight_pass](test/flight_pass_test.dart) | [API](docs/api/passes.md), [Flight pass](docs/features/flight-pass.md) |
| Pass faces, posters and airline logos | [pass presentation](lib/features/tickets/presentation), [logo cache](lib/features/tickets/data/airline_logo_cache.dart) | [train_pass_face](test/train_pass_face_test.dart), [bus_pass_face](test/bus_pass_face_test.dart), [flight_pass_face](test/flight_pass_face_test.dart), [movie_hero_band](test/movie_hero_band_test.dart) | [Train](docs/features/train-pass-redesign.md), [Bus](docs/features/bus-pass-redesign.md), [Movie artwork](docs/features/movie-logo-glance.md), [Flight](docs/features/flight-pass.md) |
| Scannable codes and exported passes | [code scanner](lib/features/tickets/application/ticket_code_scanner.dart), [share service](lib/features/tickets/application/pass_share_service.dart), [code view](lib/features/tickets/presentation/pass_code_view.dart) | [pass_code](test/pass_code_test.dart), [pass_code_view](test/pass_code_view_test.dart), [pass_share_card](test/pass_share_card_test.dart) | [Code extraction](docs/features/ticket-code-extraction.md), [Share](docs/features/pass-share.md) |
| Google Calendar import | [calendar provider](lib/features/tickets/application/calendar_import_controller.dart), [calendar screen](lib/features/tickets/presentation/calendar/calendar_import_screen.dart) | [calendar_import](test/calendar_import_test.dart) | [Calendar import](docs/features/calendar-import.md) |
| Weather glance and pull-down sky | [weather](lib/features/weather), [dashboard widgets](lib/features/dashboard/presentation/widgets) | [weather](test/weather_test.dart), [weather_glance_dashboard](test/weather_glance_dashboard_test.dart), [weather_soft_transition](test/weather_soft_transition_test.dart) | [Weather glance](docs/features/weather-glance.md) |
| Bundled artwork and attribution | [asset registry](lib/core/assets/app_assets.dart), [design masters](tool/design_src), [attributions](ATTRIBUTIONS.md) | [bank_mark](test/bank_mark_test.dart), [network_mark](test/network_mark_test.dart), [passport_cover_art](test/passport_cover_art_test.dart) | [Contributor guidance](CLAUDE.md) |

## Documentation rules

- This README is the task map; [current state](docs/current_state.md) is the capability
  and verification snapshot. Keep detailed behavior in the relevant feature contract.
- [Roadmap](docs/roadmap.md) holds only major planned features: purpose, design, shared
  data, risks and done criteria. Routine polish does not belong there.
- Mark proposals and historical investigations explicitly. Completed polish notes should
  be consolidated into their owner or archived when they retain useful evidence.
- Preserve safety decisions and constraints. Remove repeated session logs, stale branch/PR
  status and superseded instructions once their useful content has an authoritative home.
- [agent-guidance](agent-guidance/README.md) contains inactive portable skill snapshots;
  it is not another required reading path. `tool/` holds generators and opt-in preview tests;
  `build/`, `outputs/` and `terminals/` are ignored output, not source.

The optional sibling `../docket_server` owns backend operations; this repository's
[passes contract](docs/api/passes.md) describes the app/server boundary.
