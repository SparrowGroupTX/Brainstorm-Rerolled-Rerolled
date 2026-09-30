"""Read-only bounded passive observation prefix capture. No policy execution."""
import collections
import hashlib
import io
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'tools/advisor_eval'))
from read_player_log import records

HERE = Path(__file__).resolve().parent
SOURCE = Path(r'C:\Users\trevo\AppData\Roaming\Balatro\advisor_player_log_v2')
PREFIX = 'session-20260916T060145Z-1'
INPUTS = HERE / 'frozen_prefix'
INPUTS.mkdir(exist_ok=False)
paths = sorted(SOURCE.glob(PREFIX + '-*.brj'))
assert 1 <= len(paths) <= 16
lengths = {p: p.stat().st_size for p in paths}
assert sum(lengths.values()) <= 32 * 1024 * 1024
sha = lambda data: hashlib.sha256(data).hexdigest()
inputs, events, errors = [], [], []
counts, versions = collections.Counter(), collections.Counter()
for p in paths:
    before = p.stat()
    with p.open('rb') as handle:
        data = handle.read(lengths[p])
    after = p.stat()
    assert len(data) == lengths[p]
    frozen = INPUTS / p.name
    with frozen.open('xb') as handle:
        handle.write(data)
    entry = {'original_path': str(p), 'frozen_path': str(frozen), 'bytes': len(data), 'sha256': sha(data),
        'append_active': p == paths[-1], 'stat_unchanged_during_read':
        (before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns),
        'original_size_after_read': after.st_size}
    n = 0
    try:
        for ordinal, (raw, meta) in enumerate(records(io.BytesIO(data)), 1):
            e = json.loads(raw)
            n += 1
            c = e.get('context', {})
            s = c.get('snapshot', {})
            g = s.get('completionist_goal', {})
            counts[e.get('kind')] += 1
            if c.get('version'):
                versions[c['version']] += 1
            row = {key: e.get(key) for key in ('kind', 'at', 'monotonic_seconds', 'details')}
            row.update({'anchor': {'segment': p.name, 'ordinal': ordinal, 'sequence': e.get('sequence'),
                'decoded_event_sha256': sha(raw), 'stored_frame_sha256': meta.get('frame_sha256')},
                'context_keys': sorted(c), 'version': c.get('version'), 'seed': c.get('seed'),
                'state': {key: s.get(key) for key in ('ante','round','phase','state','dollars','chips','blind',
                    'hands_left','discards_left','reroll_cost','next_blind','next_blind_chips','win_ante',
                    'bankrupt_at','joker_limit','consumable_limit','consumeable_buffer','ordering_safe','jokers_shuffling')},
                'goal': {key: value for key, value in g.items() if key not in ('by_key','records','missing_keys','complete_keys','unknown_keys','held')},
                'jokers': [{**card, 'gold_status': g.get('by_key',{}).get(card.get('key'),{}).get('status')}
                    for card in s.get('jokers',[])],
                'shop_jokers': [{**card, 'gold_status': g.get('by_key',{}).get(card.get('key'),{}).get('status')}
                    for card in s.get('shop_jokers',[])],
                'advice': c.get('advice')})
            events.append(row)
    except Exception as exc:
        errors.append({'segment': p.name, 'after_complete_records': n, 'error': str(exc)})
    entry['event_count'] = n
    inputs.append(entry)
report = {'schema': 1, 'scope': 'Bounded read-only passive journal prefix capture and decode; no policy replay, simulations, source components, searches, save/profile reads or game control.',
    'prefix': PREFIX, 'inputs': inputs, 'hash_semantics': 'The SHA256 binds exactly the frozen observed byte prefix; the append-active original may grow later. Event and stored-frame anchors preserve original provenance.',
    'event_counts': dict(counts), 'loaded_versions': dict(versions), 'decode_errors': errors, 'events': events}
out = HERE / 'passive_audit.json'
with out.open('x', encoding='utf-8') as handle:
    json.dump(report, handle, indent=2)
    handle.write('\n')
print(json.dumps({'path': str(out), 'sha256': sha(out.read_bytes()), 'input_bytes': sum(v['bytes'] for v in inputs),
    'event_count': len(events), 'last_sequence': events[-1]['anchor']['sequence'],
    'loaded_versions': dict(versions), 'event_counts': dict(counts), 'decode_errors': errors,
    'last_events': [{key: e.get(key) for key in ('anchor','kind','at','details','version','seed','state','advice')} for e in events[-8:]]}))
