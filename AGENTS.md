# Docket contributor guidance

Read `CLAUDE.md` for repository conventions. Treat current source and the user's latest direction as authoritative when historical status notes disagree.

## UI work

- Docket is a Flutter document wallet. Inspect the requested screen and its actual theme/component owners before choosing a visual treatment. Do not import web landing-page layouts, Tailwind values, or desktop conventions into native screens.
- Preserve the existing product identity by default. A polish request is not permission to replace typography, navigation, card artwork, content, or interaction patterns throughout the app.
- Reuse current `AppTheme`, `AppFonts`, and relevant shared widget variants. Resolve each token's actual role before reusing it; visual similarity alone does not justify consolidation.
- `docs/features/visual-refresh.md` records an in-progress direction, not proof that every proposed change has shipped. It explicitly excludes document/pass faces and bottom navigation. Check current source and owner decisions before extending its scope.
- Optional design skills provide methods, not a competing art direction. Do not apply blanket font/icon bans, random layout selection, mandatory glass/gradients, nested bezels, giant spacing, pills, or entrance animations.
- For visual quality claims, inspect rendered evidence when the task permits it. If only source was audited, state that limit. A token mismatch alone is not evidence of poor hierarchy, density, or overall design quality.
- Keep existing uncommitted work intact. Make one coherent scoped correction and verify the result; do not accumulate decorative changes to satisfy a skill checklist.

## CodeGraph

When `.codegraph/` exists, use `mcp__codegraph__codegraph_explore` before searching or reading indexed code. Discover that exact tool name when deferred. Use raw reads for documents, unindexed files, or source sections the graph did not return. Do not initialize or upgrade the index without a request.
