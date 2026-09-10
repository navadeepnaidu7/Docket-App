# Docket sky asset

`docket_sky.png` is the retired first-pass reference, generated with the built-in image generation tool. It is no longer bundled or displayed. The current scene is rendered procedurally by `assets/shaders/docket_sky.frag`: evolving clouds, directional sunlight, dusk/moonlight, and two layers of fine drizzle.

Prompt: Create a production background texture for a premium mobile app, landscape 1536x1024. Photorealistic atmospheric blue sky, soft volumetric cumulus clouds drifting across the upper right and top edge, silver sunlight delicately illuminating wispy edges, rich cobalt blue at top graduating to quiet desaturated deep marine blue lower half. Real Apple Weather-like atmospheric rendering, photographic cloud detail, restrained serene natural daylight. Lower left and central lower half mostly clear blue negative space for white UI text. No horizon, land, buildings, sun disk, text, icons, phone, frame, or interface. Full bleed sky only.

The runtime follows local time and varies sunlight/drizzle by calendar day. This is ambient scenery, not live weather data. Reduced motion freezes the scene; the animation is only mounted while the drawer is exposed. The shader program is warmed once after the first dashboard frame.

To compare scenes, pull down the dashboard and tap **Scene** at the upper right. Choose Auto, Sunlight, Light rain, Sunset, or Night. The dashboard remembers this override until it is recreated; Auto restores the calendar/time selection. Changing a scene blends its lighting over 800ms without restarting the cloud clock. The greeting always follows the real local time.

The nearer cloud bank drifts at roughly 6px/sec at a 390px width, with slower distant haze and independent billowing. Sunlight includes a broad halo, evolving light shafts, and silver cloud edges; passing clouds attenuate the light. This is a custom atmospheric approximation, not Apple's renderer.
