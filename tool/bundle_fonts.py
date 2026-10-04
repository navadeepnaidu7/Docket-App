"""Download pinned Google Fonts bytes and licences used by Docket.

Run with the google_fonts package directory from .dart_tool/package_config.json:
  python tool/bundle_fonts.py D:/dev/pub-cache/hosted/pub.dev/google_fonts-8.2.1
Only run when intentionally updating bundled fonts. Every download is verified
against the package's pinned SHA-256 and length before it reaches assets/.
"""

import concurrent.futures
import hashlib
import json
from pathlib import Path
import re
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
FAMILIES = {
    "Inter": ("inter", "i", "inter", [400, 500, 600, 700, 800, 900]),
    "RobotoMono": ("robotoMono", "r", "robotomono", [400, 500, 600, 700]),
    "NotoSansDevanagari": ("notoSansDevanagari", "n", "notosansdevanagari", [700]),
    "Geist": ("geist", "g", "geist", [400, 500, 600, 700]),
    "InstrumentSerif": ("instrumentSerif", "i", "instrumentserif", [400]),
}
WEIGHTS = {400: "Regular", 500: "Medium", 600: "SemiBold", 700: "Bold",
           800: "ExtraBold", 900: "Black"}


def fetch(url):
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read()


def main():
    package = Path(sys.argv[1])
    destination = ROOT / "assets" / "fonts"
    destination.mkdir(parents=True, exist_ok=True)
    manifest = []
    for family, (method, part, directory, weights) in FAMILIES.items():
        source = (package / "lib/src/google_fonts_parts" / f"part_{part}.dart").read_text()
        body = source.split(f"static TextStyle {method}(", 1)[1].split("return googleFontsTextStyle", 1)[0]
        variants = re.findall(
            r"fontWeight: FontWeight.w(\d+),\s*fontStyle: FontStyle.normal,\s*"
            r"\): GoogleFontsFile\(\s*'([0-9a-f]+)',\s*(\d+)", body)
        for weight, digest, length in variants:
            if int(weight) in weights:
                manifest.append({"file": f"{family}-{WEIGHTS[int(weight)]}.ttf",
                                 "sha256": digest, "bytes": int(length),
                                 "url": f"https://fonts.gstatic.com/s/a/{digest}.ttf"})
        licence_url = f"https://raw.githubusercontent.com/google/fonts/main/ofl/{directory}/OFL.txt"
        licence = fetch(licence_url).decode("utf-8")
        (destination / f"{family}-OFL.txt").write_text(
            "\n".join(line.rstrip() for line in licence.splitlines()) + "\n",
            encoding="utf-8")

    def download(entry):
        path = destination / entry["file"]
        data = path.read_bytes() if path.exists() else fetch(entry["url"])
        assert len(data) == entry["bytes"] and hashlib.sha256(data).hexdigest() == entry["sha256"], entry["file"]
        path.write_bytes(data)
        return entry["file"]

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for filename in pool.map(download, manifest):
            print(filename)
    assert len(manifest) == sum(len(item[3]) for item in FAMILIES.values())
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Verified {len(manifest)} fonts, {sum(item['bytes'] for item in manifest):,} bytes")


if __name__ == "__main__":
    main()
