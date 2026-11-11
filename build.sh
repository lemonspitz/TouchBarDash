#!/bin/zsh
# Builds a native Apple Silicon "TouchBarDash.app" into ./build
set -euo pipefail
cd "$(dirname "$0")"

APP="build/TouchBarDash.app"
rm -rf build && mkdir -p build/obj "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 -target arm64-apple-macos13.0 \
  -framework AppKit -framework ServiceManagement -framework CoreLocation \
  Sources/*.swift -o build/obj/TouchBarDash
cp build/obj/TouchBarDash "$APP/Contents/MacOS/TouchBarDash"

ICONSET=build/obj/AppIcon.iconset
mkdir -p "$ICONSET"
build/obj/TouchBarDash --icon build/obj
for s in 16 32 128 256 512; do
  cp "build/obj/icon_$s.png" "$ICONSET/icon_${s}x${s}.png"
  cp "build/obj/icon_$((s * 2)).png" "$ICONSET/icon_${s}x${s}@2x.png"
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>TouchBarDash</string>
  <key>CFBundleIdentifier</key><string>com.lemonspitz.touchbardash</string>
  <key>CFBundleName</key><string>TouchBarDash</string>
  <key>CFBundleDisplayName</key><string>TouchBarDash</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>NSHumanReadableCopyright</key><string>Made by @lemonspitz · github.com/lemonspitz</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.weather</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSLocationUsageDescription</key><string>TouchBarDash uses your location to show local weather on the Touch Bar.</string>
  <key>NSLocationWhenInUseUsageDescription</key><string>TouchBarDash uses your location to show local weather on the Touch Bar.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Built $APP"
