# Natural Earth masters — Journey globe

Source geometry for `assets/journey/atlas_v1.bin`. **Masters, not build inputs
of the app** — same posture as `tool/design_src/passport_covers/`. Nothing here
is bundled; only the generated binary ships.

Regenerate the atlas after touching either file:

```bash
python tool/generate_journey_atlas.py
```

## Files

| File | Source | Notes |
|---|---|---|
| `ne_110m_land.geojson` | [ne_110m_land](https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_land.geojson) | Verbatim. 1:110m land polygons. |
| `ne_50m_admin1_india_lines.geojson` | [ne_50m_admin_1_states_provinces_lines](https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_1_states_provinces_lines.geojson) | Filtered to `ADM0_NAME == "India"` (66 of 581 features) and stripped to two properties. The full global file is ~880KB for 66 lines we want. |

Natural Earth is public domain and requires neither permission nor attribution.
Credited anyway in `ATTRIBUTIONS.md` and in `lib/core/assets/asset_licenses.dart`.

## What the generator does with them

**The land polygons never ship in any form.** They exist only to answer one
question per sample point — land or ocean — for 42,000 points on a Fibonacci
sphere. What ships is the surviving ~12,100 points. That is why the asset is
53KB rather than megabytes, and why the globe has no coastline geometry to draw
at runtime.

Holes are subtracted after exteriors are tested, so inland water (the Caspian
above all) does not silently become a continent. `test/journey_atlas_test.dart`
probes for exactly that.

The India lines *are* real geometry, but Douglas-Peucker simplified at 0.02
degrees and quantised to int16 (~300m error, invisible at every zoom Journey
supports).

## Adding another country's regions

Filter the same admin-1 source on a different `ADM0_NAME`, drop it in here, and
extend `STATES_GEOJSON` in the generator to read both. Keep the filtering step —
committing the full global file to save one line of Python is a bad trade.
