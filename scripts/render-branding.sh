#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
WORK=$(mktemp -d "$PWD/build/branding.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

swift scripts/render-icon.swift assets/icon.svg "$WORK/app.png"
sips -z 1024 1024 "$WORK/app.png" --out assets/app-icon.png >/dev/null
swift scripts/render-icon.swift assets/menu-bar.svg "$WORK/menu.png"
sips -z 18 18 "$WORK/menu.png" --out assets/MenuBarIcon.png >/dev/null
sips -z 36 36 "$WORK/menu.png" --out assets/MenuBarIcon@2x.png >/dev/null
printf 'Rendered app preview and 1x/2x menu-bar assets.\n'
