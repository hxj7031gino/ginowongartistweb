#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# check .DS_Store
if find "$ROOT" -name ".DS_Store" -print | grep -q .; then
  echo "Found .DS_Store:"
  find "$ROOT" -name ".DS_Store" -print
  exit 1
fi

# check missing local assets referenced by real src/href attributes
python3 - "$ROOT" <<'PY1'
from pathlib import Path
from urllib.parse import unquote
import re
import sys

root = Path(sys.argv[1])
attr_re = re.compile(r"""\b(?:src|href)\s*=\s*(["'])(.*?)\1""", re.I | re.S)
ignore_prefixes = ("http://", "https://", "mailto:", "tel:", "#", "")
missing = []

for file in sorted(root.rglob("*.html")):
    text = file.read_text(encoding="utf-8", errors="replace")
    for _, value in attr_re.findall(text):
        value = value.strip()
        if value.startswith(ignore_prefixes):
            continue
        if value.startswith(("data:", "javascript:")):
            continue

        path_value = value.split("#", 1)[0].split("?", 1)[0]
        if not path_value:
            continue

        target = (file.parent / unquote(path_value)).resolve()
        try:
            target.relative_to(root)
        except ValueError:
            continue

        if not target.exists():
            missing.append((file, value))

if missing:
    for file, value in missing:
        print(f"Missing asset: {file} -> {value}")
    raise SystemExit(1)
PY1

# duplicate selectors within the same responsive context
python3 - <<'PY2'
from pathlib import Path
import re

root = Path(".")
css_files = [root/"style.base.css", root/"style.pages.css"]
selectors = {}

def media_context(prelude):
    text = " ".join(prelude.split())
    match = re.search(r"max-width\s*:\s*(900|800|600)px", text)
    if match:
        return f"@media max-width: {match.group(1)}px"
    return text

def collect_selectors(css_text, file_name):
    text = re.sub(r"/\*.*?\*/", "", css_text, flags=re.S)
    stack = []
    start = 0
    for index, char in enumerate(text):
        if char == "{":
            prelude = text[start:index].strip()
            current_media = stack[-1] if stack else "top-level"
            if prelude.startswith("@media"):
                stack.append(media_context(prelude))
            elif prelude and not prelude.startswith("@"):
                context = current_media
                for selector in (s.strip() for s in prelude.split(",")):
                    if selector:
                        selectors.setdefault((context, selector), set()).add(file_name)
            start = index + 1
        elif char == "}":
            if stack:
                block_text = text[start:index].strip()
                if not block_text or block_text.endswith("}"):
                    stack.pop()
            start = index + 1

for p in css_files:
    if not p.exists():
        continue
    collect_selectors(p.read_text(encoding='utf-8'), p.name)

dups = {key:files for key,files in selectors.items() if len(files) > 1}
if dups:
    print("Duplicate selectors within the same CSS context:")
    for (context, selector), files in sorted(dups.items()):
        print(f"{context}: {selector} -> {', '.join(sorted(files))}")
    raise SystemExit(1)
PY2

# verify each page links both css
for f in $(rg --files -g "*.html" "$ROOT"); do
  if ! rg -q "style\.base\.css\?v=20260130" "$f"; then
    echo "Missing style.base.css link: $f"
    exit 1
  fi
  if ! rg -q "style\.pages\.css\?v=20260130" "$f"; then
    echo "Missing style.pages.css link: $f"
    exit 1
  fi
done

echo "check_site.sh OK"
