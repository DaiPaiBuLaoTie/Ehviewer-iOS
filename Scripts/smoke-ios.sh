#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-$ROOT/build}"
mkdir -p "$BUILD_ROOT/screenshots" "$BUILD_ROOT/logs"
DEVICE_ID="$(cat "$BUILD_ROOT/simulator-device-id")"
STATE="$(xcrun simctl list devices available --json | python3 -c '
import json, sys
identity = sys.argv[1]
for devices in json.load(sys.stdin)["devices"].values():
    for device in devices:
        if device["udid"] == identity:
            print(device["state"])
            sys.exit(0)
sys.exit("Test simulator is no longer available")
' "$DEVICE_ID")"
if [ "$STATE" != "Booted" ]; then
  xcrun simctl boot "$DEVICE_ID"
fi
xcrun simctl bootstatus "$DEVICE_ID" -b

APP="$BUILD_ROOT/DerivedData/Build/Products/Debug-iphonesimulator/EhPanda.app"
BUNDLE_ID="org.ehviewer.sxj.ios"
xcrun simctl install "$DEVICE_ID" "$APP"
xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" | tee "$BUILD_ROOT/logs/launch.log"
sleep 5
xcrun simctl spawn "$DEVICE_ID" launchctl list > "$BUILD_ROOT/logs/simulator-processes.log"
python3 - "$BUILD_ROOT/logs/simulator-processes.log" "$BUNDLE_ID" <<'PY'
from pathlib import Path
import sys
entries = [line.split() for line in Path(sys.argv[1]).read_text().splitlines()]
if not any(len(entry) >= 3 and entry[0].isdigit() and sys.argv[2] in entry[-1] for entry in entries):
    sys.exit("Application did not remain running after launch")
print("Application remained running after launch")
PY
xcrun simctl io "$DEVICE_ID" screenshot "$BUILD_ROOT/screenshots/launch.png"
