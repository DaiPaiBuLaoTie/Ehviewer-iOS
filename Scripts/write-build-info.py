import datetime
import hashlib
import json
import os
import pathlib
import subprocess
import sys

ipa = pathlib.Path(sys.argv[1]).resolve(strict=True)
digest = hashlib.file_digest(ipa.open('rb'), 'sha256').hexdigest()
ipa.with_suffix(ipa.suffix + '.sha256').write_text(digest + '  ' + ipa.name + '\n', encoding='utf-8')
info = {
    'file': ipa.name,
    'sha256': digest,
    'bytes': ipa.stat().st_size,
    'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
    'build_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'run_url': 'https://github.com/' + os.environ.get('GITHUB_REPOSITORY', '')
               + '/actions/runs/' + os.environ.get('GITHUB_RUN_ID', ''),
    'signing': 'unsigned; requires your own signing before installation',
    'android_reference': 'b44aafcdb1fe0270da2d3f45924d6de4b37b2cc4',
    'ios_base': '7a9051140db336c4a3ce0b883f005bacd8ce958f'
}
(ipa.parent / 'build-info.json').write_text(json.dumps(info, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
