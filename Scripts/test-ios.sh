#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-$ROOT/build}"
mkdir -p "$BUILD_ROOT/logs"
cd "$ROOT"
collect_test_summary() {
  if [ -d "$BUILD_ROOT/Tests.xcresult" ]; then
    xcrun xcresulttool get test-results summary --path "$BUILD_ROOT/Tests.xcresult" \
      > "$BUILD_ROOT/test-summary.json" || true
  fi
}
trap collect_test_summary EXIT
DEVICE_ID="$(xcrun simctl list devices available --json | python3 -c '
import json, sys
obj = json.load(sys.stdin)
phones = [device for runtime, devices in obj["devices"].items() if "iOS" in runtime
          for device in devices if device.get("isAvailable") and "iPhone" in device["name"]]
if not phones:
    sys.exit("No available iPhone simulator on runner")
print(phones[0]["udid"])
')"
printf '%s' "$DEVICE_ID" > "$BUILD_ROOT/simulator-device-id"
xcodebuild -quiet test \
  -project EhPanda.xcodeproj -scheme EhPanda \
  -testPlan FeatureTests \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath "$BUILD_ROOT/DerivedData" \
  -clonedSourcePackagesDirPath "$BUILD_ROOT/SourcePackages" \
  -onlyUsePackageVersionsFromResolvedFile \
  -skipMacroValidation -skipPackagePluginValidation \
  -resultBundlePath "$BUILD_ROOT/Tests.xcresult" \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "$BUILD_ROOT/logs/tests.log"
