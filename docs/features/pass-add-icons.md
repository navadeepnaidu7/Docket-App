# Passes add-menu icons

The Passes `+` menu uses iOS app-icon framing: continuous-corner squares,
subtle vertical gradients, and one optically sized symbol per category.
Light mode uses colored tiles with light symbols (a graphite camera on silver);
dark mode uses charcoal tiles with the corresponding colored symbols.
The same family covers PNR, Photo and PDF in the import step.

`PassAddArt` selects the palette and symbol through `PassAddIcon`. Most symbols
come from the existing MIT-licensed `cupertino_icons` dependency. The bus is an
original filled, front-facing vector drawn on a 24-unit grid to match their
weight and proportions. Flutter draws the symbols directly, so no raster icon
assets are loaded or decoded. `ClipRSuperellipse` supplies the corner shape.

`SquircleTile.artIsTile` lets this artwork fill the tile without a second
background behind it. The surrounding tile retains its labels, accessibility,
navigation, touch feedback and disabled coming-soon states.

The visual direction follows [Apple's app-icon guidance](https://developer.apple.com/design/human-interface-guidelines/app-icons):
simple backgrounds, a clear primary symbol, and consistent composition.

## Previous artwork

The earlier 3D experiment is retained in `tool/design_src/pass_add_icons/` and
`assets/passes/add/` as a design archive. Its exact generation prompts remain in
`tool/design_src/pass_add_icons/prompts.json`. Those bitmap files are no longer
listed in the Flutter asset bundle or used by the menu.

## Verification

- Actual menu previews cover categories and train import methods in both themes
  at 390px and 320px. No overflow or framework exceptions; disabled categories,
  step navigation and close behavior remain correct.
- Passes category and train-method goldens refreshed. Documents goldens are
  outside this change.
- All 13 scoped menu checks pass; focused Flutter analysis reports no issues.
- Reproduce previews with
  `flutter test --no-pub tool/pass_add_icons_preview_test.dart --update-goldens`.
  Outputs are in `build/pass-add-preview/`.
- Hardware rendering has not been checked.
