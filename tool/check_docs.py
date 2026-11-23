"""Check repository-local Markdown links without network access or dependencies."""

from pathlib import Path
import re
import subprocess
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parent.parent


def check_links() -> list[str]:
    paths = subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=ROOT,
    ).decode("utf-8").split("\0")
    errors = []
    for relative in sorted(set(paths)):
        path = ROOT / relative
        if path.suffix.lower() != ".md" or not path.is_file():
            continue
        fence = None
        for number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
            marker = re.match(r"^\s*(`{3,}|~{3,})", line)
            if marker:
                token = marker[1]
                if fence is None:
                    fence = token
                elif token[0] == fence[0] and len(token) >= len(fence):
                    fence = None
                continue
            if fence:
                continue
            for match in re.finditer(r"!?\[[^\]]*\]\((<[^>]+>|[^\s)]+)(?:\s+[^)]*)?\)", line):
                link = match[1].strip("<>")
                if re.match(r"^[a-zA-Z][a-zA-Z\d+.-]*:", link) or link.startswith("#"):
                    continue
                target = unquote(link.split("#", 1)[0])
                if not target:
                    continue
                resolved = (ROOT / target.lstrip("/")) if target.startswith("/") else (path.parent / target)
                resolved = resolved.resolve()
                # Optional sibling repositories are not required in a fresh clone.
                if not resolved.is_relative_to(ROOT):
                    continue
                if not resolved.exists():
                    errors.append(f"{relative}:{number}: missing link target {target}")
    return errors


if __name__ == "__main__":
    failures = check_links()
    for failure in failures:
        print(failure)
    if failures:
        raise SystemExit(1)
    print("Repository-local Markdown link targets exist.")
