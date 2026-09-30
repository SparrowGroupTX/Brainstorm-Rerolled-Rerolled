"""Bounded metadata-only diagnosis of the reported startup byte-limit alert."""
from datetime import datetime, timezone
from pathlib import Path
import json
import time

HERE = Path(__file__).resolve().parent
LOG_ROOT = Path('C:/Users/trevo/AppData/Roaming/Balatro')
CAPS = {'directories': 2, 'entries': 4097, 'seconds': 10, 'content_bytes': 0}
destination = HERE / 'storage_metadata.json'
assert not destination.exists(), 'Preserve the original observation.'
started = time.monotonic()
rows = []
directories = []
complete = True
for name in ('advisor_player_log_v1', 'advisor_player_log_v2'):
    directory = LOG_ROOT / name
    if not directory.exists():
        directories.append({'name': name, 'exists': False})
        continue
    directories.append({'name': name, 'exists': True})
    for path in directory.iterdir():
        if len(rows) >= CAPS['entries'] or time.monotonic() - started >= CAPS['seconds']:
            complete = False
            break
        if path.is_symlink() or path.is_junction():
            rows.append({'path': str(path), 'status': 'link_not_followed'})
            complete = False
            continue
        meta = path.stat()
        rows.append({'path': str(path), 'kind': 'file' if path.is_file() else 'other',
                     'bytes': meta.st_size, 'mtime_ns': meta.st_mtime_ns})
    if not complete:
        break
total = sum(r.get('bytes', 0) for r in rows if r.get('kind') == 'file')
value = {'observed_at_utc': datetime.now(timezone.utc).isoformat(),
         'request': 'User reported a disappearing byte-maximum popup after restart while idle at the start screen.',
         'scope': 'File names, lengths and modification times only in the two public observation log directories. No content, save/profile, executable or game access.',
         'caps': CAPS, 'complete': complete, 'directories': directories, 'entries': rows,
         'total_file_bytes': total, 'runtime_limit_bytes': 134217728,
         'remaining_bytes_if_catalog_valid': 134217728 - total if complete else None,
         'elapsed_seconds': time.monotonic() - started,
         'user_reported_restart': True, 'loaded_version_or_hashes_attested': False,
         'source_captured_search_complete_experiments': 0}
with destination.open('x', encoding='utf-8') as stream:
    json.dump(value, stream, indent=2)
    stream.write('\n')
print(json.dumps({k: value[k] for k in ('complete', 'total_file_bytes', 'runtime_limit_bytes',
                                     'remaining_bytes_if_catalog_valid', 'elapsed_seconds')}))
print('Catalog entries:', len(rows))
