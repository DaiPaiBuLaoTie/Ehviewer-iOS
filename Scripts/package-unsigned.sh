#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:?Usage: package-unsigned.sh app-path output-ipa}"
OUTPUT="${2:?Specify output IPA}"
[[ -d "$APP_PATH" && -f "$APP_PATH/Info.plist" ]] || { echo 'Missing archived app' >&2; exit 1; }
mkdir -p "$(dirname "$OUTPUT")"
OUTPUT_DIR="$(cd "$(dirname "$OUTPUT")" && pwd)"
OUTPUT="$OUTPUT_DIR/$(basename "$OUTPUT")"
STAGING="$(mktemp -d "$OUTPUT_DIR/ipa-stage.XXXXXX")"
trap 'rm -rf -- "$STAGING"' EXIT
mkdir "$STAGING/Payload"
ditto "$APP_PATH" "$STAGING/Payload/EhPanda.app"
# Strip only the temporary copy, preserving the original archive.
find "$STAGING/Payload" -depth -type d \( -name '*.app' -o -name '*.appex' -o -name '*.framework' \) -print0 |
  while IFS= read -r -d '' bundle; do
    if codesign -dv "$bundle" >/dev/null 2>&1; then
      codesign --remove-signature "$bundle"
    fi
  done
find "$STAGING/Payload" -type f -name '*.dylib' -print0 |
  while IFS= read -r -d '' library; do
    if codesign -dv "$library" >/dev/null 2>&1; then
      codesign --remove-signature "$library"
    fi
  done
python3 "$ROOT/Scripts/clean-staged-app.py" "$STAGING/Payload"
(cd "$STAGING" && /usr/bin/zip -q -r -y "$STAGING/output.ipa" Payload)
mv "$STAGING/output.ipa" "$OUTPUT"
python3 "$ROOT/Scripts/verify-ipa.py" "$OUTPUT"
python3 "$ROOT/Scripts/write-build-info.py" "$OUTPUT"
