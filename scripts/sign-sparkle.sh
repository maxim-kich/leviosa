#!/bin/bash
# SPDX-License-Identifier: MIT
# Sign nested updater components inside out.
set -euo pipefail
APP="$1"; IDENTITY="$2"; RELEASE="$3"
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
OPTIONS=(--force --sign "$IDENTITY")
if [ "$RELEASE" = 1 ]; then OPTIONS+=(--options runtime --timestamp); fi
for COMPONENT in Versions/B/XPCServices/Downloader.xpc Versions/B/XPCServices/Installer.xpc Versions/B/Autoupdate Versions/B/Updater.app; do
 codesign "${OPTIONS[@]}" "$FRAMEWORK/$COMPONENT"
done
codesign "${OPTIONS[@]}" "$FRAMEWORK"
