#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift test --package-path Packages/InHebiCore
if [[ "${INHEBI_LIVE_TESTS:-0}" == 1 ]]; then
    echo "Live tests enabled (URLSession requests to public endpoints)."
fi
xcodebuild -project inHebi.xcodeproj -scheme inHebi \
  -sdk appletvsimulator -destination 'generic/platform=tvOS Simulator' \
  -derivedDataPath artifacts/DerivedDataSimulator CODE_SIGNING_ALLOWED=NO build
