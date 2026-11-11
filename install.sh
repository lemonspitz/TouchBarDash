#!/bin/bash
# One-line installer for TouchBarDash:
#   curl -fsSL https://raw.githubusercontent.com/lemonspitz/TouchBarDash/main/install.sh | bash
set -euo pipefail

APP_NAME="TouchBarDash.app"
URL="https://github.com/lemonspitz/TouchBarDash/releases/latest/download/TouchBarDash.zip"

if [ "$(uname -m)" != "arm64" ]; then
  echo "TouchBarDash needs an Apple Silicon Mac with a Touch Bar (13-inch MacBook Pro M1 or M2)." >&2
  exit 1
fi

DEST="/Applications"
[ -w "$DEST" ] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading TouchBarDash…"
curl -fsSL "$URL" -o "$TMP/TouchBarDash.zip"
ditto -x -k "$TMP/TouchBarDash.zip" "$TMP"

pkill -x TouchBarDash 2>/dev/null || true
rm -rf "$DEST/$APP_NAME"
ditto "$TMP/$APP_NAME" "$DEST/$APP_NAME"
xattr -dr com.apple.quarantine "$DEST/$APP_NAME" 2>/dev/null || true

echo "Installed to $DEST/$APP_NAME — look for ⛅️ in the menu bar and the Touch Bar's Control Strip."
open "$DEST/$APP_NAME"
