#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
device="${1:?Usage: ./script/install-device.sh DEVICE_UDID}"
signing_args=(-allowProvisioningUpdates -allowProvisioningDeviceRegistration)
if [[ -n "${INHEBI_AUTH_KEY_PATH:-}" ]]; then
  signing_args+=(-authenticationKeyPath "$INHEBI_AUTH_KEY_PATH"
    -authenticationKeyID "${INHEBI_AUTH_KEY_ID:?Set INHEBI_AUTH_KEY_ID}"
    -authenticationKeyIssuerID "${INHEBI_AUTH_KEY_ISSUER:?Set INHEBI_AUTH_KEY_ISSUER}")
fi
revision="$(git rev-parse --short HEAD)"
build_number="$(git rev-list --count HEAD)"
xcodebuild -project inHebi.xcodeproj -scheme inHebi -configuration Debug \
  -sdk appletvos -destination "platform=tvOS,id=$device" \
  -derivedDataPath artifacts/DerivedDataDevice \
  "${signing_args[@]}" "INHEBI_COMMIT=$revision" \
  "CURRENT_PROJECT_VERSION=$build_number" build
xcrun devicectl device install app --device "$device" \
  artifacts/DerivedDataDevice/Build/Products/Debug-appletvos/inHebi.app
