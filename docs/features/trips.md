# Trips — issue #38 design proposal

Status: proposal for discussion; user direction is visual/text balance, integrated saved IDs, and an automatic, magical feel. Detailed implementation remains proposed.
Issue: https://github.com/navadeepnaidu7/Docket-App/issues/38
Reviewed: 2026-10-29; app HEAD 359b2be, server HEAD 917e463, including current local source.
Evidence: source review, not a rendered audit of the current Flutter app. The companion HTML is a conceptual wireframe with fictional data, not a production screenshot.

The initial `trips-concept.html` predates the user's visual-first clarification below; it is a structural exploration, not the current visual target.

## Product direction

Trips answers three questions: What is happening next? How do these bookings fit together? Which saved document should I have ready?

Keep the tab name Trips from the issue. Within it, use human titles such as “Your Bengaluru weekend” and “Movie night” so a single outing does not need to masquerade as a multi-day holiday. Keep original passes and IDs in their existing wallets; a trip references them rather than moving or copying documents.

## Look and feel

Preserve AppFonts.ui (Geist), AppTheme neutral paper/graphite surfaces, existing ticket artwork, native navigation and sheet conventions. Use the existing gold/amber accent for Trips; resolve it through theme tokens. Do not redesign IDs or Passes.

The existing bottom pill gains a third, trailing Trips destination when there is a dated, eligible upcoming or ongoing outing. A valid single pass is enough; having an ID is not a prerequisite. Missing documents should be visible inside the trip. Distant bookings remain in Trips once detected; highlight only genuinely new groupings, not every date change.

On first discovery, gently expand the pill and briefly illuminate the Trips icon. Keep a distinct accent afterward, with a small “new” indicator until visited. Avoid perpetual pulsing. Respect reduced motion, readable labels and the app's label preference. Never navigate automatically. Defer topology changes until a gesture/transition is finished and preserve the current destination by identity rather than index.

Keep Trips visible during refresh, temporary errors, and while the user is viewing it. Once all outings finish, show a completion state for 24 hours (proposed default), then remove the destination at a safe dashboard entry. Past trips stay reachable from Archive. This requires trip-history access, not just the existing category-based pass archive.

## Screen structure

1. **Trips overview:** a natural title, dates and at most one short contextual sentence per outing. Familiar ticket artwork and a compact saved-ID preview do most of the communication. Nearest outing first, later outings below. Do not repeat times, destinations or counts in prose when already visible on the cards. One trip should still have a predictable overview route, with its next action available immediately.
2. **Trip detail:** put the next ticket and its useful saved ID together near the top, both individually tappable. Reuse recognizable document/pass artwork with a compact preview treatment; do not shrink full cards until their text becomes unreadable. Keep document numbers and birth dates out of these previews. Multi-day trips continue into a compact, day-separated timeline; a single movie outing needs no elaborate timeline. A shared ID appears once in the active group and remains available as the next leg changes. Finished bookings retain quieter chronological context.
3. **Booking actions:** tap an event to open the existing train/movie/bus detail. A direct “Show ticket” action can open its existing code/detail presentation. Only show code actions when an actual decoded code exists. Tap a document to open its existing protected viewer, returning to the same trip and scroll position.
4. **Corrections:** an overflow sheet offers rename, add/remove booking, split trip, merge selected trips, choose/change document, and dismiss suggestion. Explain automatic choices through “Why these are together”. Removing a booking from a trip does not delete it from the wallet.

Example travel copy (fictional): title “Bengaluru this weekend”; contextual line “An overnight ride, then the weekend ahead.” Cards carry the actual departure, arrival and return information. Only claim a return if endpoints and chronology support it. Do not infer a hotel, home address, activities between bookings, or connection feasibility.

Example movie copy: title “Movie night”; contextual line “Your ticket and age ID, together.” Use that line only when an appropriate saved ID has actually been linked. The ticket shows the time and venue; the nearby ID preview opens the saved document. With no match, use a compact “Choose an ID” slot. The explanation “Suggested for age verification” belongs behind a tap or in the change-ID sheet. This is a preparation suggestion, not a claim about a venue's entry policy or acceptance of a digital copy.

### What makes it feel automatic

The useful result should be present on first entry: the right bookings assembled, an existing ID placed alongside where matching is confident, and the next ticket immediately reachable. No create-trip wizard or repeated confirmation for clear matches. Ask only at the point of genuine ambiguity; remember corrections.

Express discovery with one restrained reveal of the assembled group and the tab accent. Do not replay the reveal on ordinary refreshes. As time advances, update the next-action emphasis without rearranging the screen under an active interaction. Keep explanations and management actions behind taps; bring missing or uncertain information forward only when actionable. Avoid AI badges, ongoing shimmer, explanatory paragraphs and duplicate status labels. The magic comes from useful preparation, recognizable personal cards and continuity.

## Grouping and document rules

Use deterministic rules on-device first. Natural language does not require a generative service: template fragments can compose accurate, varied summaries from verified fields, immediately and offline.

- Normalize passes into typed events with optional start/end instants, timezone context, origin/destination identities, passenger information, source pass ID and evidence/provenance. Unknown stays unknown. Display fallback text must not become matching evidence.
- Auto-create an outing from a clearly dated pass. Keep ambiguous dates visible as “Check date” candidates without claiming a chronological position. Ignore cancelled/deleted/trash items; distinguish finished legs of an ongoing trip from unrelated historical passes.
- For multi-booking trips, require compatible time order plus supported location continuity and compatible traveller evidence. Date proximity alone is insufficient. Conflicting traveller identities prevent auto-merging. Missing or fuzzy identity/location evidence produces a suggested merge, not a silent merge.
- Proposed initial candidate limits: adjacent transport legs within 24 hours; a clearly reversed outward/return route within 7 days. These bound candidates, not proof of one trip. Validate against actual fixtures before making them final defaults. Preserve manual grouping beyond either window.
- A cinema booking joins a travel trip only with supported city/time overlap and no conflicting evidence; otherwise keep “Movie night” separate or suggest a link. Never infer a city from an arbitrary substring of an address.
- Recommend one suitable saved ID per relevant traveller. Automatically reference it only when the identity match is unambiguous or the user previously selected a default. Movies often lack attendee identity; ask the user to choose if several document holders are available. Show a concise reason and an easy change action.
- Match locally; never upload ID numbers, birth dates, passport images or document attachments for trip generation. Do not auto-link every ID. Missing/expired/ambiguous documents get a suggestion state, not a “ready” claim.
- Explicitly extracted A certification can trigger the age-ID suggestion. Missing certification must be unknown. Do not infer rating from a movie name or treat the parser's current UA fallback as evidence.
- Persist manual edits, exclusions, dismissed suggestions and stable trip IDs. A refresh must not recreate a dismissed trip or undo a split. Reconcile additions/removals against overrides and retain stable identity as new passes arrive.

## State coverage

| State | Experience |
| --- | --- |
| No eligible passes | Existing two-destination wallet; no empty Trips advertisement |
| First trip discovered | Trips appears without stealing focus; one-time accent reveal |
| Loading local records | Wait for pass and document hydration before matching |
| Refresh/offline | Retain cached trips and documents; show last updated time for stale pass data |
| No cached passes | Clear retry state, not fabricated trips or a claim of offline availability |
| Missing document | “Choose an ID” / “Add an ID”; ticket remains usable |
| Missing time or location | “Check date” or separate outing; no invented connection |
| Conflicting bookings | Flag overlap without declaring a connection safe/unsafe |
| Mid-trip | Next actionable leg promoted; previous legs preserved |
| Deleted document | Remove its shortcut and explain it is unavailable |
| Ended trip | Brief completed state, then trip history in Archive |

## Repository findings and implementation owners

- `lib/core/theme/app_theme.dart`: current Geist and neutral palettes with warm accent. Historical CLAUDE/current_state palette and supported-category notes lag current source.
- `lib/features/dashboard/presentation/dashboard_screen.dart`: TabController length 2 at line 150; `_HomeTabTransition` is hard-coded to two children and clamps animation to 0..1. Generalize the shell, add-action routing and transition semantics, not just the tab label.
- `lib/features/dashboard/presentation/widgets/pill_tab_bar.dart`: 232px pill, half-width active highlight, binary selection progress. Support a responsive third segment with adequate targets; handle controller replacement/listener ownership safely when destination count changes.
- `lib/features/tickets/domain/pass_catalog.dart`: actual current wallet supports train, movie and bus. Flights/hotels are not part of the mapped Flutter wallet and belong to a later expansion.
- `ticket_models.dart` and `bus_pass_models.dart`: optional departAt/arriveAt plus display dates and route/passenger fields. Use real ISO timestamps where present and explicit timezone handling, not lexical date sorting.
- `movie_pass_models.dart`: optional showAt and certification, but missing certification currently becomes UA (constructor and parser). Introduce explicit unknown/provenance before rules rely on this field; review existing visual fallback consumers separately.
- `lib/features/tickets/data/remote_pass_repository.dart` and `application/pass_list_provider.dart`: inspected fetch/state path is network-backed with in-memory retention; durable offline pass availability is not established. Audit the underlying API path and add account-scoped encrypted cache if absent. Clear/scope it on logout and source/account changes; do not mix fixtures with real data.
- `id_list_provider.dart`, passport list provider and SecureDocumentStore: reuse existing local document owners and load-completion/error safeguards. Trips must not interpret a failed or unfinished read as confirmed absence.
- Server `internal/service/pass_mapper.go`: maps train/movie/bus, timestamps and optional movie certification. The mapper has presentation fallbacks (for example movie seat A1); grouping and summary adapters must not treat fabricated display defaults as verified booking facts. Add provenance or omit unknowns for fields used by Trips.
- Server `internal/domain/ai.go`: extraction DTOs are the starting point for any additive normalized location/time/confidence metadata. Validate in services and expose through the existing passes contract. The local matcher does not require a new trips endpoint in v1.

Proposed new Flutter feature: `lib/features/trips/{domain,application,presentation}`. Domain owns event normalization, grouping, document suggestions and summary composition; application owns Riverpod derivation and encrypted persistence of overrides/cache; presentation owns overview, detail and correction sheets. Derive from the complete relevant pass set, not only activePassesProvider, so an ongoing trip retains its finished outbound leg. Use stable references to local documents and source passes.

## Delivery sequence

1. **Validate the experience:** review overview/detail mockups with a single movie, a train-and-bus weekend, ambiguous unrelated bookings, and no saved ID. Check dynamic navigation at small widths and large text.
2. **Build the trustworthy core:** normalized event adapters, explicit unknowns, deterministic grouping, local document suggestions, stable IDs and persisted overrides. Add any needed server contract fields first.
3. **Ship the useful surface:** dynamic tab, summaries, timeline, existing ticket/document viewers, correction sheet and trip archive. Verify offline cold start/cache and error behavior before promising availability while travelling.
4. **Expand after usage:** richer location normalization, flights/hotels once their pass support exists, optional language variants. Consider a generated summary only if templates prove limiting; grouping and facts remain deterministic and IDs remain local.

Verification for implementation: unit fixtures for overnight journeys, timezone boundaries, unknown dates/ratings, multi-person bookings, false merges, cancellation, manual split/dismiss persistence and reruns; widget tests for third-tab appearance/removal and selected-tab preservation; on-device cold-start offline access, returning from ticket/ID viewers, theme/reduced-motion/large-text checks. No runtime changes or tests are part of this planning task.

## Decisions to discuss

Recommended starting direction: warm-accent Trips tab, restrained narrative overview, chronological detail, rules-based local intelligence. The key product decision is how automatic multi-pass grouping should be: this proposal automatically groups only well-supported matches and presents uncertain links as suggestions. Time windows and completed-trip retention above are proposed defaults to tune, not settled requirements.
