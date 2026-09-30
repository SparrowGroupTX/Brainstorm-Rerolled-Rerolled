"""Root-controlled exact-base staging only. Never installs or removes work."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--stage', action='store_true')
    parser.add_argument('--backup-dir', type=Path)
    args = parser.parse_args()
    manifest_path = HERE / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    for row in manifest['package_files']:
        path = HERE / row['path']
        assert path.is_file() and sha(path) == row['sha256'], f'Package changed: {path}'
    for row in manifest['dependencies']:
        path = ROOT / row['path']
        assert path.is_file() and sha(path) == row['sha256'], f'Dependency changed: {path}'
    operations = []
    for row in manifest['integration']:
        source = HERE / row['source']
        target = ROOT / row['target']
        assert target.resolve().is_relative_to(ROOT), 'Target outside workspace'
        if row.get('base_sha256'):
            assert target.is_file() and sha(target) == row['base_sha256'], f'Root base changed: {target}'
        else:
            assert not target.exists(), f'Preserve existing target: {target}'
        operations.append((source, target))
    if args.check:
        print(json.dumps({'status': 'ready', 'manifest_sha256': sha(manifest_path), 'files': len(operations)}))
        return
    assert args.backup_dir, '--stage requires --backup-dir'
    backup = args.backup_dir.resolve()
    assert backup.is_relative_to(ROOT) and backup != ROOT and not backup.exists(), 'Use a new workspace backup directory'
    backup.mkdir(parents=True, exist_ok=False)
    shutil.copyfile(manifest_path, backup / 'manifest.reviewed.json')
    for source, target in operations:
        if target.exists():
            old = backup / target.relative_to(ROOT)
            old.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(target, old)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        assert sha(target) == sha(source)
    receipt = {'status': 'staged_only', 'manifest_sha256': sha(manifest_path),
               'files': [{'path': target.relative_to(ROOT).as_posix(), 'sha256': sha(target)} for _, target in operations]}
    with (backup / 'staging_receipt.json').open('x', encoding='utf8') as stream:
        json.dump(receipt, stream, indent=2)
        stream.write('\n')
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()
