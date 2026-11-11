#!/bin/zsh
# Builds TouchBarDash and packages it for a GitHub release:
#   build/release/TouchBarDash.dmg  – open it and drag the app onto Applications
#   build/release/TouchBarDash.zip  – used by install.sh
set -euo pipefail
cd "$(dirname "$0")"
./build.sh
OUT=build/release
STAGE=build/obj/dmg
rm -rf "$OUT" "$STAGE" && mkdir -p "$OUT" "$STAGE"

ditto -c -k --sequesterRsrc --keepParent "build/TouchBarDash.app" "$OUT/TouchBarDash.zip"

ditto "build/TouchBarDash.app" "$STAGE/TouchBarDash.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "TouchBarDash" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$OUT/TouchBarDash.dmg"

(cd "$OUT" && shasum -a 256 TouchBarDash.dmg TouchBarDash.zip > SHA256SUMS.txt)
ls -lh "$OUT"
