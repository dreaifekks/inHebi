#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
device="${1:?Usage: ./script/fetch-focus-trace.sh DEVICE_ID [OUTPUT_FILE]}"
output="${2:-artifacts/FocusTrace-$(date +%Y%m%d-%H%M%S).txt}"
mkdir -p "$(dirname "$output")"
xcrun devicectl device copy from --device "$device" \
  --domain-type appDataContainer --domain-identifier com.dreaife.shelf \
  --source Library/Caches/Shelf/FocusTrace.txt --destination "$output"
