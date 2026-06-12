#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from pathlib import Path
import re
from datetime import datetime

ROOT = Path(".").resolve()
PROJECTS_DIR = ROOT / "works" / "projects"

# 只处理你现在 WARN 的这三个项目（精准、不乱动其它）
TARGET_SLUGS = {
    "p-2022-001-columbarium-of-the-days",
    "p-2024-001-the-awarded",
    "p-2024-002-the-haunted-image",
}

IMG_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".JPG", ".JPEG", ".PNG", ".WEBP"}

def backup(p: Path) -> Path:
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    bak = p.with_suffix(p.suffix + f".bak.{ts}")
    bak.write_text(p.read_text(encoding="utf-8"), encoding="utf-8")
    return bak

def main():
    if not PROJECTS_DIR.exists():
        print("❌ works/projects not found")
        return

    # Map for updating HTML references: "img/01.jpg" -> "img/001.jpg" (case-insensitive ext handled)
    ref_map = {}

    renamed_total = 0
    updated_html = 0

    for slug in sorted(TARGET_SLUGS):
        proj = PROJECTS_DIR / slug
        img_dir = proj / "img"
        if not img_dir.exists():
            print(f"⚠️ Skip (no img dir): {slug}")
            continue

        # 1) 收集需要改名的两位编号文件：01.jpg, 02.png ...
        to_rename = []
        for p in img_dir.iterdir():
            if not p.is_file():
                continue
            if p.suffix not in IMG_EXTS:
                continue
            m = re.fullmatch(r"(\d{2})\.(jpg|jpeg|png|webp|JPG|JPEG|PNG|WEBP)", p.name)
            if m:
                num2 = m.group(1)             # "01"
                ext = m.group(2)              # "jpg"/"png"...
                num3 = num2.zfill(3)          # "001"
                new_name = f"{num3}.{ext.lower()}"
                to_rename.append((p, new_name))

                # 建立 HTML 引用替换表（尽量覆盖各种扩展写法）
                # 例如 img/01.jpg -> img/001.jpg
                ref_map[f"img/{num2}.jpg"] = f"img/{num3}.jpg"
                ref_map[f"img/{num2}.jpeg"] = f"img/{num3}.jpeg"
                ref_map[f"img/{num2}.png"] = f"img/{num3}.png"
                ref_map[f"img/{num2}.webp"] = f"img/{num3}.webp"

        if not to_rename:
            print(f"— No 2-digit gallery files to rename: {slug}")
            continue

        # 2) 两阶段改名避免冲突：先改成临时名，再改成最终名
        temp_pairs = []
        for old_path, new_name in to_rename:
            tmp = old_path.with_name(f"__tmp__{old_path.name}")
            old_path.rename(tmp)
            temp_pairs.append((tmp, img_dir / new_name))

        for tmp, final in temp_pairs:
            # 如果最终名已经存在，避免覆盖：加后缀 _dup
            if final.exists():
                final = final.with_name(final.stem + "_dup" + final.suffix)
            tmp.rename(final)
            renamed_total += 1

        print(f"✅ Renamed gallery files to 3-digit: {slug} ({len(temp_pairs)} files)")

        # 3) 更新该项目的 index.html 里对 img/01.jpg 这类引用
        index_html = proj / "index.html"
        if index_html.exists():
            text = index_html.read_text(encoding="utf-8")
            original = text

            # 只替换 img/NN.ext 形式（简单稳妥）
            for old, new in ref_map.items():
                # 同时兼容大小写（把常见四种都替换一次）
                text = text.replace(old, new)
                text = text.replace(old.upper(), new)
                text = text.replace(old.replace("img/", "img/").title(), new)

            if text != original:
                bak = backup(index_html)
                index_html.write_text(text, encoding="utf-8")
                updated_html += 1
                print(f"   ✅ Updated index.html refs (backup: {bak.name})")
        else:
            print(f"⚠️ No index.html to update refs: {slug}")

    print("\nDone.")
    print(f"- Total renamed files: {renamed_total}")
    print(f"- Project pages updated: {updated_html}")

if __name__ == "__main__":
    main()
