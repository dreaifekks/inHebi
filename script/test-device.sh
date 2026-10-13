#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
device="${1:?Usage: ./script/test-device.sh DEVICE_UDID [xcodebuild options]}"
shift
result="artifacts/device-ui-$(date +%Y%m%d-%H%M%S).xcresult"
mkdir -p artifacts/screenshots
test_status=0
xcodebuild -project Shelf.xcodeproj -scheme Shelf -configuration Debug \
  -sdk appletvos -destination "platform=tvOS,id=$device" \
  -derivedDataPath DerivedData -resultBundlePath "$result" \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  -parallel-testing-enabled NO "$@" test || test_status=$?
if [[ -d "$result" ]]; then
  python3 script/export-screenshots.py "$result"
fi
exit "$test_status"
