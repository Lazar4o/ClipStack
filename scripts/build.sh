#!/usr/bin/env bash
# Builds ClipStack.app into ./build and signs it.
# Usage: scripts/build.sh            (env SIGN_ID overrides the signing identity)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # path has spaces → quote everything
APP_NAME="ClipStack"
SIGN_ID="${SIGN_ID:-ClipStack Dev}"
cd "$ROOT"

swift build -c release --product "$APP_NAME"
BIN="$(swift build -c release --show-bin-path)/$APP_NAME"

APP="$ROOT/build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/"
fi
plutil -lint "$APP/Contents/Info.plist" >/dev/null

if security find-identity -p codesigning | grep -q "\"$SIGN_ID\""; then
  codesign --force --timestamp=none --sign "$SIGN_ID" "$APP"
else
  echo "WARNING: signing identity \"$SIGN_ID\" not found → ad-hoc signature." >&2
  echo "         Accessibility must be re-granted after every rebuild (docs/PLAN.md Step 0)." >&2
  codesign --force --sign - "$APP"
fi
codesign --verify --strict "$APP"
echo "Built $APP"
