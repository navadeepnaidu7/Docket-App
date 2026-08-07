# Parallel work: status

**Status: CLOSED** (as of 7 Aug 2026). Both parallel features shipped and
merged into `master`. This file is kept as history of the branch contract so
future dual-track work can reuse the same rules.

## Closed tracks

| Track | Branch | Outcome |
|---|---|---|
| Movie posters | `feat/movie-poster-rendering` | Merged via PR #3 |
| Prompted entry flow | `feat/prompted-entry-flow` | Merged via PR #5 + #6 |

Shared prerequisites that both tracks depended on:

- `16733a7` — suite termination (`widget_test` no longer hangs the whole run)
- `f21d042` — pure-logic groundwork for the entry flow

## Historical branch diagram

```
master (then 34c6038)
  └── 16733a7  test: make the suite terminate      ← shared prerequisite
        └── f21d042  pure-logic groundwork          ← shared prerequisite
              ├── feat/movie-poster-rendering       6540442  ✓ merged
              └── feat/prompted-entry-flow          …       ✓ merged
```

Both feature branches descended from the **same two commit objects**. Merge
order did not matter; verified 2 Aug 2026 with zero conflicts.

## Working rules (reuse for the next dual track)

1. **Never commit from a shared working tree without a pathspec.** Stage
   explicitly or use `git commit -- <paths>`.
2. **Rebase onto shared prerequisites, not onto the other feature branch.**
3. **Run the whole suite before pushing.**
4. **Own disjoint path sets.** Contended files only with additive edits.
5. **Document by appending**, never rewrapping paragraphs you did not write.

When starting a new pair of features, replace this section with a live branch
diagram and a file-ownership table. Mark the previous tracks closed above.
