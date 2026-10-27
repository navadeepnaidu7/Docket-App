<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

## Design work

For existing products, the user's direction and current repository design decisions take precedence over optional design skills and external examples. Preserve product identity and platform conventions unless a redesign is requested. Do not combine skills into a checklist of mandatory aesthetic treatments or randomize layouts for novelty. Use rendered evidence for claims about visual hierarchy, density, or polish; disclose source-only review limits. Distinguish small conformance fixes from changes that materially improve the user's task.
