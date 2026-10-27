# Align IDs filter ink with the wallet theme

Written against: `452f2f331c7c8c433c1840a35f5a1727a2a7b8de`, branch `visual-refresh`, including existing uncommitted changes inspected on 2026-10-27.

Status: selected for implementation; product source unchanged by this plan.

## Evidence chain

- Surface: `DocketApp` → `DashboardScreen` home mode → `IdsTab` → `WalletFilterControls` and `_FilteredEmptyState`.
- Problem: `wallet_filter_controls.dart:46` and `ids_tab.dart:348` define primary ink as white in dark mode and `#1C1C1E` in light mode. The theme's actual ink is `#F5F5F7` / `#111113`.
- Design evidence: `CLAUDE.md:123` requires theme-token reuse instead of raw colors. `app_theme.dart:171` assigns the theme ink to `ColorScheme.onSurface`.
- Owner: `lib/core/theme/app_theme.dart`; consumers are the two widget-local `ink` definitions.
- Runtime: `app.dart:154` supplies the theme; `dashboard_screen.dart:745` renders `IdsTab`; `ids_tab.dart:223` renders the filtered-empty state and `:324` renders filter controls when enabled and multiple categories exist.
- Uncertainty: this is a source-proven palette mismatch, not a claim that the small color difference is a major usability problem. No rendered comparison was performed.

## Design decision

Resolve both primary `ink` values from `Theme.of(context).colorScheme.onSurface`. This makes filter labels and their existing opacity-derived icons follow the same theme owner as the surrounding wallet.

## Reuse

- `Theme.of(context).colorScheme.onSurface`.
- Exemplars: `_ActiveFilterChip.build` in `wallet_filter_controls.dart:202` and `DashboardHeader.build` in `dashboard_header.dart:108`.
- No new primitive or token is needed.

## Changes

1. `lib/features/dashboard/presentation/widgets/wallet_filter_controls.dart`
   - Replace only `_WalletFilterControlsState.build`'s hardcoded primary `ink` assignment with the theme's `colorScheme.onSurface`.
   - Keep `isDark`: other existing color calculations still use it.
   - Preserve selection, clearing, labels, layout, motion, and current alpha multipliers.
2. `lib/features/dashboard/presentation/widgets/ids_tab.dart`
   - Make the same replacement in `_FilteredEmptyState.build`.
   - Preserve `isDark`, muted color, copy, reset action, and geometry.

## Scope

- Inherit: filter trigger, selected menu text, ink-derived filter icons, filtered-empty primary message.
- Verify: active chip and header continue to share the same underlying ink.
- Exclude: muted text, fills, borders, artwork, card faces, bottom navigation, other screens, typography, and motion.

## Validation

- Product: enable category filtering in an IDs wallet with multiple document categories; open, select, and clear a category.
- Interface: compare light and dark settled themes; check primary filter ink against the active chip/header. Check filtered-empty text if that state is reachable with existing data; do not change filtering behavior to manufacture it.
- System: confirm the two assignments use the existing theme value, with no new palette definitions.
- Repository: run `flutter analyze`; compare results with any pre-existing issues. No new tests are necessary for these two presentation-only assignments. Do not format unrelated files.

## Stop conditions

- Recheck ownership if these widgets or the theme have changed since this plan.
- Do not widen the change to other colors or redesign the filter without a separate product decision.

## Design documentation

None. The existing token-reuse rule already covers this decision.
