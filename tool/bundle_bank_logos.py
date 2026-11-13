"""Rebundle pinned bank SVGs and inline CSS fills for flutter_svg."""
import hashlib
import json
from pathlib import Path
import re
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tool/design_src/bank_logos/sources.json"


def main():
    sources = json.loads(MANIFEST.read_text())
    for source in sources:
        original = urllib.request.urlopen(source["url"], timeout=30).read()
        assert hashlib.sha256(original).hexdigest() == source["sha256"]
        svg = original.decode("utf-8")
        styles = re.findall(r"<style[^>]*>(.*?)</style>", svg, re.S)
        for style in styles:
            for cls, color in re.findall(r"\.([\w-]+)\s*\{\s*fill:\s*(#[0-9a-fA-F]+)\s*;?\s*\}", style):
                svg = svg.replace(f'class="{cls}"', f'fill="{color}"')
        svg = re.sub(r"<style[^>]*>.*?</style>", "", svg, flags=re.S)
        svg = re.sub(r"<metadata[^>]*>.*?</metadata>", "", svg, flags=re.S)
        # Preserve unmodified bytes for files that need no normalization.
        data = svg.encode("utf-8") if styles else original
        (ROOT / f"assets/wallet/banks/{source['id']}.svg").write_bytes(data)
        source["bundledSha256"] = hashlib.sha256(data).hexdigest()
        source["changes"] = (
            "Inline CSS fills; remove style and metadata elements."
            if styles else "None"
        )
    MANIFEST.write_text(json.dumps(sources, indent=2) + "\n")


if __name__ == "__main__":
    main()
