"""Generate Docket Android launcher icons from the brand monogram.

Matches assets/branding SVGs:

- circle:  docket_logo_circle.svg  (inset monogram for round masks)
- square:  docket_logo_square.svg
- squircle:docket_logo_squircle.svg

Android 8+ adaptive icons: launcher applies circle/squircle/square mask.
We put the *circle* monogram on the adaptive foreground so circular
launchers match the circle SVG. roundIcon uses the full circle SVG.

Android-only — iOS icons are left untouched.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "android" / "app" / "src" / "main" / "res"
BRANDING_OUT = ROOT / "tool" / "icon_masters"

BG = (15, 23, 42, 255)  # #0F172A
WHITE = (255, 255, 255, 255)
TRANSPARENT = (0, 0, 0, 0)

# Monogram geometry from branding SVGs (viewBox 512).
# circle path:  M136 120 H250 C344 120 392 170 392 256 C392 342 344 392 250 392 H136 Z
#               hole cx=315 cy=256 r=22
# square path:  M120 104 H250 C355 104 408 160 408 256 C408 352 355 408 250 408 H120 Z
#               hole cx=324 cy=256 r=24
MONOGRAM = {
    "circle": {
        "start": (136, 120),
        "stem_bottom": (136, 392),
        "top_right_ctrl": ((344, 120), (392, 170), (392, 256)),
        "bot_right_ctrl": ((392, 342), (344, 392), (250, 392)),
        "mid_top": (250, 120),
        "hole": (315, 256, 22),
    },
    "square": {
        "start": (120, 104),
        "stem_bottom": (120, 408),
        "top_right_ctrl": ((355, 104), (408, 160), (408, 256)),
        "bot_right_ctrl": ((408, 352), (355, 408), (250, 408)),
        "mid_top": (250, 104),
        "hole": (324, 256, 24),
    },
}
# squircle uses the same monogram as square (only outer radius differs)
MONOGRAM["squircle"] = MONOGRAM["square"]
MONOGRAM["full"] = MONOGRAM["square"]


def _cubic(p0, p1, p2, p3, n: int = 64):
    out = []
    for i in range(1, n + 1):
        t = i / n
        u = 1 - t
        x = (
            u**3 * p0[0]
            + 3 * u**2 * t * p1[0]
            + 3 * u * t**2 * p2[0]
            + t**3 * p3[0]
        )
        y = (
            u**3 * p0[1]
            + 3 * u**2 * t * p1[1]
            + 3 * u * t**2 * p2[1]
            + t**3 * p3[1]
        )
        out.append((x, y))
    return out


def monogram_points(size: float, variant: str = "circle") -> list[tuple[float, float]]:
    m = MONOGRAM[variant]
    s = size / 512.0
    mid = m["mid_top"]
    c1, c2, c3 = m["top_right_ctrl"]
    b1, b2, b3 = m["bot_right_ctrl"]
    # path: M stem_bottom → start → mid_top → curve to (392/408,256) → curve to mid bottom → close
    stem_bottom = m["stem_bottom"]
    start = m["start"]
    pts: list[tuple[float, float]] = [stem_bottom, start, mid]
    pts += _cubic(mid, c1, c2, c3)
    pts += _cubic(c3, b1, b2, b3)
    return [(x * s, y * s) for x, y in pts]


def hole_params(size: float, variant: str = "circle") -> tuple[float, float, float]:
    cx, cy, r = MONOGRAM[variant]["hole"]
    s = size / 512.0
    return cx * s, cy * s, r * s


def draw_monogram(
    draw: ImageDraw.ImageDraw,
    size: int,
    variant: str,
    *,
    fill=WHITE,
    hole_fill=BG,
) -> None:
    draw.polygon(monogram_points(size, variant), fill=fill)
    cx, cy, r = hole_params(size, variant)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=hole_fill)


def _downscale(img: Image.Image, size: int) -> Image.Image:
    if img.size[0] == size:
        return img
    return img.resize((size, size), Image.Resampling.LANCZOS)


def make_full_icon(size: int, shape: str = "circle") -> Image.Image:
    """Rasterize a shaped icon. Renders 4x then downscales for smooth edges."""
    scale = 4 if size < 512 else 1
    canvas = size * scale
    img = Image.new("RGBA", (canvas, canvas), TRANSPARENT)
    draw = ImageDraw.Draw(img)

    # Prefer circle monogram (docket_logo_circle.svg) — inset for round masks.
    # Square monogram only when baking square/squircle outer shapes.
    if shape == "circle":
        draw.ellipse([0, 0, canvas - 1, canvas - 1], fill=BG)
        variant = "circle"
    elif shape == "squircle":
        r = max(1, int(canvas * 112 / 512))
        draw.rounded_rectangle([0, 0, canvas - 1, canvas - 1], radius=r, fill=BG)
        variant = "square"
    elif shape == "square":
        r = max(1, int(canvas * 64 / 512))
        draw.rounded_rectangle([0, 0, canvas - 1, canvas - 1], radius=r, fill=BG)
        variant = "square"
    else:
        # full-bleed adaptive/legacy base: circle monogram on solid navy
        draw.rectangle([0, 0, canvas - 1, canvas - 1], fill=BG)
        variant = "circle"

    draw_monogram(draw, canvas, variant, hole_fill=BG)
    return _downscale(img, size)


def make_adaptive_foreground(size: int) -> Image.Image:
    """Circle monogram on transparent — matches docket_logo_circle.svg.

    Adaptive background is solid navy; launcher mask supplies the outer shape.
    """
    scale = 4 if size < 512 else 1
    canvas = size * scale
    img = Image.new("RGBA", (canvas, canvas), TRANSPARENT)
    draw = ImageDraw.Draw(img)
    draw.polygon(monogram_points(canvas, "circle"), fill=WHITE)

    # Punch the counter hole (transparent) so adaptive bg shows through.
    hole = Image.new("L", (canvas, canvas), 0)
    hd = ImageDraw.Draw(hole)
    cx, cy, r = hole_params(canvas, "circle")
    hd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    r_ch, g_ch, b_ch, a_ch = img.split()
    a_ch = ImageChops.subtract(a_ch, hole)
    img = Image.merge("RGBA", (r_ch, g_ch, b_ch, a_ch))
    return _downscale(img, size)


def write_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG")
    print(f"  {path.relative_to(ROOT)} ({path.stat().st_size} bytes)")


def generate_android() -> None:
    print("Android icons (circle monogram from docket_logo_circle.svg):")
    fg_sizes = {
        "mipmap-mdpi": 108,
        "mipmap-hdpi": 162,
        "mipmap-xhdpi": 216,
        "mipmap-xxhdpi": 324,
        "mipmap-xxxhdpi": 432,
    }
    legacy_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    for folder, sz in fg_sizes.items():
        write_png(
            make_adaptive_foreground(sz),
            RES / folder / "ic_launcher_foreground.png",
        )

    for folder, sz in legacy_sizes.items():
        # Legacy: full-bleed navy + circle monogram (works under any system mask).
        write_png(make_full_icon(sz, "full"), RES / folder / "ic_launcher.png")
        # roundIcon: exact circle SVG (navy disc + circle monogram).
        write_png(make_full_icon(sz, "circle"), RES / folder / "ic_launcher_round.png")


def generate_masters() -> None:
    print("Master brand PNGs:")
    BRANDING_OUT.mkdir(parents=True, exist_ok=True)
    for shape in ("full", "square", "squircle", "circle"):
        write_png(
            make_full_icon(1024, shape),
            BRANDING_OUT / f"icon_{shape}_1024.png",
        )
    write_png(
        make_adaptive_foreground(1024),
        BRANDING_OUT / "icon_foreground_1024.png",
    )


def main() -> None:
    generate_masters()
    generate_android()
    print("Done (Android only).")


if __name__ == "__main__":
    main()
