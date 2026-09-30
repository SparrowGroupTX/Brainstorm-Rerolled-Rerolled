"""Root-owned staging only. Default is a read-only complete hash check."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import os
import tempfile
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def checked_path(root, name):
    path = (root / name).resolve()
    path.relative_to(root.resolve())
    return path


def check():
    manifest = json.loads((HERE / 'integration_manifest.json').read_text())
    assert manifest['kind'] == 'cashout_fixtures317_detached_ready'
    for name, expected in manifest['files'].items():
        assert sha(checked_path(HERE, name)) == expected, 'Changed reviewed draft: ' + name
    changes = []
    for name, info in manifest['integration'].items():
        target = checked_path(ROOT, name)
        source = checked_path(HERE, info['draft'])
        assert sha(source) == info['candidate_sha256'], 'Changed candidate: ' + name
        current = sha(target) if target.exists() else None
        assert current == info['base_sha256'], 'Current root differs; do not overwrite: ' + name
        changes.append((target, source, info))
    return manifest, changes


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--stage', action='store_true')
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--expected-manifest')
    args = parser.parse_args()
    manifest, changes = check()
    digest = sha(HERE / 'integration_manifest.json')
    if not args.stage:
        print(json.dumps({'status': 'checked_not_staged', 'files': len(changes), 'manifest_sha256': digest}))
        return
    assert args.expected_manifest == digest, 'Root must specify the exact reviewed manifest hash'
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8]
    backup = HERE / 'staging_backups' / stamp
    backup.mkdir(parents=True, exist_ok=False)
    receipt = {'status': 'staging_started', 'manifest_sha256': digest, 'files': {},
               'installation': False, 'version_change': False, 'settings_or_saves': 'not accessed'}
    for target, source, info in changes:
        relative = target.relative_to(ROOT)
        receipt['files'][relative.as_posix()] = dict(info)
        if target.exists():
            saved = backup / relative
            saved.parent.mkdir(parents=True, exist_ok=True)
            saved.open('xb').write(target.read_bytes())
            assert sha(saved) == info['base_sha256']
    (backup / 'started.json').open('x').write(json.dumps(receipt, indent=2) + '\n')
    # Validate again after backing up and immediately before each write.
    check()
    for target, source, info in changes:
        current = sha(target) if target.exists() else None
        assert current == info['base_sha256'], 'Concurrent root edit; staging stopped: ' + str(target)
        data = source.read_bytes()
        if info['base_sha256'] is None:
            target.open('xb').write(data)
        else:
            with tempfile.NamedTemporaryFile(dir=target.parent, prefix='.' + target.name + '.stage-', delete=False) as stream:
                stream.write(data)
                temporary = Path(stream.name)
            assert sha(target) == info['base_sha256'], 'Concurrent edit before replacement; preserved temp file: ' + str(temporary)
            os.replace(temporary, target)
        assert sha(target) == info['candidate_sha256'], 'Post-stage hash mismatch: ' + str(target)
    receipt['status'] = 'staged_not_installed'
    (backup / 'complete.json').open('x').write(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'status': receipt['status'], 'backup': str(backup), 'files': len(changes)}))


if __name__ == '__main__':
    main()
