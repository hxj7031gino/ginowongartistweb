#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$HOME/Desktop/github/my-cv}"
PROJ="$ROOT/works/projects/p-2024-002-the-haunted-image"
VIDDIR="$PROJ/video"
MP4="$VIDDIR/detail.mp4"
WEBM="$VIDDIR/detail.webm"

echo "Project: $PROJ"

[[ -d "$PROJ" ]] || { echo "❌ Missing project folder: $PROJ"; exit 1; }

if [[ ! -d "$VIDDIR" ]]; then
  echo "❌ Missing video folder: $VIDDIR"
  echo "   Create it: mkdir -p \"$VIDDIR\""
  exit 1
fi

if [[ ! -f "$MP4" ]]; then
  echo "❌ Missing required file: $MP4"
  echo "   Put your MP4 here and name it exactly: detail.mp4"
  exit 1
fi

echo "✅ Found: $MP4"
ls -lh "$MP4"

FTYPE="$(file -b "$MP4")"
echo "file(detail.mp4): $FTYPE"
if echo "$FTYPE" | grep -qiE 'mp4|ISO Base Media|MPEG-4'; then
  echo "✅ MP4 container looks OK"
else
  echo "⚠️  detail.mp4 doesn't look like an MP4 container (check export/rename)."
fi

if [[ -f "$WEBM" ]]; then
  echo "✅ Found optional: $WEBM"
  ls -lh "$WEBM"
  WTYPE="$(file -b "$WEBM")"
  echo "file(detail.webm): $WTYPE"
  if echo "$WTYPE" | grep -qiE 'WebM|Matroska'; then
    echo "✅ WebM container looks OK"
  else
    echo "⚠️  detail.webm doesn't look like a WebM container (check export/rename)."
  fi
else
  echo "ℹ️  Optional file not found (OK): $WEBM"
fi

echo
echo "Scanning for other video files under: $VIDDIR"
FOUND="$(find "$VIDDIR" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mov" \) -print)"
if [[ -n "${FOUND:-}" ]]; then
  echo "$FOUND"
  if echo "$FOUND" | grep -qE '[[:space:]]'; then
    echo "⚠️  Found filenames with spaces. Prefer: lowercase + hyphens, no spaces."
  fi
  if echo "$FOUND" | grep -qE '[A-Z]'; then
    echo "⚠️  Found uppercase letters. Prefer lowercase for web hosting consistency."
  fi
else
  echo "No other video files found (good)."
fi

echo
echo "✅ Verification complete."
