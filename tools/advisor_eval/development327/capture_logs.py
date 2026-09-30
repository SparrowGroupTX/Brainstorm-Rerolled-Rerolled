"""One bounded passive capture of new public observation logs; never game/save IO."""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import re
import time

HERE = Path(__file__).resolve().parent
ROOT = Path('C:/Users/trevo/AppData/Roaming/Balatro')
CAPS = {'metadata_entries': 4096, 'metadata_seconds': 10, 'files': 8,
        'physical_bytes': 64 * 1024 * 1024, 'copy_seconds': 20}
PATTERN = re.compile(r'^(session-\d{8}T\d{6}Z-\d+)-(\d{6})\.brj$')


def write(name, value):
    with (HERE / name).open('x', encoding='utf-8') as f:
        json.dump(value, f, indent=2)
        f.write('\n')


write('read_plan.json', {'authorization': 'User explicitly requested inspection of current logs for bugs and lossless bloat reduction.',
      'scope': 'Direct public observation logs only; no saves, profiles, executable, gameplay, rescoring, search, simulation or experiment.',
      'caps': CAPS, 'at_utc': datetime.now(timezone.utc).isoformat(),
      'selection': 'Newest BRJ2 session by timestamp filename, newest contiguous suffix of at most eight files and64MiB. Copy a fixed byte prefix at capture; preserve changing/truncated tails explicitly.'})
start = time.monotonic()
inventory = []
for name in ('advisor_player_log_v1', 'advisor_player_log_v2'):
    directory = ROOT / name
    if not directory.exists():
        continue
    assert not directory.is_symlink() and not directory.is_junction()
    for path in directory.iterdir():
        assert len(inventory) < CAPS['metadata_entries'] and time.monotonic() - start < CAPS['metadata_seconds']
        assert path.is_file() and not path.is_symlink() and not path.is_junction()
        meta = path.stat()
        match = PATTERN.fullmatch(path.name)
        inventory.append({'path': str(path), 'bytes': meta.st_size, 'mtime_ns': meta.st_mtime_ns,
                          'session': match[1] if match else None, 'segment': int(match[2]) if match else None})
matches = [r for r in inventory if r['session']]
assert matches, 'No new BRJ2 observation files are present.'
session = max(r['session'] for r in matches)
group = {r['segment']: r for r in matches if r['session'] == session}
selected = []
size = 0
for segment in range(max(group), 0, -1):
    if segment not in group or len(selected) >= CAPS['files'] or size + group[segment]['bytes'] > CAPS['physical_bytes']:
        break
    selected.append(group[segment]);size += group[segment]['bytes']
selected.reverse()
assert selected
write('inventory.json', {'at_utc': datetime.now(timezone.utc).isoformat(), 'files': inventory,
                         'selected': selected, 'total_bytes': sum(r['bytes'] for r in inventory)})
destination = HERE / 'captured_logs'
destination.mkdir(exist_ok=False)
receipts = []
start = time.monotonic()
for row in selected:
    assert time.monotonic() - start < CAPS['copy_seconds']
    path = Path(row['path'])
    before = path.stat()
    # The whole request reserves the fixed inventory prefix, never follows growth.
    assert before.st_size >= row['bytes']
    with path.open('rb') as f:
        data = f.read(row['bytes'])
    assert len(data) == row['bytes']
    after = path.stat()
    target = destination / path.name
    with target.open('xb') as f:
        f.write(data)
    receipts.append({**row, 'captured_path': str(target), 'sha256': hashlib.sha256(data).hexdigest(),
                     'before_bytes': before.st_size, 'after_bytes': after.st_size,
                     'after_mtime_ns': after.st_mtime_ns,
                     'metadata_unchanged': row['bytes'] == before.st_size == after.st_size and
                        row['mtime_ns'] == before.st_mtime_ns == after.st_mtime_ns})
write('capture.json', {'session': session, 'caps': CAPS, 'files': receipts,
                      'physical_bytes': size, 'elapsed_seconds': time.monotonic() - start,
                      'prefix_capture_not_complete_session_claim': True})
print(json.dumps({'inventory_files': len(inventory), 'inventory_bytes': sum(r['bytes'] for r in inventory),
                  'session': session, 'selected_files': len(receipts), 'captured_bytes': size,
                  'all_metadata_unchanged': all(r['metadata_unchanged'] for r in receipts)}))
