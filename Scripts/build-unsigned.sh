#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-$ROOT/build}"
mkdir -p "$BUILD_ROOT/logs" "$BUILD_ROOT/artifacts"
cd "$ROOT"
python3 Scripts/verify-source.py
xcodebuild -quiet archive \
  -project EhPanda.xcodeproj -scheme EhPanda -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$BUILD_ROOT/EhViewer-SXJ.xcarchive" \
  -derivedDataPath "$BUILD_ROOT/DerivedData" \
  -clonedSourcePackagesDirPath "$BUILD_ROOT/SourcePackages" \
  -onlyUsePackageVersionsFromResolvedFile \
  -skipMacroValidation -skipPackagePluginValidation \
  -resultBundlePath "$BUILD_ROOT/Archive.xcresult" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY= CODE_SIGN_ENTITLEMENTS= \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= \
  CURRENT_PROJECT_VERSION="${GITHUB_RUN_NUMBER:-1}" \
  2>&1 | tee "$BUILD_ROOT/logs/archive.log"
bash Scripts/package-unsigned.sh \
  "$BUILD_ROOT/EhViewer-SXJ.xcarchive/Products/Applications/EhPanda.app" \
  "$BUILD_ROOT/artifacts/EhViewer-SXJ-iOS-unsigned.ipa"
