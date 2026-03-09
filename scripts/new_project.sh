#!/usr/bin/env bash
set -euo pipefail

PROJECTS_DIR="works/projects"
TEMPLATE_DIR="${PROJECTS_DIR}/_template-project"
WORK_HTML="work.html"

if [[ ! -d .git || ! -d "$PROJECTS_DIR" || ! -f "$WORK_HTML" ]]; then
  echo "Error: run this script from repo root (my-cv)." >&2
  exit 1
fi

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "Error: template directory not found: $TEMPLATE_DIR" >&2
  exit 1
fi

read -r -p "Year (YYYY): " PROJECT_YEAR
if [[ ! "$PROJECT_YEAR" =~ ^[0-9]{4}$ ]]; then
  echo "Error: Year must be YYYY." >&2
  exit 1
fi

read -r -p "Number (optional NNN, blank = auto): " PROJECT_NNN
if [[ -n "$PROJECT_NNN" && ! "$PROJECT_NNN" =~ ^[0-9]{3}$ ]]; then
  echo "Error: manual number must be exactly 3 digits." >&2
  exit 1
fi

read -r -p "Slug (lowercase + hyphens, no spaces): " PROJECT_SLUG
if [[ ! "$PROJECT_SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "Error: slug must be lowercase letters/numbers with hyphens only (no spaces)." >&2
  exit 1
fi

read -r -p "Project title: " PROJECT_TITLE
if [[ -z "$PROJECT_TITLE" ]]; then
  echo "Error: Project title cannot be empty." >&2
  exit 1
fi

read -r -p "Year display text for work.html [${PROJECT_YEAR}]: " DISPLAY_YEAR
DISPLAY_YEAR="${DISPLAY_YEAR:-$PROJECT_YEAR}"
if [[ ! "$DISPLAY_YEAR" =~ ^[0-9]{4}$ ]]; then
  echo "Error: display year must be YYYY." >&2
  exit 1
fi

if [[ -z "$PROJECT_NNN" ]]; then
  max_nnn=0
  shopt -s nullglob
  for path in "${PROJECTS_DIR}/p-${PROJECT_YEAR}-"*; do
    dir_name="$(basename "$path")"
    if [[ "$dir_name" =~ ^p-${PROJECT_YEAR}-([0-9]{3})- ]]; then
      n=$((10#${BASH_REMATCH[1]}))
      (( n > max_nnn )) && max_nnn=$n
    fi
  done
  shopt -u nullglob
  PROJECT_NNN="$(printf '%03d' "$((max_nnn + 1))")"
fi

PROJECT_ID="p-${PROJECT_YEAR}-${PROJECT_NNN}-${PROJECT_SLUG}"
PROJECT_DIR="${PROJECTS_DIR}/${PROJECT_ID}"
PROJECT_INDEX="${PROJECT_DIR}/index.html"

if [[ -e "$PROJECT_DIR" ]]; then
  echo "Error: target already exists: $PROJECT_DIR" >&2
  exit 1
fi

mkdir -p "$PROJECT_DIR"
cp -R "${TEMPLATE_DIR}/." "$PROJECT_DIR/"
mkdir -p "${PROJECT_DIR}/img"
if [[ -d "${TEMPLATE_DIR}/assets" ]]; then
  mkdir -p "${PROJECT_DIR}/assets"
fi

if [[ ! -f "$PROJECT_INDEX" ]]; then
  cat > "$PROJECT_INDEX" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>New Project Title</title>
  <link rel="stylesheet" href="../../../style.base.css?v=20260130">
  <link rel="stylesheet" href="../../../style.pages.css?v=20260130">
</head>
<body class="project-page">
  <header class="site-header">
    <h1 class="site-title"><a href="../../../index.html" class="site-title-link">Gino Wong</a></h1>
    <nav class="site-nav">
      <a href="../../../index.html" class="nav-link">Home</a>
      <a href="../../../work.html" class="nav-link">Work</a>
      <a href="../../../statement.html" class="nav-link">Artist Statement</a>
      <a href="../../../biography.html" class="nav-link">Biography</a>
    </nav>
  </header>
  <main class="project-main">
    <figure class="project-hero">
      <img src="img/hero.jpg" alt="New project hero" loading="lazy" decoding="async" />
    </figure>
    <div class="project-back">
      <a href="../../../work.html" class="back-link">Back to Work</a>
    </div>
  </main>
</body>
</html>
HTML
fi

if [[ ! -f "$PROJECT_INDEX" ]]; then
  echo "Error: template copy failed; missing ${PROJECT_INDEX}" >&2
  exit 1
fi

touch "${PROJECT_DIR}/img/hero.jpg"
touch "${PROJECT_DIR}/img/thumb.jpg"

cat > "${PROJECT_DIR}/README-ASSET-NAMES.txt" <<'TXT'
Recommended image names:
- hero.webp or hero.jpg
- thumb-v2.webp
- thumb.webp
- thumb-v2.jpg
- thumb.jpg
- 01.webp / 01.jpg etc

Thumbnail selection priority:
thumb-v2.webp -> thumb.webp -> thumb-v2.jpg -> thumb.jpg

Hero selection priority:
hero.webp -> hero.jpg
TXT

hero_src="img/hero.jpg"
hero_expected="hero.jpg"
if [[ -f "${PROJECT_DIR}/img/hero.webp" ]]; then
  hero_src="img/hero.webp"
  hero_expected="hero.webp"
fi

thumb_file=""
for candidate in thumb-v2.webp thumb.webp thumb-v2.jpg thumb.jpg; do
  if [[ -f "${PROJECT_DIR}/img/${candidate}" ]]; then
    thumb_file="$candidate"
    break
  fi
done

thumb_choice="none (work row inserted without thumbnail image)"
if [[ -n "$thumb_file" ]]; then
  thumb_choice="works/projects/${PROJECT_ID}/img/${thumb_file}"
fi

escape_html() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

title_esc="$(escape_html "$PROJECT_TITLE")"
page_class="${PROJECT_SLUG}-page"

python3 - "$PROJECT_INDEX" "$title_esc" "$page_class" "$hero_src" <<'PY'
import re
import sys
from pathlib import Path

index_path = Path(sys.argv[1])
title = sys.argv[2]
page_class = sys.argv[3]
hero_src = sys.argv[4]

html = index_path.read_text(encoding="utf-8")

html = re.sub(r"<title>.*?</title>", f"<title>{title}</title>", html, count=1, flags=re.S)
html = re.sub(
    r'(<h1\b[^>]*class="[^"]*\bproject-title\b[^"]*"[^>]*>).*?(</h1>)',
    rf"\1{title}\2",
    html,
    count=1,
    flags=re.S,
)

if re.search(r"<body\b[^>]*class=", html, flags=re.S):
    html = re.sub(
        r'(<body\b[^>]*\bclass=")[^"]*(")',
        rf"\1{page_class}\2",
        html,
        count=1,
        flags=re.S,
    )
else:
    html = re.sub(r"<body\b([^>]*)>", rf'<body\1 class="{page_class}">', html, count=1, flags=re.S)

html = re.sub(
    r'\n[ \t]*<link\s+rel="stylesheet"\s+href="[^"]*style(?:\.base|\.pages)?\.css(?:\?[^"]*)?"\s*/?>',
    "",
    html,
    flags=re.S,
)
html = re.sub(
    r"</head>",
    '\n  <link rel="stylesheet" href="../../../style.base.css?v=20260130">\n'
    '  <link rel="stylesheet" href="../../../style.pages.css?v=20260130">\n'
    "</head>",
    html,
    count=1,
    flags=re.S,
)

html = re.sub(
    r'(<img\b[^>]*\bsrc=")[^"]*hero\.[^"]*(")',
    rf'\1{hero_src}\2',
    html,
    count=1,
    flags=re.S,
)

html = re.sub(
    r"<a\b[^>]*>\s*Back to Work\s*</a>",
    '<a href="../../../work.html" class="back-link">Back to Work</a>',
    html,
    flags=re.S,
)
if '<a href="../../../work.html" class="back-link">Back to Work</a>' not in html:
    html = re.sub(
        r"</main>",
        '\n    <div class="project-back">\n'
        '      <a href="../../../work.html" class="back-link">Back to Work</a>\n'
        "    </div>\n"
        "  </main>",
        html,
        count=1,
        flags=re.S,
    )

index_path.write_text(html, encoding="utf-8")
PY

work_backup="work.html.bak.$(date +%Y%m%d-%H%M%S)"
cp "$WORK_HTML" "$work_backup"

if ! python3 - "$WORK_HTML" "$PROJECT_ID" "$title_esc" "$DISPLAY_YEAR" "$thumb_file" "$PROJECT_YEAR" "$PROJECT_NNN" <<'PY'
import re
import sys
from pathlib import Path

work_path = Path(sys.argv[1])
project_id = sys.argv[2]
title = sys.argv[3]
display_year = sys.argv[4]
thumb_file = sys.argv[5]
new_year = int(sys.argv[6])
new_nnn = int(sys.argv[7])

html = work_path.read_text(encoding="utf-8")

start = html.find('<div class="work-list">')
if start == -1:
    raise SystemExit("Error: work-list not found in work.html")

open_end = html.find('>', start)
if open_end == -1:
    raise SystemExit("Error: malformed work-list opening tag")

body_start = open_end + 1
i = body_start
depth = 1
while i < len(html) and depth > 0:
    next_open = html.find('<div', i)
    next_close = html.find('</div>', i)
    if next_close == -1:
        raise SystemExit("Error: unmatched work-list container")
    if next_open != -1 and next_open < next_close:
        depth += 1
        i = next_open + 4
    else:
        depth -= 1
        i = next_close + 6

if depth != 0:
    raise SystemExit("Error: failed to parse work-list container")

close_start = i - 6
list_body = html[body_start:close_start]

row_re = re.compile(r'\s*<a\b[^>]*\bclass="[^"]*\bwork-row\b[^"]*"[^>]*>.*?</a>\s*', re.S)
rows = list(row_re.finditer(list_body))
if not rows:
    raise SystemExit("Error: no work-row blocks found")

first_block = rows[0].group(0)
new_block = first_block
new_block = re.sub(r'href="[^"]+"', f'href="works/projects/{project_id}/index.html"', new_block, count=1)

if thumb_file:
    if re.search(r'<img\b[^>]*\bclass="[^"]*\bwork-thumb\b[^"]*"', new_block, re.S):
        new_block = re.sub(
            r'(<img\b(?=[^>]*\bclass="[^"]*\bwork-thumb\b[^"]*")[^>]*?)\bsrc="[^"]*"',
            rf'\1src="works/projects/{project_id}/img/{thumb_file}"',
            new_block,
            count=1,
            flags=re.S,
        )
        new_block = re.sub(
            r'(<img\b(?=[^>]*\bclass="[^"]*\bwork-thumb\b[^"]*")[^>]*?)\balt="[^"]*"',
            rf'\1alt="{title}"',
            new_block,
            count=1,
            flags=re.S,
        )
else:
    new_block = re.sub(
        r'\n?\s*<img\b(?=[^>]*\bclass="[^"]*\bwork-thumb\b[^"]*")[^>]*>\s*\n?',
        '\n',
        new_block,
        count=1,
        flags=re.S,
    )

new_block = re.sub(
    r'(<div class="work-line">).*?(<span class="work-year">\().*?(\)</span></div>)',
    rf'\1{title} \2{display_year}\3',
    new_block,
    count=1,
    flags=re.S,
)

items = []
for idx, m in enumerate(rows):
    block = m.group(0)
    href_m = re.search(r'href="([^"]+)"', block)
    href = href_m.group(1) if href_m else ""
    key_m = re.search(r'p-(\d{4})-(\d{3})-', href)
    if key_m:
        key = (0, -int(key_m.group(1)), -int(key_m.group(2)), idx)
    else:
        key = (1, 0, 0, idx)
    items.append((key, block))

items.append(((0, -new_year, -new_nnn, len(items)), new_block))
items.sort(key=lambda x: x[0])

prefix = list_body[:rows[0].start()]
suffix = list_body[rows[-1].end():]
new_body = prefix + ''.join(block for _, block in items) + suffix

new_html = html[:body_start] + new_body + html[close_start:]
work_path.write_text(new_html, encoding="utf-8")
PY
then
  cp "$work_backup" "$WORK_HTML"
  echo "Error: failed to update work.html. Restored from backup: ${work_backup}" >&2
  exit 1
fi

echo "Project created successfully."
echo "Created folder: ${PROJECT_DIR}"
echo "Expected hero image: ${hero_expected} (hero.webp preferred, fallback hero.jpg)"
echo "Selected thumbnail: ${thumb_choice}"
echo "Backed up work list: ${work_backup}"
echo "Reminder: replace placeholder files in ${PROJECT_DIR}/img (hero.jpg, thumb.jpg) with real images."
echo "Reminder: edit ${PROJECT_INDEX} and add full project text/details."
