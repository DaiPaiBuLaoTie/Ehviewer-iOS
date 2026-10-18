"""Fast source/configuration checks; this is not an Xcode build."""
import json
import pathlib
import plistlib
import re
import xml.etree.ElementTree as ET

root = pathlib.Path(__file__).resolve().parents[1]
count = 0
for path in root.rglob('*'):
    if any(part in {'.git', 'build', '.tools', '.reference', '.planning'} for part in path.relative_to(root).parts):
        continue
    if path.suffix in {'.json', '.xcstrings', '.xctestplan', '.resolved'}:
        json.loads(path.read_text(encoding='utf-8-sig'))
        count += 1
    elif path.suffix in {'.plist', '.entitlements'}:
        plistlib.loads(path.read_bytes())
        count += 1
    elif path.suffix in {'.xcscheme', '.xcworkspacedata'}:
        ET.fromstring(path.read_bytes())
        count += 1
info = plistlib.loads((root / 'App/Info.plist').read_bytes())
project = (root / 'EhPanda.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
assert 'org.ehviewer.sxj.ios.shareExtension' in project
assert 'PRODUCT_BUNDLE_IDENTIFIER = org.ehviewer.sxj.ios;' in project
assert 'org.ehviewer.sxj.ios.downloads.processing' in info['BGTaskSchedulerPermittedIdentifiers']
assert 'processing' in info['UIBackgroundModes']
assert info['UIFileSharingEnabled'] is True
assert info['CFBundleDisplayName'] == 'EhViewer SXJ'
assert 'app.ehpanda.downloads.processing' not in (root / 'AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift').read_text()
workflow = (root / '.github/workflows/ios-unsigned.yml').read_text()
assert 'runs-on: macos-26' in workflow
assert 'secrets.' not in workflow
assert re.search(r'contents:\s*read', workflow)
for name in ['build-unsigned.sh', 'package-unsigned.sh', 'test-ios.sh']:
    assert b'\r' not in (root / 'Scripts' / name).read_bytes(), name + ' must use LF'
for path in [root / 'AppPackage/Package.resolved', root / 'EhPanda.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved']:
    assert path.is_file(), 'Missing dependency lock: ' + str(path)
print('Source/configuration checks passed (' + str(count) + ' structured files). Xcode compilation still required.')
