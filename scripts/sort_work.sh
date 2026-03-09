#!/usr/bin/env bash
set -euo pipefail

if [[ ! -d ".git" || ! -f "work.html" ]]; then
  echo "Error: run from repo root (my-cv)." >&2
  exit 1
fi

ts="$(date +%Y%m%d-%H%M%S)"
backup="work.html.bak.${ts}"
cp "work.html" "$backup"

python3 - <<'PY'
import re
from pathlib import Path

path = Path("work.html")
html = path.read_text(encoding="utf-8")

open_match = re.search(r'<div\s+class="work-list">', html)
if not open_match:
    raise SystemExit('Error: <div class="work-list"> not found')

list_open_start = open_match.start()
list_body_start = open_match.end()

# Find matching closing </div> for work-list by tracking nested <div> depth.
depth = 1
i = list_body_start
while depth > 0:
    next_open = html.find("<div", i)
    next_close = html.find("</div>", i)
    if next_close == -1:
        raise SystemExit("Error: malformed work-list (missing closing </div>)")
    if next_open != -1 and next_open < next_close:
        depth += 1
        i = next_open + 4
    else:
        depth -= 1
        i = next_close + 6

list_close_start = i - 6
list_close_end = i
list_body = html[list_body_start:list_close_start]

row_pattern = re.compile(
    r'\s*<a\b[^>]*\bclass="[^"]*\bwork-row\b[^"]*"[^>]*>.*?</a>\s*',
    flags=re.S,
)
rows = list(row_pattern.finditer(list_body))
if not rows:
    raise SystemExit("Error: no work rows found inside work-list")

prefix = list_body[:rows[0].start()]
suffix = list_body[rows[-1].end():]

items = []
old_order = []
for idx, match in enumerate(rows):
    block = match.group(0)
    href_match = re.search(r'href="([^"]+)"', block)
    href = href_match.group(1) if href_match else ""
    old_order.append(href)

    key_match = re.search(r'p-(\d{4})-(\d{3})-', href)
    if key_match:
        year = int(key_match.group(1))
        nnn = int(key_match.group(2))
        key = (0, -year, -nnn, idx)
    else:
        key = (1, 0, 0, idx)

    items.append((key, href, block))

items.sort(key=lambda x: x[0])
new_order = [href for _, href, _ in items]

new_rows = "".join(block for _, _, block in items)
new_list_body = prefix + new_rows + suffix
new_html = html[:list_body_start] + new_list_body + html[list_close_start:]

path.write_text(new_html, encoding="utf-8")

print(f"rows_found: {len(rows)}")
print("old_order:")
for href in old_order:
    print(href)
print("new_order:")
for href in new_order:
    print(href)
PY

echo "Backup: ${backup}"
