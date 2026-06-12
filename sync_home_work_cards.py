#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from pathlib import Path
import csv
import re
from datetime import datetime

ROOT = Path(".").resolve()
CSV_PATH = ROOT / "projects.csv"
INDEX_HTML = ROOT / "index.html"
WORK_HTML = ROOT / "work.html"

# 你指定的 Recent Projects（Home 页展示）
RECENT_SLUGS = [
    "p-2024-001-the-awarded",
    "p-2024-002-the-haunted-image",
]

def backup(p: Path) -> Path:
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    bak = p.with_suffix(p.suffix + f".bak.{ts}")
    bak.write_text(p.read_text(encoding="utf-8"), encoding="utf-8")
    return bak

def read_projects(csv_path: Path) -> list[dict]:
    if not csv_path.exists():
        raise FileNotFoundError("projects.csv not found.")
    rows = []
    with csv_path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for r in reader:
            slug = (r.get("project_slug") or "").strip()
            title = (r.get("title") or "").strip()
            year = (r.get("year") or "").strip()
            if slug:
                rows.append({"slug": slug, "title": title, "year": year})
    return rows

def card_html(project: dict, card_class: str, title_class: str, year_class: str) -> str:
    slug = project["slug"]
    title = project["title"] or slug
    year = project["year"] or ""
    href = (
        "work/the-haunted-image/"
        if slug == "p-2024-002-the-haunted-image"
        else f"works/projects/{slug}/index.html"
    )
    src  = f'works/projects/{slug}/img/thumb.jpg'

    # 两行小字：title + year
    return (
        f'                <a class="{card_class}" href="{href}">\n'
        f'                    <img src="{src}" alt="{title}">\n'
        f'                    <div class="{title_class}">{title}</div>\n'
        f'                    <div class="{year_class}">{year}</div>\n'
        f'                </a>\n'
    )

def replace_div_inner(html: str, div_class: str, new_inner: str) -> tuple[str, bool]:
    # 替换 <div class="xxx"> ... </div> 的内部内容（保留外层 div）
    pattern = re.compile(rf'(<div\s+class="{re.escape(div_class)}"\s*>)(.*?)(</div>)', re.S)
    m = pattern.search(html)
    if not m:
        return html, False
    replaced = pattern.sub(rf'\1\n{new_inner}            \3', html, count=1)
    return replaced, True

def main():
    projects = read_projects(CSV_PATH)
    by_slug = {p["slug"]: p for p in projects}

    # Home Recent Projects（只放你指定的 2 个）
    recent = []
    for s in RECENT_SLUGS:
        if s in by_slug:
            recent.append(by_slug[s])
        else:
            print(f"⚠️ Recent slug not found in projects.csv: {s}")

    # Work 页：展示全部（按 projects.csv 的顺序）
    all_projects = projects

    # 生成 Home 的 selected works 网格
    home_inner = ""
    for p in recent:
        home_inner += card_html(
            p,
            card_class="selected-work-card",
            title_class="selected-work-title",
            year_class="selected-work-year"
        )

    # 生成 Work 的 work-grid（卡片形态沿用你原来 work-card 结构）
    # 如果你的 work.html 里是 <div class="work-grid">...</div>，会自动替换其内部
    work_inner = ""
    for p in all_projects:
        slug = p["slug"]
        title = p["title"] or slug
        year = p["year"] or ""
        href = (
            "work/the-haunted-image/"
            if slug == "p-2024-002-the-haunted-image"
            else f"works/projects/{slug}/index.html"
        )
        src  = f'works/projects/{slug}/img/thumb.jpg'
        work_inner += (
            '                <div class="work-card">\n'
            f'                    <a href="{href}">\n'
            f'                        <img src="{src}" alt="{title}">\n'
            f'                        <div class="work-card-title">{title}</div>\n'
            f'                        <div class="work-card-desc">{year}</div>\n'
            f'                    </a>\n'
            '                </div>\n'
        )

    # 修改 index.html
    if INDEX_HTML.exists():
        html = INDEX_HTML.read_text(encoding="utf-8")
        new_html, ok = replace_div_inner(html, "selected-works-grid", home_inner)
        if ok and new_html != html:
            bak = backup(INDEX_HTML)
            INDEX_HTML.write_text(new_html, encoding="utf-8")
            print(f"✅ Updated index.html (backup: {bak.name})")
        else:
            print('⚠️ index.html: did not find <div class="selected-works-grid"> ... </div>, no change.')
    else:
        print("⚠️ index.html not found, skip.")

    # 修改 work.html
    if WORK_HTML.exists():
        html = WORK_HTML.read_text(encoding="utf-8")
        new_html, ok = replace_div_inner(html, "work-grid", work_inner)
        if ok and new_html != html:
            bak = backup(WORK_HTML)
            WORK_HTML.write_text(new_html, encoding="utf-8")
            print(f"✅ Updated work.html (backup: {bak.name})")
        else:
            print('⚠️ work.html: did not find <div class="work-grid"> ... </div>, no change.')
    else:
        print("⚠️ work.html not found, skip.")

    print("\nDone.")

if __name__ == "__main__":
    main()
