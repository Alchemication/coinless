#!/usr/bin/env python3
"""Checks the public site before it's published (.github/workflows/pages.yml).

- The page loads nothing from another site: scripts, stylesheets, images and
  fonts are all local. Plain links to other sites are fine.
- Every local file the page refers to exists, and every image has alt text.

Run: python3 site/check.py
"""

import re
import sys
from pathlib import Path

SITE = Path(__file__).resolve().parent


def check(page: Path) -> list[str]:
    html = page.read_text(encoding="utf-8")
    problems = []

    for image in re.findall(r"<img\b[^>]*>", html):
        if not re.search(r'\balt="[^"]+"', image):
            problems.append(f"{page.name}: an image has no alt text: {image[:60]}…")

    loads = re.findall(r'<(?:script|img|link|source|iframe)\b[^>]*?\b(?:src|href)="([^"]+)"', html)
    loads += re.findall(r'url\(["\']?([^"\')]+)', html)
    for target in loads:
        if re.match(r"(https?:)?//", target):
            # Link previews must be absolute; browsers don't load them.
            if not re.search(r'<meta property="og:image" content="' + re.escape(target), html):
                problems.append(f"{page.name}: loads {target} from another site; keep a copy under site/")
        elif not target.startswith(("#", "data:")) and not (page.parent / target.split("#")[0]).exists():
            problems.append(f"{page.name}: {target} doesn't exist")
    return problems


def ghosts() -> list[str]:
    """Every sprite assets/ghosts.js names exists in images/ghosts/, and every file there is used."""
    script = (SITE / "assets/ghosts.js").read_text(encoding="utf-8")
    block = script[script.index("const GAMES"):script.index("  ]\n")]
    names = set(re.findall(r"'([a-z0-9][a-z0-9-]*)'", block))
    names -= {"icon", "figure", "portrait"}  # the kinds, not sprites
    files = {path.stem for path in (SITE / "images/ghosts").glob("*.png")}
    return ([f"ghosts.js: images/ghosts/{name}.png doesn't exist" for name in sorted(names - files)] +
            [f"images/ghosts/{name}.png isn't used by ghosts.js" for name in sorted(files - names)])


def main() -> int:
    problems = [problem for page in sorted(SITE.glob("*.html")) for problem in check(page)] + ghosts()
    css = (SITE / "assets/site.css").read_text(encoding="utf-8")
    for target in re.findall(r'url\(["\']?([^"\')]+)', css):
        if re.match(r"(https?:)?//", target):
            problems.append(f"site.css: loads {target} from another site")
    for problem in problems:
        print(problem, file=sys.stderr)
    print("Site checks passed." if not problems else f"{len(problems)} problem(s).")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
