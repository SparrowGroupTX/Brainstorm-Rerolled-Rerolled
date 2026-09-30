"""Stage reviewed frame hooks only after exact source/base hash checks."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    manifest = json.loads((HERE / 'manifest.json').read_text(encoding='utf-8'))
    pending = []
    for item in manifest['integration']:
        source, target = HERE / item['source'], ROOT / item['target']
        if sha(source) != item['sha256']:
            raise SystemExit(f'Reviewed source changed: {source}')
        if target.exists():
            if item['base_sha256'] is None or sha(target) != item['base_sha256']:
                raise SystemExit(f'Existing work differs from reviewed base: {target}')
        elif item['base_sha256'] is not None:
            raise SystemExit(f'Expected base is absent: {target}')
        pending.append((source,target))
    backup = HERE / 'staging_backups' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    backup.mkdir(parents=True,exist_ok=False)
    for source,target in pending:
        if target.exists():
            saved = backup / target.relative_to(ROOT)
            saved.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(target,saved)
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(source,target)
    print(json.dumps({'status':'staged','backup':str(backup),'targets':[str(t) for _,t in pending]}))


if __name__ == '__main__':
    main()
