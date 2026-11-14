#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p build/CaptureQAHost.app/Contents/MacOS
swiftc Tests/NativeHost/main.swift -framework AppKit -o build/CaptureQAHost.app/Contents/MacOS/CaptureQAHost
cat > build/CaptureQAHost.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>CaptureQAHost</string><key>CFBundleIdentifier</key><string>local.maxim.leviosa.qa-host</string><key>CFBundleName</key><string>LeviOsa Capture QA Host</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>
PLIST
codesign --force --sign - build/CaptureQAHost.app
