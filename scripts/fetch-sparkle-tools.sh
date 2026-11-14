#!/bin/bash
# Official, pinned maintainer tools. Private keys are never downloaded or exported.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD/build/dependencies/Sparkle-2.10.1"
if [ ! -f "$ROOT/.verified" ]; then
 mkdir -p build/dependencies
 WORK=$(mktemp -d "$PWD/build/dependencies/download.XXXXXX")
 trap 'rm -rf "$WORK"' EXIT
 curl --fail --location --silent --show-error https://github.com/sparkle-project/Sparkle/releases/download/2.10.1/Sparkle-2.10.1.tar.xz -o "$WORK/Sparkle.tar.xz"
 printf '%s  %s\n' 1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27 "$WORK/Sparkle.tar.xz" | shasum -a 256 --check >&2
 mkdir -p "$ROOT";tar -xJf "$WORK/Sparkle.tar.xz" -C "$ROOT"
 touch "$ROOT/.verified"
fi
printf '%s\n' "$ROOT"
