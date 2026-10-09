#!/bin/bash
# 배포용 DMG 만들기: ./release.sh → dist/Peek-<버전>.dmg + SHA-256
set -euo pipefail
cd "$(dirname "$0")"

./build.sh
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/Peek.app/Contents/Info.plist)
OUT="dist/Peek-$VERSION.dmg"
mkdir -p dist
rm -f "$OUT"

create-dmg \
  --volname "Peek $VERSION" \
  --volicon icon/AppIcon.icns \
  --background dmg/background.tiff \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 128 \
  --text-size 13 \
  --icon "Peek.app" 180 200 \
  --hide-extension "Peek.app" \
  --app-drop-link 480 200 \
  --no-internet-enable \
  "$OUT" build/Peek.app

shasum -a 256 "$OUT" | tee "$OUT.sha256"
