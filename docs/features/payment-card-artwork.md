# Payment card artwork refinement

Scope: replace the decorative graphics on payment-card faces. Preserve every
bank's existing dark/light palette and accent hue, face typography, field
positions, bank/network marks, masking, reveal and stack interactions. Artwork
is an original Docket interpretation, not an official bank card reproduction.

## Evidence and direction

The rendered existing 15-face sheet repeats full-height lines, wavy bands and
concentric rings. Several banks differ mainly by the number and direction of
those strokes. The artwork also dissolves into the footer through a shared
gradient mask, making the different motifs feel similar.

Official references inspected:

- [Revolut cards](https://www.revolut.com/en-NL/cards/): broad directional
  reflections and large quiet surfaces make the physical material legible.
  Borrow controlled highlights and negative space; do not copy their wordmark,
  chip, exact card face or promotional background.
- [Wise cards](https://wise.com/gb/card/): the digital collection uses large
  cropped graphic areas and print texture rather than a field of uniform lines.
  Borrow the scale of composition, while keeping Docket's existing bank colors.
- Two focused UIZZE catalogue queries returned no reference results. No visual
  claims are based on catalogue metadata or unseen screenshots.

Design: static relief compositions with one dominant form, a deliberate edge,
and a small secondary accent. Three related treatments: curved sculptural relief,
inset/cropped geometry, and folded planes. Preserve bank-specific recognition
with curated motifs and placement, including gold on Canara's blue. Keep the
last-four number area quiet and protect the logo and footer through actual
composition. Limit fine engraving to a contained area; avoid full-height stripes,
box grids, gratuitous symbols, new product badges or added chips.

Render the real Flutter faces in dark/light palettes, at thumbnail size, and in
the stack. Keep a before sheet and publish a selectable before/after comparison.
No photograph or downloaded reference artwork is shipped in the app. Source
changes should remain in the payment-card painters; no persistence migration.

## Result and verification

Six related silhouettes now replace the eleven repetitive line patterns: sweep,
orbit, curved fold, arch, engraved lens and cut planes. The 23-bank registry
retains its exact accent colors; `card_surface.dart` and the card-face layout
were not edited. Shared directional lighting and fine edge highlights give the
forms depth without new bitmap assets, blur passes or animation work.

The first rendered pass showed HDFC's seam entering the expiry area and rigid
fold geometry. The seam now exits above the footer and the folded profiles are
curved. Inspected the revised 15-face gallery, both HDFC palettes, stack overview
and light detail screen. The existing all-bank decoding check covers all 23
marks on both palettes at wallet and thumbnail sizes.

58 targeted tests passed without updating baselines in the final run, including
network detection, masking/reveal, copy controls, entry, and the stack's 5/10/15
card cases. Scoped analysis is clean. Only affected visual baselines were
regenerated. The bank-gallery fixtures now explicitly wait for bundled fonts,
so targeted runs show the real typography instead of the test fallback face.

Review artifact: `build/card-art-references/artwork-comparison.html`, with 15
selectable before/after examples from real Flutter renders. Desktop dark and
mobile light HTML layouts were inspected. Source reference images and the old
sheet are kept only under `build/card-art-references/`; none are app assets.
ADB has no connected device, so this refinement has no physical-device check.
