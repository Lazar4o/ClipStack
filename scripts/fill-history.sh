#!/usr/bin/env bash
# Test helper: copies "clip 01" … "clip NN" with a pause longer than ClipStack's 0.5 s poll.
# Overwrites the real clipboard. Usage: scripts/fill-history.sh [count]
set -euo pipefail
COUNT="${1:-15}"
for i in $(seq 1 "$COUNT"); do
  printf "clip %02d" "$i" | pbcopy
  sleep 0.8
done
echo "Copied $COUNT test clips."
