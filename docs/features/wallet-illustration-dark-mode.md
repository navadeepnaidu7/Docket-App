# Wallet illustration dark-mode contrast

Status: implemented and checked on the connected phone, 29 October 2026.

Scope: improve the existing Manage reorder and Trash tray illustrations in dark
mode. Preserve their geometry, palette families, timing, and light-mode appearance.

The current artwork paints translucent white surfaces and low-opacity dark blue,
violet and teal details in both themes. Add a dark treatment using Docket's elevated
surface as a base, lighter versions of the existing tints for markings and rims,
and distinct front/back tray values so the stored cards remain readable.

Check both illustrations rendered in dark mode and confirm light mode still
matches. Use a temporary empty-Manage display override for the visual check,
then remove it; do not remove or alter saved documents to reach that state.
Use the connected Flutter hot-reload session. No automated tests or APK rebuild.

Implemented dark-only gradients over surfaceContainerHighest, lighter versions of
the existing blue/violet/teal markings, and tinted rims. The front tray has a
distinct darker surface so cards visibly move into and out of it. Light-mode
color formulas and the existing animation controllers/geometry remain unchanged.

Both illustrations were visually checked on the Motorola in dark and light mode.
Focused dart analysis reported No issues found; git diff --check passed. The
temporary empty-Manage override is removed, the normal ten-document list is back,
and the original Always light preference is restored. No document data was edited.
Reference captures are local ignored files under build/id-tools-review.

## Trash artwork refinement

Replace the shallow tray with a custom-drawn tapered wastebasket, a recessed mouth
and one recognizable ID card. The card slowly rises out and returns, reinforcing that
removed documents can be recovered. Retain the 220 by 164 footprint and the blue /
teal material family in both themes. Use a directly repainted CustomPainter for
the 5.4-second cycle, with a readable still frame for reduced motion. Check the
actual Trash screen in both themes; document storage and actions are outside scope.

Implemented as a directly repainted CustomPainter with a rounded, tapered basket,
three recessed ribs and an illustrated ID face. The final silhouette focuses on
the basket and ID, with no detached lid. Dark mode uses tinted graphite; light
mode uses pale frosted teal and blue. Reduced motion holds the raised-card frame.

The initial drawing was viewed on the phone in dark mode. Final source refinements
were hot reloaded successfully; the user requested finishing without another phone
check, so the final silhouette and light-mode rendering are not claimed verified.
No document actions or theme preferences were changed for this refinement.
