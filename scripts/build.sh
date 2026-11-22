#!/usr/bin/env bash
# Builds ClipStack.app into ./build and signs it (hardened runtime).
# Usage: scripts/build.sh
#   SIGN_ID=...      signing identity (default "ClipStack Dev"; ad-hoc if missing)
#   CONFIG=debug     debug build (includes the DebugHooks used for development)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # path has spaces → quote everything
APP_NAME="ClipStack"
SIGN_ID="${SIGN_ID:-ClipStack Dev}"
CONFIG="${CONFIG:-release}"
cd "$ROOT"

swift build -c "$CONFIG" --product "$APP_NAME"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"

APP="$ROOT/build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/"
fi
plutil -lint "$APP/Contents/Info.plist" >/dev/null

# Hardened runtime (--options runtime): blocks DYLD_INSERT_LIBRARIES-style code injection, so no other
# program can borrow ClipStack's Accessibility permission. ClipStack needs no entitlements for it.
if security find-identity -p codesigning | grep -q "\"$SIGN_ID\""; then
  codesign --force --options runtime --timestamp=none --sign "$SIGN_ID" "$APP"
else
  echo "WARNING: signing identity \"$SIGN_ID\" not found → ad-hoc signature." >&2
  echo "         Accessibility must be re-granted after every rebuild (README: signing setup)." >&2
  codesign --force --options runtime --sign - "$APP"
fi
codesign --verify --strict "$APP"
echo "Built $APP"
