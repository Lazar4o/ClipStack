#!/usr/bin/env bash
# Builds ClipStack, quits the running copy, replaces ~/Applications/ClipStack.app and relaunches it.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ClipStack"
DEST="$HOME/Applications"

"$ROOT/scripts/build.sh"

if pgrep -x "$APP_NAME" >/dev/null; then
  pkill -TERM -x "$APP_NAME" || true          # the app turns SIGTERM into a normal quit → history is flushed
  for _ in {1..30}; do
    pgrep -x "$APP_NAME" >/dev/null || break
    sleep 0.1
  done
  pkill -KILL -x "$APP_NAME" 2>/dev/null || true
fi

mkdir -p "$DEST"
rm -rf "$DEST/$APP_NAME.app"
ditto "$ROOT/build/$APP_NAME.app" "$DEST/$APP_NAME.app"
rm -rf "$ROOT/build/$APP_NAME.app"             # keep one copy only (no wrong-copy launches, no duplicate Spotlight hits)
open "$DEST/$APP_NAME.app"                      # always launch via `open`, never the raw binary
echo "Installed and launched $DEST/$APP_NAME.app"
