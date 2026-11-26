"""Generate the Docket app icon (v5) for Android and the bundled branding.

Renders tool/design_src/docket_icon/layers.html with headless Chrome or Edge
(transparent background, 2x) and writes:

- android/app/src/main/res/mipmap-*/ic_launcher_{foreground,background}.png:
  the adaptive layers, 108dp at each density. The launcher applies its own mask
  (circle, squircle, rounded square, teardrop, cookie). The door and lock stay
  inside the 66dp safe zone, so no mask clips them.
- android/app/src/main/res/mipmap-*/ic_launcher{,_round}.png: legacy icons.
- android/app/src/main/ic_launcher-playstore.png: 512px Play listing icon.
- assets/branding/docket_icon.png: 512px full-square icon bundled in the app.
- tool/icon_masters/: 1024px masters of each layer and the composite.

The monochrome (themed icon) layer and the notification icon are hand-written
vector drawables and are not touched here. Set CHROME to the browser binary if
it is not installed in a standard location.

Android-only: iOS icons are left untouched.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tool" / "design_src" / "docket_icon" / "layers.html"
RES = ROOT / "android" / "app" / "src" / "main" / "res"
PLAY = ROOT / "android" / "app" / "src" / "main" / "ic_launcher-playstore.png"
BRANDING = ROOT / "assets" / "branding" / "docket_icon.png"
MASTERS = ROOT / "tool" / "icon_masters"

DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

BROWSERS = [
    os.environ.get("CHROME", ""),
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    shutil.which("google-chrome") or "",
    shutil.which("chromium") or "",
]


def _browser() -> str:
    for path in BROWSERS:
        if path and Path(path).exists():
            return path
    raise SystemExit("No Chrome or Edge found; set CHROME to the browser binary.")


def render(layer: str, css_px: int, out_dir: Path) -> Image.Image:
    """Render one layer (bgonly, fgonly, all) at 2x the given CSS size.

    The master is sized in vw for viewing; headless Chrome's viewport is not
    exactly --window-size, so a copy pinned to px is rendered instead. A vw
    render scales the foreground against the background and drifts the door.
    """
    page = out_dir / f"layers_{css_px}.html"
    page.write_text(SRC.read_text(encoding="utf-8").replace("100vw", f"{css_px}px"), encoding="utf-8")
    out = out_dir / f"{layer}_{css_px}.png"
    subprocess.run(
        [
            _browser(),
            "--headless=new",
            "--disable-gpu",
            "--hide-scrollbars",
            "--default-background-color=00000000",
            "--force-device-scale-factor=2",
            f"--window-size={css_px},{css_px}",
            f"--screenshot={out}",
            f"{page.as_uri()}#{layer}",
        ],
        check=True,
        capture_output=True,
        timeout=120,
    )
    return Image.open(out).convert("RGBA")


def check_door(fg: Image.Image) -> None:
    """Fail if the door is not where the 1024 grid puts it on the 108dp canvas.

    The door spans x 262-786 and y 232-792 on the 1024 icon grid, which sits in
    the 72dp visible area offset 18dp: the safe-zone guarantee depends on it.
    """
    w = fg.size[0]
    px = fg.load()
    pts = [
        (x, y)
        for y in range(0, w, 2)
        for x in range(0, w, 2)
        if px[x, y][3] > 250 and min(px[x, y][:3]) > 225
    ]
    xs = [p[0] / w for p in pts]
    ys = [p[1] / w for p in pts]
    got = (min(xs), max(xs), min(ys), max(ys))
    want = tuple((18 + 72 * v / 1024) / 108 for v in (262, 786, 232, 792))
    if any(abs(g - e) > 0.01 for g, e in zip(got, want)):
        raise SystemExit(f"Door drifted: got {got}, expected {want}")


def resize(img: Image.Image, size: int) -> Image.Image:
    # Premultiplied resize so the transparent foreground keeps clean edges.
    return img.convert("RGBa").resize((size, size), Image.LANCZOS).convert("RGBA")


def visible(composite: Image.Image) -> Image.Image:
    """Crop the 72dp area every launcher mask shows from the 108dp canvas."""
    s = composite.size[0]
    return composite.crop((s // 6, s // 6, s - s // 6, s - s // 6))


def masked(img: Image.Image, kind: str) -> Image.Image:
    s = img.size[0] * 4
    big = img.resize((s, s), Image.LANCZOS)
    mask = Image.new("L", (s, s), 0)
    draw = ImageDraw.Draw(mask)
    if kind == "round":
        draw.ellipse([0, 0, s - 1, s - 1], fill=255)
    else:
        draw.rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.22), fill=255)
    big.putalpha(mask)
    return big


def save(img: Image.Image, path: Path, *, rgb: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    (img.convert("RGB") if rgb else img).save(path, format="PNG", optimize=True)
    print(f"  {path.relative_to(ROOT)} ({path.stat().st_size} bytes)")


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        tmp_dir = Path(tmp)
        fg = render("fgonly", 432, tmp_dir)
        check_door(fg)
        bg = render("bgonly", 432, tmp_dir)
        icon = visible(render("all", 432, tmp_dir))

        print("Android adaptive layers and legacy icons:")
        for folder, scale in DENSITIES.items():
            out = RES / f"mipmap-{folder}"
            save(resize(fg, int(108 * scale)), out / "ic_launcher_foreground.png")
            save(resize(bg, int(108 * scale)), out / "ic_launcher_background.png", rgb=True)
            save(resize(masked(icon, "square"), int(48 * scale)), out / "ic_launcher.png")
            save(resize(masked(icon, "round"), int(48 * scale)), out / "ic_launcher_round.png")

        print("Play listing and bundled branding:")
        save(resize(icon, 512), PLAY, rgb=True)
        save(resize(icon, 512), BRANDING, rgb=True)

        print("1024px masters:")
        save(render("fgonly", 512, tmp_dir), MASTERS / "docket_icon_foreground_1024.png")
        save(render("bgonly", 512, tmp_dir), MASTERS / "docket_icon_background_1024.png", rgb=True)
        save(resize(visible(render("all", 768, tmp_dir)), 1024), MASTERS / "docket_icon_1024.png", rgb=True)
    print("Done (Android only).")


if __name__ == "__main__":
    main()
