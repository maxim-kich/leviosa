#!/bin/zsh
set -eu
cd "${0:A:h}"
mkdir -p build
swiftc Sources/Recognizer.swift Tests/main.swift -o build/recognizer-tests
./build/recognizer-tests
swiftc Sources/Recognizer.swift Sources/GestureEditor.swift Tests/Editor/main.swift -o build/editor-tests
./build/editor-tests
swiftc Sources/PreferencesUpgrade.swift Tests/Preferences/main.swift -o build/preferences-tests
./build/preferences-tests
swiftc Sources/CornerGesture.swift Tests/Corner/main.swift -o build/corner-tests
./build/corner-tests
swiftc Sources/InAppUpdater.swift Sources/UpdateChecker.swift Tests/Updater/main.swift -F vendor -framework Sparkle -framework AppKit -Xlinker -rpath -Xlinker "$PWD/vendor" -o build/updater-tests
./build/updater-tests
swiftc Sources/OverlayGeometry.swift Tests/Overlay/main.swift -o build/overlay-tests
./build/overlay-tests
swiftc Sources/Recognizer.swift Sources/CaptureLifecycle.swift Sources/DrawingPad.swift Tests/Pad/main.swift -framework AppKit -o build/pad-tests
./build/pad-tests
swiftc Sources/CaptureLifecycle.swift Tests/Lifecycle/main.swift -o build/lifecycle-tests
./build/lifecycle-tests
swiftc Sources/CaptureLifecycle.swift Sources/DrawingCommandTap.swift Sources/DrawingKeyboard.swift Tests/Keyboard/main.swift -framework AppKit -framework Carbon -o build/keyboard-tests
./build/keyboard-tests
swiftc Sources/Recognizer.swift Sources/CaptureLifecycle.swift Sources/DrawingPad.swift Sources/DrawingCursor.swift Tests/Cursor/main.swift -framework AppKit -o build/cursor-tests
./build/cursor-tests
swiftc Sources/ActivationShortcut.swift Tests/Shortcut/main.swift -framework AppKit -framework Carbon -o build/shortcut-tests
./build/shortcut-tests
