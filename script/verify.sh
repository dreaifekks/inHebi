#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift test --package-path Packages/ShelfCore
if [[ "${SHELF_LIVE_TESTS:-0}" == 1 ]]; then
    echo "Live tests enabled (URLSession requests to public endpoints)."
fi
xcodebuild -project Shelf.xcodeproj -scheme Shelf \
  -sdk appletvsimulator -destination 'generic/platform=tvOS Simulator' \
  -derivedDataPath artifacts/DerivedDataSimulator CODE_SIGNING_ALLOWED=NO build
