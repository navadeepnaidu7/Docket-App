# Motion, navigation and responsiveness

The app-wide motion contract: shared curves, route transitions, back behaviour, and the
responsiveness fixes for gestures and repaint cost. Feature-specific motion lives with its
feature (weather in `weather-glance.md`, decks in `pass-deck.md` / `archive-pass-deck.md`,
startup in `startup.md`).

Owners: `lib/core/motion/smooth_curves.dart`, `lib/core/theme/app_theme.dart`
(`pageTransitionsTheme`), `lib/core/motion/studio_page_route.dart`,
`android/app/src/main/AndroidManifest.xml`. Tests: `test/motion_audit_test.dart`,
`test/home_tab_transition_test.dart`.

## Navigation policy

- **Android routes use `FadeForwardsPageTransitionsBuilder`** through the theme; Apple
  platforms keep Cupertino transitions. `studioPageRoute` is a `MaterialPageRoute`, so peer
  destinations follow the same policy instead of a separate rise animation. The older
  `FadeUpwardsPageTransitionsBuilder` plus a custom rise/fade was the source of the
  app-wide vertical screen motion; do not reintroduce either.
- Bottom sheets, popups and the morph sheet keep their own presentation.
- **Predictive back is disabled** (`enableOnBackInvokedCallback="false"`). Normal back and
  existing `PopScope` draft/overlay guards stay. The profile detail goes through
  `MaterialPageRoute` so Android applies the same policy.
- **IDs/Passes tab handoff**: both wallets keep state and lazy first mount; a brief
  crossfade with small translation, each wallet's paint isolated, and content, nav
  indicator and backdrop tint driven from one controller timeline. Rapid reversals continue
  from the current value; reduced motion drops lateral translation.

## Responsiveness rules (Oct 2026)

- Card tilt eases back from the live pose on release, can be interrupted by a new touch,
  leaves vertical swipes to the `PageView`, tracks one pointer (a second finger cannot flip),
  and respects reduced motion.
- The ID carousel keeps the focused document across list mutations (nearest survivor
  otherwise); explicit filter changes still start at the first card. Pages have stable keys;
  cached faces refresh when document data changes, even with the same id.
- Shine borders update focus only on page change, stop while scrolling, paint from
  animation listenables, and sit apart from the static card.
- Large base64 portraits decode on a background isolate with stale-result guards; small
  ones stay synchronous. (`compute` runs on the event loop on web; the gain is native-only.)
- Pass repositories and API clients select only repository/client configuration from dev
  flags, so a visual setting does not reload passes.

## Measuring

Frame claims need `flutter run --profile` on a physical phone, same wallet before and after:
cold entry, ten card swipes, rapid flips, Settings open/close, add/remove. Report UI and
raster p90/p99 and frames over budget (16.7 ms at 60 Hz, 8.3 ms at 120 Hz). Debug FPS is not
evidence. None of the items on this page has a profile-mode frame measurement yet.

---

## Audit, first bundle (findings 1, 2, 3, 5, 6)

An external motion audit read the ~60 motion-bearing UI files and raised 13 findings
plus 4 missed opportunities. The rest are listed at the bottom.

The diagnosis the bundle acts on: the intended personality is tactile and
Apple-adjacent, but the highest-frequency surfaces — the dashboard backdrop, the
carousel indicators and every passport/ID prompt step — carry ceremony sized for a
once-per-install moment.

## Shared decision: one strong ease-out

Finding 6 is the load-bearing one, because the other four inherit from it. Routine UI
exits across the app used `Curves.easeInCubic`, which starts slow — so a state change
visibly hesitates before leaving, on every tab switch, step advance and segmented-tab
change.

`strongEaseOut = Cubic(0.23, 1, 0.32, 1)` lands in `lib/core/motion/smooth_curves.dart`
next to the existing duration/curve tokens, and is used for **both** directions of a
switch. `stepSwitchDuration` (200ms) and `reducedSwitchDuration` (120ms) join it, so
the step-change timeline has one name rather than five hand-typed durations.

`easeOutQuint` in `core/motion/entry_reveal.dart` stays — it is the route-push and
progress curve, and `studio_page_route.dart` is not in scope here.

Two `easeInCubic` sites are deliberately left alone:

- `shared/widgets/morph_sheet.dart` — the audit excluded the bottom-anchored morph
  sheet as already well considered.
- `onboarding/.../accordion_step.dart` — a once-per-install flow, so "routine exit"
  does not apply, and it was not raised.

## Finding 1 — dashboard backdrop tickers (HIGH, performance)

`wallet_backdrop.dart` runs a 14s and a 30s `AnimationController` on `repeat()`, and
every tick rebuilds through `AnimatedBuilder` and repaints a full-screen canvas of six
viewport-scale blurred orbs plus a radial vignette.

The cost is fill rate and per-frame CPU, not the blur call itself — Impeller has an
analytic fast path for blurred circles, but six overlapping translucent full-screen
draws are still fill-rate bound on a phone GPU, and each rebuild re-runs
`WalletPalette.blended` (HSL round-trips) and `focusSignature` (a string allocation).

The fix is frequency, not appearance. **No orb geometry, colour or alpha changes**, so
the dashboard looks identical:

1. **Quantise the ambient clocks.** The two drifts are slow by design: at a 390px width
   the nearer orb travels ~20px/sec, so a 60fps tick advances it 0.3px. They now step
   at 20 Hz, so listeners are notified only when the value crosses a bucket. (Uncommitted
   work at the time of writing moves this from a quantised `AnimationController` to a
   timer, because a running controller requests a full frame every vsync even when nothing
   repainted; check `wallet_backdrop.dart` for the current class.) At the fastest point of the sweep that is ~1.6px of travel between steps —
   below what a blur that wide can show — and it cuts the full-screen
   rebuild-and-repaint rate 3x on a 60Hz panel and 6x on a 120Hz one.
2. **Keep finger-driven motion immediate.** `pageNotifier`, the tilt notifier and the
   tab tint controller are *not* quantised, so carousel scroll and card tilt still
   repaint every frame. Throttling those is what finding 2 is about; they must stay live.
3. **Freeze under reduced motion.** The tickers never start and both clocks hold 0, so
   the wash is a still image — and specifically the composition the first frame already
   paints, since the drift only begins 480ms in. Previously `disableAnimations` was
   ignored here entirely. A later toggle in either direction is honoured.
4. **Left alone deliberately:** per-paint `RadialGradient.createShader` for the
   vignette, and the three HSL round-trips for the analogous hues. Both are real work,
   but memoising them needs module-level mutable cache state, and at the new ~20
   paints/sec neither is measurable. Not worth the global.

Deliberately not done: pre-rendering the wash to a `ui.Image` and animating it with
transform/opacity, as the audit suggested. The six orbs drift on independent phases and
breathe on independent radii, so one cached bitmap cannot reproduce the motion — it
would have to become a different-looking backdrop, which is a design change, not a
motion fix.

## Finding 2 — indicators chasing the finger (HIGH, performance / interruptibility)

`dot_indicator.dart` and the private `_DotIndicator` in `tickets_tab.dart` are both
rebuilt from an `AnimatedBuilder` on a live `PageController`, so `page` already arrives
every frame. Wrapping that in a 200ms `AnimatedContainer` / `AnimatedPositioned` means
each frame retargets a tween that never finishes: the indicator lags the finger and
re-runs layout while doing it.

Size and opacity are now derived straight from the page position into a plain
`Container`, and the scroll pill moves under `Transform.translate` — paint-only, so a
drag no longer relayouts the `Stack` on every frame. Both files get the same treatment;
they are near-duplicates and the audit flagged them together.

## Finding 3 — prompt step ceremony (HIGH, purpose & frequency)

Every passport and ID prompt step layered: a 400ms `AnimatedSwitcher` (the audit said
240ms; the code said 400ms, so the finding understates it), a 320ms progress-bar
animation, and three 320ms `EntryReveal`s staggered 0/40/80ms inside the incoming body.
The input a user is about to type into was still arriving ~400ms after their tap, on a
screen they see once per field.

Now: one 200ms directional slide+fade on `strongEaseOut`, and the progress hairline
moves on the same 200ms timeline. The three nested reveals are gone — the switcher
already fades and slides the whole body, so per-element staggering was re-animating
content that was mid-entrance anyway.

The first step of a flow no longer self-animates, because `AnimatedSwitcher` does not
animate its initial child. That is correct: the route push transition is the entrance.

## Finding 5 — checkmark from nothing (HIGH, physicality)

`completion_celebration.dart` drove `ScaleTransition` directly off the success
controller, whose initial value is 0.0 — so the success checkmark inflated from
`scale(0)`, which nothing physical does. It now runs a `0.94 → 1.0` tween through the
same `bouncyCurve` spring, so it settles rather than inflates. The `AnimatedSwitcher`
around it already supplies the opacity entrance.

## Validation

- `flutter analyze`
- `flutter test`, including new coverage in `test/motion_audit_test.dart`:
  - the dot indicator and the passes `_DotIndicator` reach their derived size/offset in
    a single frame, with no settling tween
  - `WalletBackdrop` under `disableAnimations` settles instead of ticking forever
  - the success checkmark's scale never drops below 0.94
  - a prompt step's body is fully opaque within `stepSwitchDuration`
- Existing `passport_prompt_flow_test.dart`, `id_prompt_flow_test.dart` and
  `pass_action_bar_test.dart` cover the touched widgets and must stay green.

**Not verifiable from a dev machine, and not claimed:** the actual frame cost of the
backdrop change, and the felt quality of the shortened step transition. Both need a
physical device. The backdrop claim here is "repaints ~15x/sec instead of every frame",
which is what the test asserts — not a measured frame time.

## Still open from the audit

| # | Severity | Area |
|---|----------|------|
| 4 | HIGH | Home/Manage/Trash double crossfade — two 350ms switches, a 320ms bar slide, a delayed 280ms picker close |
| 7 | HIGH | `document_entry_scaffold` 280ms switch wrapping a second 480ms `EntryReveal` |
| 8 | MEDIUM | `pill_tab_bar` rebuilds whole bar per tick; 300ms tab vs 600ms backdrop tint |
| 9 | MEDIUM | Reduced motion handled in only two files — needs centralising |
| 10 | MEDIUM | ~~Card tilt snaps to zero on release~~ (fixed, see Responsiveness rules); 500ms flip is too long |
| 11 | MEDIUM | `BounceTap` symmetric timing; three pass cards duplicate press motion |
| 12 | MEDIUM | Attachment double-tap zoom discards input mid-tween |
| 13 | MEDIUM | `view_picker` starts at `scale(0.88)` |
| M1-M4 | — | State continuity: wallet, scanner, validation feedback, trash removal |

The curve token from finding 6 is the hook for most of those: 4, 7 and 8 are duration
and coordination work on switches that now share one curve.
