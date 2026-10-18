#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-$ROOT/build}"
mkdir -p "$BUILD_ROOT/screenshots" "$BUILD_ROOT/logs"
DEVICE_ID="$(xcrun simctl list devices booted --json | python3 -c '
import json, sys
obj = json.load(sys.stdin)
phones = [device for runtime, devices in obj["devices"].items() if "iOS" in runtime
          for device in devices if device.get("isAvailable") and "iPhone" in device["name"]]
if not phones:
    sys.exit("No booted iPhone simulator after tests")
print(phones[0]["udid"])
')"
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
