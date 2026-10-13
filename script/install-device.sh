#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
device="${1:?Usage: ./script/install-device.sh DEVICE_UDID}"
auth_args=()
if [[ -n "${SHELF_AUTH_KEY_PATH:-}" ]]; then
  auth_args=(-authenticationKeyPath "$SHELF_AUTH_KEY_PATH"
    -authenticationKeyID "${SHELF_AUTH_KEY_ID:?Set SHELF_AUTH_KEY_ID}"
    -authenticationKeyIssuerID "${SHELF_AUTH_KEY_ISSUER:?Set SHELF_AUTH_KEY_ISSUER}")
fi
revision="$(git rev-parse --short HEAD)"
build_number="$(git rev-list --count HEAD)"
xcodebuild -project Shelf.xcodeproj -scheme Shelf -configuration Debug \
  -sdk appletvos -destination "platform=tvOS,id=$device" \
  -derivedDataPath artifacts/DerivedDataDevice \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  "${auth_args[@]}" "SHELF_COMMIT=$revision" \
  "CURRENT_PROJECT_VERSION=$build_number" build
xcrun devicectl device install app --device "$device" \
  artifacts/DerivedDataDevice/Build/Products/Debug-appletvos/Shelf.app
