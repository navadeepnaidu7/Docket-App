# Bus card polish

Simplify the bus face by removing the generic boarding advisory and its closing
rule. Keep route, stops, date, departure, seat, boarding bay and fare visible.

All bus providers get coach artwork. Keep the existing redBus asset and palette;
use a distinctive, unbranded ivory-and-teal coach for the universal style,
including its expired variant. Reserve separate header bands for the provider,
coach and route so long names cannot run behind the artwork.

The new transparent PNG is generated with the built-in image generation tool.
Prompt: photorealistic premium studio render of an unbranded modern intercity
coach, platinum ivory body, subtle petrol-teal lower accent, smoked panoramic
windows, detailed chrome wheel, left-facing front three-quarter/side close-up,
cropped on the right, soft controlled lighting, clean alpha edges, no text,
logos, people, road or floor shadow.

Verification: bus face, responsive wallet and share-card tests; focused static
analysis; manual rendered preview of redBus, universal, long-name and expired
cards at wallet sizes.

Verified: 143 bus/wallet/share tests passed; after widening the date and
departure fields, 41 bus/share/preview tests passed. Focused analysis reported
no issues. Eight previews cover redBus, universal, long provider names and
expired cards at 382px and 288px widths, with no artwork/text overlap. Hardware
rendering has not been checked.

## Exact asset generation prompt

```text
Use case: product-mockup
Asset type: transparent decorative coach image for a premium mobile bus ticket card.
Primary request: Create one high-quality photorealistic studio product render of the front half of an unbranded modern intercity coach. Distinctive yet restrained, platinum ivory painted body with a subtle deep petrol-teal lower accent, dark panoramic smoked windows, crisp chrome wheel detailing and realistic rubber, elegant sculpted front and long curved side mirror. True transparent background.
Composition/framing: left-facing bus, mostly side view with a slight front three-quarter angle that shows the curved windshield and front face; front nose and mirror fully visible on left, one front wheel clearly visible near lower middle; bus continues beyond and is cropped by the right edge. Landscape approximately 1.4:1. Coach occupies almost the entire frame with minimal transparent margins. Vehicle stands level. Matches the visual clarity of a premium automotive catalogue, reads well when scaled to 230px wide.
Lighting/mood: soft broad studio key from above-left, controlled reflections, subtle highlights, strong separation against a dark teal UI panel. No ground plane or cast floor shadow.
Constraints: Exactly one bus, isolated clean alpha edges. No background, no road, no people, no text, no logos, no branding, no badge, no watermark. Precise coherent vehicle geometry. Rich material detail, premium finish, realistic rather than toy-like.
```
