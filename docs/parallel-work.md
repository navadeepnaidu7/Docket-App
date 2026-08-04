# Parallel work: branch and file ownership

Two features are in flight at once. This is the contract that keeps them
mergeable. Read it before starting work on either.

## Branches

```
master (34c6038)
  └── 16733a7  test: make the suite terminate      ← shared prerequisite
        └── f21d042  pure-logic groundwork          ← shared prerequisite
              ├── feat/movie-poster-rendering       6540442
              └── feat/prompted-entry-flow          de856cd …
```

Both feature branches descend from the **same two commit objects**, not from
copies. That matters: whichever merges into `master` first brings the shared
prerequisites, and the second merge sees them as already-merged ancestors. No
duplication, no conflict, and **merge order does not matter**.

Verified on 2 Aug 2026 by merging both into a throwaway branch off `master`:
zero conflicts, 184 tests passing, `flutter analyze` clean.

### The two shared commits

- **`16733a7`** — `flutter test` never terminated before this; `widget_test.dart`
  span in `pumpAndSettle` against repeating animations until its own ten-minute
  timeout. Everything downstream depends on being able to run the suite.
- **`f21d042`** — validators, `BacKeyFormat`, `NfcFailure`, the
  `imagePath`/`photoBase64` split, and the wallet-order fix. No UI. It also
  carries the CLAUDE.md *Movie posters* section, which belongs to the poster
  feature and was swept in by accident while both sets of changes shared a
  working tree. It is left there deliberately: rewriting a pushed commit that
  both branches descend from would cost more than the misattribution does.

## File ownership

The two features currently touch **completely disjoint file sets**. Keep it that
way and there is nothing to resolve.

| Owner | Paths |
|---|---|
| **Movie posters** | `lib/features/tickets/**`, `lib/core/assets/app_assets.dart`, `assets/passes/**`, `android/app/src/main/res/xml/**`, `test/movie_hero_band_test.dart`, `test/passes_json_test.dart` |
| **Prompted entry flow** | `lib/shared/prompt_flow/**`, `lib/features/passport/**`, `lib/features/ids/**`, `lib/features/nfc/**`, `lib/features/mrz_scanner/**`, `lib/core/validation/**`, `lib/core/storage/image_payload.dart`, `lib/core/theme/app_spacing.dart`, `lib/core/theme/prompt_typography.dart`, `android/…/MainActivity.kt`, `test/prompt_flow_*`, `test/document_validators_test.dart`, `test/bac_key_format_test.dart`, `test/nfc_failure_test.dart`, `test/passport_profile_migration_test.dart`, `test/image_payload_test.dart` |

### Contended files — coordinate before editing

These are the only places the two features can realistically collide.

| File | Risk | Rule |
|---|---|---|
| `pubspec.yaml` / `pubspec.lock` | Both may add dependencies | Add your dependency on its own line; never reformat or reorder the file. Regenerate the lock separately and take *both* sides when resolving. |
| `lib/core/theme/app_theme.dart` | Entry flow added shape/size tokens | Additive only. Do not renumber or repurpose an existing token. |
| `lib/features/dashboard/presentation/**` | Entry flow will change the add-document sheet and route; posters may touch the passes tab | Entry flow owns `add_item_sheet.dart` and the passport/ID routes. Posters own the passes tab body. |
| `CLAUDE.md`, `docs/current_state.md`, `docs/api/passes.md` | Both document their work | Append a new section rather than editing a neighbouring one. Never rewrap paragraphs you did not write — that turns a one-line change into a whole-file conflict. |
| `android/app/src/main/AndroidManifest.xml` | Posters added network security config; entry flow may touch NFC intent filters | Separate elements, so additive edits merge. Do not reorder existing entries. |

## Working rules

1. **Never commit from a shared working tree without a pathspec.** Use
   `git commit -- <paths>` or stage explicitly. Both features had changes in the
   tree simultaneously; a bare `git commit -a` sweeps the other agent's work into
   your commit. That is exactly how the CLAUDE.md section above ended up in the
   wrong place.
2. **Rebase onto the shared prerequisites, not onto the other feature branch.**
   If you need something from the other feature, say so rather than branching off
   it — that is what interleaved the two histories in the first place.
3. **Run the whole suite before pushing.** It takes about fifteen seconds now.
4. **`flutter analyze` must stay at 3 known infos** (`secure_document_store.dart:36`,
   `id_scanner_screen.dart:128`, `mrz_scanner_screen.dart:130`). Those three are
   pre-existing and are cleaned up by the entry flow's Stage 8.

## Known cross-feature interaction

The entry flow's Stage 7 replaces unguarded `base64Decode` calls with a
`SafeBase64Image` widget across **all four** wallet cards, including the two ID
cards and the passport card. If the poster work adds image rendering to the movie
card, use the same widget rather than a second decode path — `Image.memory` on a
malformed payload throws during build, which is the bug Stage 7 exists to fix.
