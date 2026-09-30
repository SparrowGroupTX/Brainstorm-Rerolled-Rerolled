"""Read only one explicitly identified public action log; no saves or evaluation."""
from pathlib import Path
import hashlib
import io
import json
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from read_player_log import records

path = Path('C:/Users/trevo/AppData/Roaming/Balatro/advisor_player_log_v2/session-20260914T195043Z-1-000001.brj')
assert path.stat().st_size <= 1048576
data = path.read_bytes()
entries = []
for raw, metadata in records(io.BytesIO(data)):
    event = json.loads(raw)
    details = event.get('details') or {}
    context = event.get('context') or {}
    snapshot = context.get('snapshot') or {}
    entries.append({'at': event.get('at'), 'kind': event.get('kind'), 'sequence': event.get('sequence'),
                    'details': {key: details[key] for key in ('event', 'reason', 'detail', 'error', 'message', 'status', 'state', 'owner',
                        'search_id', 'request_id', 'generation', 'time', 'late_result_discarded') if key in details},
                    'loaded_version': context.get('version'), 'phase': snapshot.get('phase'),
                    'state': snapshot.get('state')})
    assert len(entries) <= 300
print(json.dumps({'source': str(path), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                  'events': entries}, indent=2))
