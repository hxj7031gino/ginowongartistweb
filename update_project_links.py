#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from pathlib import Path
import re
from datetime import datetime

# 你确认的新项目详情页路径（A: works/projects/<slug>/index.html）
NEW_LINKS = {
    "the_awarded": "works/projects/p-2024-001-the-awarded/index.html",
    "the_haunted_image": "work/the-haunted-image/",
    "east_london_socialist_value": "works/projects/p-2023-001-east-london-socialist-value/index.html",
    "making_conversation": "works/projects/p-2023-002-making-conversation/index.html",
    "columbarium_of_the_days": "works/projects/p-2022-001-columbarium-of-the-days/index.html",
}

# 旧路径 -> 新路径（你站点旧版本里最常见的三条）
REPLACE_MAP = {
    "works/work-one/index.html": NEW_LINKS["the_awarded"],
    "works/work-two/index.html": NEW_LINKS["east_london_socialist_value"],
    "works/work-three/index.html": NEW_LINKS["columbarium_of_the_days"],
    # 如果你旧站里还有别的路径（比如 work-four/work-six），你可以在这里继续加
    # "works/work-four/index.html": NEW_LINKS["the_haunted_image"],
    # "works/work-six/index.html": NEW_LINKS["making_conversation"],
}

# 默认会处理这些文件；你也可以让它扫描所有 .html
DEFAULT_FILES = ["index.html", "work.html"]


def backup_file(p: Path) -> Path:
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    bak = p.with_suffix(p.suffix + f".bak.{ts}")
    bak.write_text(p.read_text(encoding="utf-8"), encoding="utf-8")
    return bak


def replace_in_text(text: str, replace_map: dict) -> tuple[str, int]:
    count = 0
    for old, new in replace_map.items():
        # 只替换精确字符串（保守）
        if old in text:
            text = text.replace(old, new)
            count += 1
    return text, count


def main():
    root = Path(".").resolve()

    # 你可以把 scan_all_html 改成 True，让它扫描根目录下所有 .html
    scan_all_html = False

    if scan_all_html:
        targets = sorted([p for p in root.glob("*.html") if p.is_file()])
    else:
        targets = [root / f for f in DEFAULT_FILES if (root / f).exists()]

    if not targets:
        print("⚠️ No target HTML files found. (Expected index.html / work.html)")
        return

    total_changed_files = 0
    for p in targets:
        original = p.read_text(encoding="utf-8")
        updated, hits = replace_in_text(original, REPLACE_MAP)

        if updated != original:
            bak = backup_file(p)
            p.write_text(updated, encoding="utf-8")
            total_changed_files += 1
            print(f"✅ Updated: {p.name}  (replacements: {hits})  backup: {bak.name}")
        else:
            print(f"— No change: {p.name}")

    print("\nDone.")
    print("If anything looks wrong, restore from the .bak file.")


if __name__ == "__main__":
    main()
