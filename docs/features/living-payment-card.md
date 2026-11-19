# Living payment card — atmospheric satin study

## Intent

The user wants the card material itself to feel alive, replacing printed line
motifs and graphics with atmospheric color and responsive light. The
motion proposal was approved through an interactive HTML study and is now
implemented in Flutter.

One direction: **atmospheric satin**. Keep each bank's familiar base color and
its accent as light within the material: navy/coral for HDFC, blue/gold for
Canara, cobalt/cyan for SBI. Keep the bank/network marks, number masking and
existing type roles. The details remain fixed relative to the face; only the
surface lighting and slight physical card response move.

## Motion contract

Purpose: touch feedback and active-card state indication. This is a frequently
seen financial surface, so the requested ambient motion is confined to the
background of the active card. Information does not animate independently.

- Slow continuous changes in diffuse colored light, over roughly 16–24 seconds.
  This long ambient cycle is explicitly requested; it is separate from quick
  interface feedback. No flashing, particles, orbiting objects or moving text.
- Touch/hover moves a broad reflection and gently tilts the face. Spring values
  reuse the existing membership card's mass 1, stiffness 180 and damping 27.
  Retarget from current position/velocity; release settles without a jump.
- Touch-down increases the local light immediately; release fades it back.
- Bank-palette demonstration crossfades in 200ms using Docket's strong ease-out.
- Reduced motion freezes ambient movement and tilt, retaining color feedback.
  Pause and off-screen/background states stop the prototype's idle motion.

The prototype uses composited gradient layers, transforms and opacity, with
bundled Geist/Roboto Mono and existing brand artwork. No animation framework,
web dependency, network API, new art asset, or photograph is needed.

## Native implementation plan

1. Build a material owner behind the existing `WalletPaymentCard` contents;
   replace the static motif painter. Preserve number/CVV security behavior.
2. Prototype native lighting with bounded gradients and `CustomPainter(repaint:)`,
   so the label tree and bank SVGs do not rebuild on every frame. Profile that
   version before deciding whether a fragment shader is justified.
3. Pass active/selected state from the wallet and stack. Animate just the active
   full face. Resting/off-screen cards use a stable material frame; app lifecycle
   and route coverage pause ticks. Do not run 15 independent ambient controllers.
4. Observe touch through `Listener`, allowing the current tap-to-open,
   tap-to-reveal, long-press and stack swipe recognizers to keep ownership. Add
   no competing drag recognizer just for the material response.
5. Blend the lighting into the current lift/switch transition over 200ms. Keep
   card-switch spring timing; the surface accent should settle with the card.
6. Verify contrast at the brightest/darkest animation phases, secure reveals,
   rapid selection, reduced motion, background pauses, and 5/10/15-card decks.
   Measure frame timing and battery impact on the connected phone before making
   any performance claim. Reuse the running hot-reload session for Dart changes.

Deliverable for this stage: a self-contained motion study under
`build/card-live-study/atmospheric-satin.html`, shown inline for feel review.

## Study verification (before native implementation)

Inspected desktop dark and mobile light renders. Scripted HTML checks exercised
palette switching, pause state and its accessible label, reduced motion disabling
ambient movement and tilt, and a pointer spring producing a nonzero pose and
reflection. No console assertion failures were reported. Initial and 8-second
surface phases were rendered to inspect the moving light beneath stationary
details. Header/footer shading and an opaque small card-type label protect the
text from the brightest part of the reflection. Pause freezes ambient motion
and tilt; reduced motion keeps only brief color feedback.

This verifies the web motion study, not Flutter runtime performance. No native
source file was edited and the running phone session was left alone. Frame rate,
battery cost and gesture coexistence remain native implementation checks.

## Native implementation — November 18, 2026

`LivingCardMaterial` now owns the ambient clock, spring tilt and touch light.
`CardMaterial` paints diffuse elliptical light in the saved bank palette,
followed by header/footer shading, reusable satin grain and the fine edge.
The old line/relief motifs are no longer painted on payment card faces.
No new package, shader or art asset was added.

The wallet enables the active full face, the deck enables its selected pinned
face, and details enable their visible face. Resting deck cards have a stable
material frame. Motion stops on route coverage, hidden tabs, lifecycle changes
and scrolling out of view. A selected deck face uses the deck's pinned ownership
rather than the scrolling content's bounds. Reduced motion retains brief touch
color feedback without ambient movement or tilt. Information and brand marks
have a retained repaint boundary separate from the ambient painter.

Validation: 66 targeted card tests passed, including secure reveal, long press,
route/lifecycle/viewport pauses, retained content, reduced motion, rapid changes
of the active clock, and every card reachable in 5/10/15-card decks. Updated
native goldens cover existing screens and dark/pearl materials at resting and
eight-second phases. Targeted analysis of changed source and tests is clean.
Full-repository analysis still reports pre-existing issues in saved Dart copies
under `build/` and unrelated lint notices.

Hot reloaded 17 libraries onto the Motorola Edge 30 in 8.181 seconds, using the
existing wireless session. Inspected the actual selected face, changed cards by
swipe, opened details and returned to the retained selection. Two captures of
the selected Canara face confirmed its material changes over time. Number and
security-code values were left masked during phone inspection. The live session
remains running. Release frame timing and battery impact have not been measured.
