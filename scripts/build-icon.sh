#!/bin/bash
set -euo pipefail
DESTINATION="$1"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/leviosa-icon.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
swift scripts/render-icon.swift assets/icon.svg "$WORK/icon.png"
mkdir -p "$WORK/AppIcon.iconset"
for SIZE in 16 32 128 256 512; do
 sips -z "$SIZE" "$SIZE" "$WORK/icon.png" --out "$WORK/AppIcon.iconset/icon_${SIZE}x${SIZE}.png" >/dev/null
 DOUBLE=$((SIZE * 2))
 sips -z "$DOUBLE" "$DOUBLE" "$WORK/icon.png" --out "$WORK/AppIcon.iconset/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$WORK/AppIcon.iconset" -o "$DESTINATION"
