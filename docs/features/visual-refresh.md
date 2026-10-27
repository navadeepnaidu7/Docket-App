# Visual refresh — "indie Apple" direction

Status: in progress (branch `visual-refresh`).

## Why

Audit of the app on device (Oct 2026) against a reference the owner liked (CRED Circle
onboarding: calm off-white page, one rich gradient card, a black full-width pill, two-tone
headline, almost no icons):

- Every tab painted the whole screen in a saturated wash (navy for IDs, maroon/peach for
  Passes), so the card competed with its own background.
- 179 Material `Icons.*` in mixed filled/outlined styles; every Settings row carried one.
- Primary buttons were small and low-contrast (grey pill on navy, navy pill on peach).
- Inter at default settings everywhere; Geist and Instrument Serif were bundled but unused
  outside the train face. Many widgets hardcode `TextStyle` colors instead of theme tokens.

## Direction

1. **Colour lives in the cards.** Pages are neutral (light `#F4F4F2`, dark `#0B0B0C`). The wallet
   backdrop keeps a soft halo tinted by the focused card, but no full-screen tab colour.
2. **Ink is the primary colour.** Primary CTA = full-width ink pill (black on light, white on
   dark), 56dp, Geist SemiBold 16. Secondary = text button. Press = scale 0.97 + haptic.
3. **Type: Geist** for all chrome. Two-tone headlines (muted line + ink line). Small-caps
   tracking labels for metadata. Card faces keep their own type systems.
4. **Fewer icons.** Settings rows drop leading icons. Remaining icons are monochrome.
5. **Motion.** Staggered entry on empty states; presses scale instead of rippling.

## Out of scope for the first pass

**Not touched, by owner decision:** document card faces (passport, PAN, Aadhaar),
pass faces (train/bus/movie) and the bottom navigation bar. The refresh is about
the UI elements around them — colour, type, buttons, sheets, lists, empty states. Onboarding and entry flows
inherit the token changes but get no layout work yet.
