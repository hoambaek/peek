#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Peek.app"
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

VERSION="1.0.0"
SOURCES=(Sources/Services.swift Sources/Shim.swift Sources/AdBlock.swift Sources/Sheets.swift
         Sources/PlayerWindow.swift Sources/AppDelegate.swift Sources/main.swift)

# 애플 실리콘·인텔 둘 다 돌도록 유니버설 바이너리로 묶는다
for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos13.0" "${SOURCES[@]}" -o "build/Peek-$arch"
done
lipo -create build/Peek-arm64 build/Peek-x86_64 -output "$APP/Contents/MacOS/Peek"
rm build/Peek-arm64 build/Peek-x86_64

cp icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>Peek</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>ko</string></array>
  <key>CFBundleIdentifier</key><string>com.orkney.peek</string>
  <key>CFBundleName</key><string>Peek</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIconName</key><string>AppIcon</string>
  <key>CFBundleDisplayName</key><string>Peek</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticTermination</key><false/>
</dict>
</plist>
PLIST

echo -n 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --deep --sign - "$APP" 2>/dev/null || true
echo "built: $(pwd)/$APP"
