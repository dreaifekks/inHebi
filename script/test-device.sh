#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
device="${1:?Usage: ./script/test-device.sh DEVICE_UDID [xcodebuild options]}"
shift
result="artifacts/device-ui-$(date +%Y%m%d-%H%M%S).xcresult"
mkdir -p artifacts/screenshots
signing_args=(-allowProvisioningUpdates -allowProvisioningDeviceRegistration)
if [[ -n "${INHEBI_AUTH_KEY_PATH:-}" ]]; then
  signing_args+=(-authenticationKeyPath "$INHEBI_AUTH_KEY_PATH"
    -authenticationKeyID "${INHEBI_AUTH_KEY_ID:?Set INHEBI_AUTH_KEY_ID}"
    -authenticationKeyIssuerID "${INHEBI_AUTH_KEY_ISSUER:?Set INHEBI_AUTH_KEY_ISSUER}")
fi
test_status=0
xcodebuild -project inHebi.xcodeproj -scheme inHebi -configuration Debug \
  -sdk appletvos -destination "platform=tvOS,id=$device" \
  -derivedDataPath artifacts/DerivedDataDevice -resultBundlePath "$result" \
  -parallel-testing-enabled NO "${signing_args[@]}" "$@" test || test_status=$?
if [[ -d "$result" ]]; then
  python3 script/export-screenshots.py "$result"
fi
exit "$test_status"
