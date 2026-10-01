"""Export generated icon masters as alpha-preserving mobile assets.

Run from the repository root: python tool/export_pass_add_icons.py
The originals remain untouched in tool/design_src/pass_add_icons.
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
MASTERS = ROOT / "tool" / "design_src" / "pass_add_icons"
OUTPUT = ROOT / "assets" / "passes" / "add"
NAMES = ("train", "bus", "flight", "movie", "event", "more", "pnr", "photo", "pdf")


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name in NAMES:
        source = MASTERS / f"{name}.png"
        if not source.exists():
            raise FileNotFoundError(source)
        with Image.open(source) as original:
            image = original.convert("RGBA")
            if image.getchannel("A").getextrema() != (0, 255):
                raise ValueError(f"{name} must have a transparent background")
            image.thumbnail((512, 512), Image.Resampling.LANCZOS)
            target = OUTPUT / f"{name}.webp"
            image.save(target, "WEBP", quality=95, method=6, alpha_quality=100)
            print(f"{name}: {image.width}x{image.height}, {target.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
