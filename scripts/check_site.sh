#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# check .DS_Store
if find "$ROOT" -name ".DS_Store" -print | grep -q .; then
  echo "Found .DS_Store:"
  find "$ROOT" -name ".DS_Store" -print
  exit 1
fi

# check missing assets referenced by img src
missing=0
while IFS= read -r file; do
  while IFS= read -r src; do
    path="$ROOT/$(dirname "$file")/${src}"
    if [[ ! -f "$path" ]]; then
      echo "Missing asset: $file -> $src"
      missing=1
    fi
  done < <(rg -o "img[^"']+" "$file" || true)
  done < <(rg --files -g "*.html" "$ROOT")
if [[ $missing -ne 0 ]]; then
  exit 1
fi

# duplicate selectors across css files (simple)
python3 - <<'PY2'
from pathlib import Path
import re

root = Path(".")
css_files = [root/"style.base.css", root/"style.pages.css"]
selectors = {}
for p in css_files:
    if not p.exists():
        continue
    text = p.read_text(encoding='utf-8')
    for part in text.split('{')[:-1]:
        sel = part.split('}')[-1].strip()
        if not sel or sel.startswith('@'):
            continue
        selectors.setdefault(sel, set()).add(p.name)

dups = {s:files for s,files in selectors.items() if len(files) > 1}
if dups:
    print("Duplicate selectors across css files:")
    for s,files in sorted(dups.items()):
        print(f"{s} -> {', '.join(sorted(files))}")
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
