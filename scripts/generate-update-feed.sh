#!/bin/bash
# SPDX-License-Identifier: MIT
# No network writes; all URLs are future publication targets.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(cat VERSION);ARCHIVE="$1";OUTPUT="$2"
TOOLS="${LEVIOSA_SPARKLE_TOOLS:-$(./scripts/fetch-sparkle-tools.sh)}"
ACCOUNT=com.maximkich.leviosa.updates
EXPECTED="LeviOsa-v${VERSION}-macOS-arm64.zip"
[ "$(basename "$ARCHIVE")" = "$EXPECTED" ] || { echo 'Unexpected archive name.' >&2;exit 1; }
[ ! -e "$OUTPUT" ] || { echo 'Refusing to overwrite a feed.' >&2;exit 1; }
[ "$("$TOOLS/bin/generate_keys" --account "$ACCOUNT" -p)" = "$(cat config/sparkle-public-key.txt)" ] || { echo 'Update key mismatch.' >&2;exit 1; }
WORK=$(mktemp -d "${TMPDIR:-/tmp}/leviosa-feed.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
cp "$ARCHIVE" "$WORK/$EXPECTED"
"$TOOLS/bin/generate_appcast" --account "$ACCOUNT" --maximum-deltas 0 --maximum-versions 1 --download-url-prefix "https://github.com/maxim-kich/leviosa/releases/download/v${VERSION}/" -o "$WORK/appcast.xml" "$WORK"
"$TOOLS/bin/sign_update" --account "$ACCOUNT" --verify "$WORK/appcast.xml"
cp "$WORK/appcast.xml" "$OUTPUT"
