# Calm startup

Scope: reduce opening movement and work while preserving wallet artwork and navigation.

- Replace the 560 ms full-content slide with a 200 ms opacity fade, honoring reduced motion.
- Keep weather pull-down available; do not automatically move the wallet after launch.
- Fetch pass data after opening without constructing the hidden TicketsTab until selected.
- Mount the passport data page (including DG2 portrait widgets) on the first flip, then retain it.
- Preserve encrypted storage, migrations and uncommitted UI work.

Verification: startup lifecycle/tab-switch tests, passport flip tests, analyzer and full tests. Device frame timing and install-over-existing-build remain separate checks.

## Verification (29 October 2026)

- Focused startup, main entry, passport cover/flip and weather dashboard checks: 25 passed, including immediate reduced-motion visibility.
- `flutter analyze --no-pub lib test`: no errors or warnings; four existing informational lints in settings_screen.dart and chip_payload.dart.
- Full suite: 702 passed, five failed. Four failures compare add-menu/passport-cover artwork to golden images; one Settings test cannot find its expected section label. Those tests exercise surfaces outside this startup change; their baselines were not rewritten.
- Repository-wide analysis also scans saved rejected code under build/session-polish and reports unresolved imports there.
- No on-device launch recording, frame-time comparison or install-over-existing-build verification was performed. The 200 ms fade is an animation setting, not a measured cold-start time.
