#!/bin/bash
# Builds macos-app/build/BravePiP.app with swiftc (Xcode not required, Command Line Tools are enough).
set -euo pipefail
cd "$(dirname "$0")"

APP=build/BravePiP.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Resources/Info.plist "$APP/Contents/Info.plist"

swiftc -O -swift-version 5 \
  -target "$(uname -m)-apple-macos13.0" \
  -o "$APP/Contents/MacOS/BravePiP" \
  $(find PiPApp Views WindowManager Browser Messaging -name '*.swift')

codesign --force --sign - "$APP" >/dev/null
echo "Built $(pwd)/$APP"
