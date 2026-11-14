#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
VERSION=$(cat VERSION)
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid VERSION' >&2; exit 1; }
APP="${LEVIOSA_APP_PATH:-$PWD/build/LeviOsa.app}"
MODE="${LEVIOSA_RELEASE_SIGNING:-0}"
MINIMUM=13.0
IDENTITY="${LEVIOSA_SIGN_IDENTITY:--}"
BUNDLE=local.maxim.leviosa.review
if [ "$MODE" = 1 ]; then
 BUNDLE=com.maximkich.leviosa
 if [ "$IDENTITY" = - ]; then
  IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -1)
 fi
 [ -n "$IDENTITY" ] && [ "$IDENTITY" != - ] || { echo 'Developer ID Application identity required.' >&2; exit 1; }
fi
if pgrep -fx "$APP/Contents/MacOS/LeviOsa" >/dev/null; then
 echo 'Refusing to overwrite a running app; quit it or choose LEVIOSA_APP_PATH.' >&2; exit 1
fi
mkdir -p build "$APP/Contents/"{MacOS,Frameworks,Resources}
WORK=$(mktemp -d "$PWD/build/compile.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
./scripts/build-icon.sh "$WORK/AppIcon.icns"
cp "$WORK/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp assets/MenuBarIcon.png assets/MenuBarIcon@2x.png "$APP/Contents/Resources/"
ditto vendor/Sparkle.framework "$APP/Contents/Frameworks/Sparkle.framework"
# Remove generated project-license resources left by an older build.
rm -f "$APP/Contents/Resources/"LICENSE*.txt
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"
cp docs/licenses/Sparkle-LICENSE.txt "$APP/Contents/Resources/Sparkle-LICENSE.txt"
clang -target arm64-apple-macos$MINIMUM -c Sources/Trackpad.c -o "$WORK/Trackpad.o"
swiftc -O -target arm64-apple-macos$MINIMUM -import-objc-header Sources/Trackpad.h "$WORK/Trackpad.o" -swift-version 5 Sources/PreferencesUpgrade.swift Sources/GestureEditor.swift Sources/GestureSettingsView.swift Sources/ActivationShortcut.swift Sources/ShortcutRecorderView.swift Sources/CaptureLifecycle.swift Sources/DrawingCommandTap.swift Sources/DrawingKeyboard.swift Sources/DrawingPad.swift Sources/DrawingCursor.swift Sources/DrawingController.swift Sources/Recognizer.swift Sources/CornerGesture.swift Sources/OverlayGeometry.swift Sources/InAppUpdater.swift Sources/UpdateChecker.swift Sources/main.swift -F vendor -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks -o "$APP/Contents/MacOS/LeviOsa" -framework AppKit -framework Carbon
python3 scripts/configure-bundle.py "$APP/Contents/Info.plist" "$BUNDLE" "$VERSION" "$MINIMUM"
./scripts/sign-sparkle.sh "$APP" "$IDENTITY" "$MODE"
OPTIONS=(--force --sign "$IDENTITY")
if [ "$MODE" = 1 ]; then OPTIONS+=(--options runtime --timestamp); fi
codesign "${OPTIONS[@]}" "$APP"
codesign --verify --deep --strict "$APP"
if [ "$MODE" = 1 ]; then
 DETAILS=$(codesign -dvv "$APP" 2>&1)
 [[ "$DETAILS" == *"Authority=Developer ID Application:"* ]]
fi
printf 'Built %s\n' "$APP"
