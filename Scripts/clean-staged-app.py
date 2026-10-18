"""Remove signing metadata from a temporary Payload copy only."""
import pathlib
import shutil
import sys

payload = pathlib.Path(sys.argv[1]).resolve(strict=True)
if payload.name != 'Payload' or not payload.parent.name.startswith('ipa-stage.'):
    raise SystemExit('Refusing to clean a non-staging directory')
for path in sorted(payload.rglob('*'), key=lambda item: len(item.parts), reverse=True):
    if path.is_symlink():
        continue
    if path.name == '_CodeSignature' and path.is_dir():
        shutil.rmtree(path)
    elif path.name == 'embedded.mobileprovision' and path.is_file():
        path.unlink()
