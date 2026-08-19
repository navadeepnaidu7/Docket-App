"""Builds the Journey globe atlas: assets/journey/atlas_v1.bin.

The globe draws Earth's landmass as a field of points, not as filled polygons.
So coastline geometry is consumed *here*, offline, purely to decide which points
on a Fibonacci sphere are land -- and is then discarded. Nothing polygonal ships.
That keeps the runtime asset to a list of numbers, removes a whole class of
per-frame geometry work, and is why the binary is ~60KB rather than megabytes.

What ships:

  * land dots  -- evenly distributed sphere points that fell on land, sorted
                  into level-of-detail bands so the world view can draw a
                  coarse subset and the city view the full field.
  * state rings -- simplified India admin-1 boundary lines, drawn only once the
                  camera has descended past world level.

Both are quantised to int16. Max error is about 0.003 degrees (~300m), which is
invisible at every zoom Journey supports.

Sources, in tool/design_src/naturalearth/ (masters, never bundled):
  ne_110m_land.geojson
  ne_50m_admin1_india_lines.geojson
Both derive from Natural Earth, which is public domain. See ATTRIBUTIONS.md.

Usage:
    python tool/generate_journey_atlas.py

Writes assets/journey/atlas_v1.bin and, beside it but NOT bundled,
atlas_v1.debug.json -- a sidecar the decoder test asserts against so a silent
off-by-one in the binary reader cannot pass unnoticed.
"""

from __future__ import annotations

import json
import math
import os
import struct
import zlib

import numpy as np
from matplotlib.path import Path as MplPath

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
SRC = os.path.join(HERE, "design_src", "naturalearth")
OUT_DIR = os.path.join(REPO, "assets", "journey")

LAND_GEOJSON = os.path.join(SRC, "ne_110m_land.geojson")
STATES_GEOJSON = os.path.join(SRC, "ne_50m_admin1_india_lines.geojson")

MAGIC = 0x414A4B44  # 'DKJA' little-endian
VERSION = 1

# Points laid on the sphere before the land test. About 29% survive.
SAMPLE_COUNT = 42000

# Level-of-detail banding. A point's band is decided by its index modulo
# BAND_STRIDE, which works because striding a Fibonacci set preserves even
# spacing at every subset size -- taking "the first N" instead would clump them
# into a spiral.
BAND_STRIDE = 7
BAND_RULES = [
    lambda m: m == 0,           # band 0: 1/7 of points, the world view
    lambda m: m in (1, 2),      # band 1: +2/7, country and region
    lambda m: m >= 3,           # band 2: the rest, city view
]

# Douglas-Peucker tolerance for state outlines, in degrees.
SIMPLIFY_EPSILON = 0.02
MIN_RING_POINTS = 4

LAT_SCALE = 32767.0 / 90.0
LNG_SCALE = 32767.0 / 180.0


def quantise_lat(values):
    return np.clip(np.round(np.asarray(values) * LAT_SCALE), -32767, 32767).astype("<i2")


def quantise_lng(values):
    return np.clip(np.round(np.asarray(values) * LNG_SCALE), -32767, 32767).astype("<i2")


def fibonacci_sphere(count):
    """Evenly spaced points on a sphere, as (lat, lng) degrees."""
    i = np.arange(count, dtype=np.float64)
    # Golden-angle spiral. z is uniform in [-1, 1], which is what makes the
    # spacing even by area rather than by angle.
    z = 1.0 - (2.0 * i + 1.0) / count
    lat = np.degrees(np.arcsin(np.clip(z, -1.0, 1.0)))
    golden = math.pi * (3.0 - math.sqrt(5.0))
    lng = np.degrees(((i * golden) % (2.0 * math.pi)) - math.pi)
    return lat, lng


def load_land_rings(path):
    """Exterior and hole rings from a land polygon layer."""
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)

    exteriors, holes = [], []
    for feature in data["features"]:
        geometry = feature["geometry"]
        kind = geometry["type"]
        if kind == "Polygon":
            polygons = [geometry["coordinates"]]
        elif kind == "MultiPolygon":
            polygons = geometry["coordinates"]
        else:
            continue
        for rings in polygons:
            if not rings:
                continue
            exteriors.append(np.asarray(rings[0], dtype=np.float64))
            for ring in rings[1:]:
                holes.append(np.asarray(ring, dtype=np.float64))
    return exteriors, holes


def land_mask(lat, lng, exteriors, holes):
    """True where a sample falls on land.

    Tests membership of any exterior ring, then removes anything that also falls
    inside a hole -- lakes and inland seas are not land, and skipping the second
    pass puts dots in the middle of the Caspian.
    """
    points = np.column_stack([lng, lat])
    inside = np.zeros(len(lat), dtype=bool)

    for ring in exteriors:
        # Bounding box first: most samples are ocean and fail this immediately,
        # which is what keeps a 42000 x 130-ring test tractable.
        lo_x, lo_y = ring[:, 0].min(), ring[:, 1].min()
        hi_x, hi_y = ring[:, 0].max(), ring[:, 1].max()
        candidate = (
            ~inside
            & (points[:, 0] >= lo_x)
            & (points[:, 0] <= hi_x)
            & (points[:, 1] >= lo_y)
            & (points[:, 1] <= hi_y)
        )
        if not candidate.any():
            continue
        hit = MplPath(ring).contains_points(points[candidate])
        idx = np.flatnonzero(candidate)
        inside[idx[hit]] = True

    for ring in holes:
        lo_x, lo_y = ring[:, 0].min(), ring[:, 1].min()
        hi_x, hi_y = ring[:, 0].max(), ring[:, 1].max()
        candidate = (
            inside
            & (points[:, 0] >= lo_x)
            & (points[:, 0] <= hi_x)
            & (points[:, 1] >= lo_y)
            & (points[:, 1] <= hi_y)
        )
        if not candidate.any():
            continue
        hit = MplPath(ring).contains_points(points[candidate])
        idx = np.flatnonzero(candidate)
        inside[idx[hit]] = False

    return inside


def douglas_peucker(points, epsilon):
    """Recursive polyline simplification on an (N, 2) array."""
    if len(points) < 3:
        return points

    start, end = points[0], points[-1]
    segment = end - start
    length_sq = float(segment[0] ** 2 + segment[1] ** 2)

    if length_sq == 0.0:
        distances = np.hypot(points[:, 0] - start[0], points[:, 1] - start[1])
    else:
        t = np.clip(((points - start) @ segment) / length_sq, 0.0, 1.0)
        projected = start + t[:, None] * segment
        distances = np.hypot(
            points[:, 0] - projected[:, 0], points[:, 1] - projected[:, 1]
        )

    index = int(np.argmax(distances))
    if distances[index] <= epsilon:
        return np.vstack([start, end])

    left = douglas_peucker(points[: index + 1], epsilon)
    right = douglas_peucker(points[index:], epsilon)
    return np.vstack([left[:-1], right])


def load_state_rings(path):
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)

    rings = []
    for feature in data["features"]:
        geometry = feature["geometry"]
        if geometry["type"] == "LineString":
            parts = [geometry["coordinates"]]
        elif geometry["type"] == "MultiLineString":
            parts = geometry["coordinates"]
        else:
            continue
        for part in parts:
            ring = np.asarray(part, dtype=np.float64)
            if len(ring) < MIN_RING_POINTS:
                continue
            simplified = douglas_peucker(ring, SIMPLIFY_EPSILON)
            if len(simplified) >= MIN_RING_POINTS:
                rings.append(simplified)
    return rings


def build():
    lat, lng = fibonacci_sphere(SAMPLE_COUNT)
    exteriors, holes = load_land_rings(LAND_GEOJSON)
    mask = land_mask(lat, lng, exteriors, holes)

    index = np.arange(SAMPLE_COUNT)
    band_of = np.full(SAMPLE_COUNT, len(BAND_RULES) - 1, dtype=np.int32)
    modulo = index % BAND_STRIDE
    for band, rule in enumerate(BAND_RULES):
        band_of[np.array([rule(int(m)) for m in modulo])] = band

    land_lat = lat[mask]
    land_lng = lng[mask]
    land_band = band_of[mask]

    # Sort by band so every level of detail is a contiguous prefix and the
    # painter can draw bands 0..n by slicing rather than filtering.
    order = np.argsort(land_band, kind="stable")
    land_lat, land_lng, land_band = land_lat[order], land_lng[order], land_band[order]

    band_offsets = [int(np.searchsorted(land_band, b, side="right")) for b in range(len(BAND_RULES))]

    rings = load_state_rings(STATES_GEOJSON)

    payload = bytearray()
    payload += struct.pack("<IHH", MAGIC, VERSION, 0)
    payload += struct.pack("<I", len(land_lat))
    payload += struct.pack("<B3x", len(BAND_RULES))
    for offset in band_offsets:
        payload += struct.pack("<I", offset)
    # Reserved for a spherical-cell index. Written as zero now so that adding
    # one later cannot force a format bump and an asset regeneration.
    payload += struct.pack("<I", 0)
    payload += quantise_lat(land_lat).tobytes()
    payload += quantise_lng(land_lng).tobytes()
    payload += struct.pack("<I", len(rings))
    for ring in rings:
        payload += struct.pack("<H", len(ring))
    for ring in rings:
        payload += quantise_lat(ring[:, 1]).tobytes()
    for ring in rings:
        payload += quantise_lng(ring[:, 0]).tobytes()
    payload += struct.pack("<I", zlib.crc32(bytes(payload)) & 0xFFFFFFFF)

    os.makedirs(OUT_DIR, exist_ok=True)
    binary_path = os.path.join(OUT_DIR, "atlas_v1.bin")
    with open(binary_path, "wb") as handle:
        handle.write(payload)

    # Not bundled. The decoder test asserts against these counts, so a binary
    # reader that is quietly off by one fails loudly instead of drawing a
    # plausible-looking but wrong planet.
    debug = {
        "sampleCount": SAMPLE_COUNT,
        "dotCount": int(len(land_lat)),
        "bandOffsets": band_offsets,
        "ringCount": len(rings),
        "ringVertexTotal": int(sum(len(r) for r in rings)),
        "landFraction": round(float(mask.mean()), 6),
    }
    with open(os.path.join(OUT_DIR, "atlas_v1.debug.json"), "w", encoding="utf-8") as handle:
        json.dump(debug, handle, indent=2)

    print(f"dots      {len(land_lat)} of {SAMPLE_COUNT} ({mask.mean():.1%} land)")
    print(f"bands     {band_offsets}")
    print(f"rings     {len(rings)} ({debug['ringVertexTotal']} vertices)")
    print(f"written   {binary_path} ({len(payload) / 1024:.1f} KB)")


if __name__ == "__main__":
    build()
