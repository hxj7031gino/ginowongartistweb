#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from pathlib import Path
import re
import csv
from datetime import datetime

ROOT = Path(".").resolve()
PROJECTS_DIR = ROOT / "works" / "projects"
CSV_PATH = ROOT / "projects.csv"

IGNORE = {"_template-project"}  # 固定忽略
PATTERN = re.compile(r"^p-(\d{4})-(\d{3})-([a-z0-9]+(?:-[a-z0-9]+)*)$")

MINIMAL_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{title}</title>
  <link rel="stylesheet" href="../../../style.css" />
</head>
<body>
  <header class="site-header">
    <div class="site-title-wrapper">
      <a class="site-title" href="../../../index.html">Gino Wong</a>
    </div>
    <nav class="site-nav">
      <a href="../../../index.html" class="nav-link">Home</a>
      <a href="../../../projects/" class="nav-link">Project</a>
      <a href="../../../work.html" class="nav-link">Work</a>
      <a href="../../../about/" class="nav-link">About</a>
    </nav>
  </header>

  <main class="project-main">
    <h1 class="project-title">{title}</h1>

    <figure class="project-hero">
      <img src="img/hero.jpg" alt="{title} hero" />
    </figure>

    <section class="project-gallery">
      <h2 class="project-section-title">Gallery</h2>
      <div class="project-grid">
        <img src="img/01.jpg" alt="{title} image 01" />
        <!-- Add more images: 02.jpg, 03.jpg... -->
      </div>
    </section>

    <section class="project-meta">
      <h2 class="project-section-title">Information</h2>
      <div class="project-meta-row"><span>Year</span><span></span></div>
      <div class="project-meta-row"><span>Medium</span><span></span></div>
      <div class="project-meta-row"><span>Dimensions</span><span></span></div>
    </section>

    <div class="project-back">
      <a href="../../../work.html">Back to Work</a>
    </div>
  </main>
</body>
</html>
"""

def slug_to_title(slug: str) -> str:
    m = PATTERN.match(slug)
    if not m:
        return slug
    name = m.group(3).replace("-", " ").strip()
    return name.title()

def read_existing_csv(csv_path: Path) -> dict:
    data = {}
    if not csv_path.exists():
        return data
    with csv_path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            slug = (row.get("project_slug") or "").strip()
            if not slug:
                continue
            data[slug] = (
                (row.get("title") or "").strip(),
                (row.get("year") or "").strip()
            )
    return data

def main():
    if not PROJECTS_DIR.exists():
        print("❌ works/projects not found.")
        return

    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    trash_dir_name = f"_trash_invalid_{ts}"
    trash_dir = PROJECTS_DIR / trash_dir_name
    trash_dir.mkdir(parents=True, exist_ok=True)

    template_index = PROJECTS_DIR / "_template-project" / "index.html"
    template_html = template_index.read_text(encoding="utf-8") if template_index.exists() else None

    # 1) classify folders
    invalid = []
    valid = []
    for p in sorted(PROJECTS_DIR.iterdir()):
        if not p.is_dir():
            continue
        name = p.name
        if name in IGNORE:
            continue
        if name.startswith("_trash_invalid_"):
            # ✅ crucial fix: don't move trash into itself
            continue
        if name.startswith("."):
            continue

        if PATTERN.match(name):
            valid.append(p)
        else:
            invalid.append(p)

    # 2) move invalid to trash
    moved = 0
    for p in invalid:
        target = trash_dir / p.name
        p.rename(target)
        moved += 1

    # 3) ensure index.html
    created = 0
    skipped = 0
    for p in valid:
        out = p / "index.html"
        if out.exists():
            skipped += 1
            continue
        title = slug_to_title(p.name)
        if template_html is not None:
            out.write_text(template_html, encoding="utf-8")
        else:
            out.write_text(MINIMAL_TEMPLATE.format(title=title), encoding="utf-8")
        created += 1

    # 4) rewrite projects.csv (backup first)
    existing = read_existing_csv(CSV_PATH)
    csv_backup = None
    if CSV_PATH.exists():
        csv_backup = CSV_PATH.with_suffix(CSV_PATH.suffix + f".bak.{ts}")
        csv_backup.write_text(CSV_PATH.read_text(encoding="utf-8"), encoding="utf-8")

    rows = []
    for p in valid:
        slug = p.name
        m = PATTERN.match(slug)
        year = m.group(1) if m else ""
        title = slug_to_title(slug)

        if slug in existing:
            old_title, old_year = existing[slug]
            if old_title:
                title = old_title
            if old_year:
                year = old_year

        rows.append((slug, title, year))

    def sort_key(row):
        slug = row[0]
        m = PATTERN.match(slug)
        if not m:
            return ("0000", "000")
        return (m.group(1), m.group(2))

    rows.sort(key=sort_key, reverse=True)

    with CSV_PATH.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["project_slug", "title", "year"])
        for r in rows:
            w.writerow(r)

    print("✅ Fix complete.")
    print(f"- Trash folder: {trash_dir_name}")
    print(f"- Moved invalid folders to trash: {moved}")
    print(f"- Created index.html for valid projects: {created} (skipped existing: {skipped})")
    if csv_backup:
        print(f"- Backed up projects.csv to: {csv_backup.name}")
    print(f"- Rewrote projects.csv with {len(rows)} valid projects.")
    if template_html is None:
        print("⚠️ _template-project/index.html not found. Used minimal placeholder pages.")

if __name__ == "__main__":
    main()
