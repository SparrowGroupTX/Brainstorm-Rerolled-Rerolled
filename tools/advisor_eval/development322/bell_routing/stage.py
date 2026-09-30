"""Stage only reviewed detached Bell routing bytes, preserving current work."""
from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import shutil

PACKAGE = Path(__file__).resolve().parent
ROOT = PACKAGE.parents[3]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    manifest = json.loads((PACKAGE / 'manifest.json').read_text(encoding='utf-8'))
    pending = []
    for item in manifest['integration']:
        source, target = PACKAGE / item['source'], ROOT / item['target']
        if digest(source) != item['sha256']:
            raise SystemExit(f'Candidate hash changed: {source}')
        if target.exists():
            if item['base_sha256'] is None or digest(target) != item['base_sha256']:
                raise SystemExit(f'Existing work differs from reviewed base: {target}')
        elif item['base_sha256'] is not None:
            raise SystemExit(f'Expected base file missing: {target}')
        pending.append((source, target))
    backup = PACKAGE / 'staging_backups' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    backup.mkdir(parents=True, exist_ok=False)
    for source, target in pending:
        if target.exists():
            preserved = backup / target.relative_to(ROOT)
            preserved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, preserved)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    print(json.dumps({'status': 'staged', 'backup': str(backup), 'files': [str(target) for _, target in pending]}))


if __name__ == '__main__':
    main()
