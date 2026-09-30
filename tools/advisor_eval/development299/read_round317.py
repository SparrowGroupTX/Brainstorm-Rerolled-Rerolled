"""Read only the three identified opt-in public log segments; no evaluation."""
from pathlib import Path
from collections import deque, Counter
import hashlib
import io
import json
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from read_player_log import records

base = Path('C:/Users/trevo/AppData/Roaming/Balatro/advisor_player_log_v2')
recent, counts, sources = deque(maxlen=12), Counter(), []
total = 0
for number in (1, 2, 3):
    path = base / f'session-20260914T201348Z-1-{number:06}.brj'
    assert path.stat().st_size <= 1048576
    data = path.read_bytes()
    sources.append({'name': path.name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
    for raw, metadata in records(io.BytesIO(data)):
        event = json.loads(raw)
        total += 1
        assert total <= 3000
        details, context = event.get('details') or {}, event.get('context') or {}
        snapshot = context.get('snapshot') or {}
        counts[event.get('kind')] += 1
        allowed = ('event', 'reason', 'detail', 'error', 'message', 'status', 'state', 'owner', 'action',
                   'search_id', 'request_id', 'generation', 'accepted', 'action_kind', 'callback_returned', 'completion')
        def compact(value, depth=0):
            if depth > 3:
                return '<nested>'
            if isinstance(value, str):
                return value[:800]
            if isinstance(value, list):
                return [compact(v, depth+1) for v in value[:8]]
            if isinstance(value, dict):
                return {k: compact(v, depth+1) for k, v in value.items()
                        if k in ('kind', 'area', 'indices', 'order', 'title', 'status', 'lines', 'error', 'reason', 'accepted')}
            return value
        recent.append({'at': event.get('at'), 'kind': event.get('kind'), 'sequence': event.get('sequence'),
                       'details': {key: compact(details[key]) for key in allowed if key in details},
                       'loaded_version': context.get('version'), 'phase': snapshot.get('phase'),
                       'state': snapshot.get('state'), 'ante': snapshot.get('ante'),
                       'chips': snapshot.get('chips'), 'target': (snapshot.get('blind') or {}).get('chips')})
result = {'sources': sources, 'count': total, 'kinds': counts, 'recent': list(recent),
          'scope': 'Read-only public startup/action diagnostic; no policy or save evaluation'}
if sys.argv[1:] == ['--record']:
    output = Path(__file__).resolve().parent / 'public_cashout317.json'
    with output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2)
        stream.write('\n')
    print(str(output))
else:
    assert not sys.argv[1:]
    print(json.dumps(result, indent=2))
