"""Freeze one named earlier passive session and inspect sealed latest pack choices."""
import collections
import hashlib
import io
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT / 'tools/advisor_eval'))
from read_player_log import records

def sha(data): return hashlib.sha256(data).hexdigest()
audit_path = HERE / 'passive_audit.json'
assert sha(audit_path.read_bytes()) == '532092c5bc654205c655d7e0fd123b8135393422acbab81026facff6ced194a7'
latest = json.loads(audit_path.read_bytes())
source = Path(r'C:\Users\trevo\AppData\Roaming\Balatro\advisor_player_log_v2')
prefix = 'session-20260916T053031Z-1'
frozen_dir = HERE / 'prior_frozen_prefix'
frozen_dir.mkdir(exist_ok=False)
paths = sorted(source.glob(prefix + '-*.brj'))
assert 1 <= len(paths) <= 16
lengths = {p: p.stat().st_size for p in paths}
assert sum(lengths.values()) <= 32 * 1024 * 1024

def anchor(event, ordinal, meta, segment, raw):
    return {'segment': segment, 'ordinal': ordinal, 'sequence': event.get('sequence'),
        'stored_frame_sha256': meta.get('frame_sha256'), 'decoded_event_sha256': sha(raw)}

def summarize_searches(events):
    out = []; start = None
    for e, a in events:
        if e.get('kind') == 'collection_search_started':
            start = {'anchor': a, 'at': e.get('at'), 'start_seed': e.get('details', {}).get('start_seed')}
        if e.get('kind') != 'collection_search_finished': continue
        d = e['details']; r = d['receipt']; request = r.get('request', {})
        out.append({'anchor': a, 'at': e.get('at'), 'loaded_version': e.get('context', {}).get('version'),
            'preceding_start': start, 'status': d.get('status'), 'result': r.get('result'),
            'request': {k: request.get(k) for k in ('deck', 'stake_level', 'tag', 'souls', 'target_jokers',
                'target_locations', 'reject_perishable_targets', 'minimum_distinct', 'first_ante', 'last_ante', 'interchangeable_copies')},
            'receipt_wall_seconds': r.get('elapsed_wall_seconds')})
    return out

prior_inputs = []; prior_versions = collections.Counter(); prior_events = []; prior_errors = []; prior_counts = collections.Counter()
for p in paths:
    before = p.stat()
    with p.open('rb') as handle: data = handle.read(lengths[p])
    after = p.stat(); assert len(data) == lengths[p]
    frozen = frozen_dir / p.name
    with frozen.open('xb') as handle: handle.write(data)
    item = {'original_path': str(p), 'frozen_path': str(frozen), 'bytes': len(data), 'sha256': sha(data),
        'append_active': False, 'qualification': 'Named earlier session; original may change later. Hash binds captured prefix only.',
        'stat_unchanged_during_read': (before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns),
        'original_size_after_read': after.st_size}
    n = 0
    try:
        for n, (raw, meta) in enumerate(records(io.BytesIO(data)), 1):
            event = json.loads(raw); a = anchor(event, n, meta, p.name, raw)
            prior_counts[event.get('kind')] += 1
            version = event.get('context', {}).get('version')
            if version: prior_versions[version] += 1
            if event.get('kind') in ('collection_search_started', 'collection_search_finished'):
                prior_events.append((event, a))
    except Exception as exc:
        prior_errors.append({'segment': p.name, 'completed_records': n, 'error': str(exc)})
    item['event_count'] = n; prior_inputs.append(item)

wanted = {1093, 1094, 1095, 1135, 1136, 1137}
latest_events = {}; latest_search_events = []
original_receipts = []
for item in latest['inputs']:
    data = Path(item['frozen_path']).read_bytes()
    assert len(data) == item['bytes'] and sha(data) == item['sha256']
    for ordinal, (raw, meta) in enumerate(records(io.BytesIO(data)), 1):
        event = json.loads(raw); seq = event.get('sequence')
        if seq not in wanted and event.get('kind') not in ('collection_search_started', 'collection_search_finished'): continue
        a = anchor(event, ordinal, meta, Path(item['frozen_path']).name, raw)
        if event.get('kind') in ('collection_search_started', 'collection_search_finished'):
            latest_search_events.append((event, a))
        if seq in wanted:
            latest_events[seq] = (event, a)
            dest = HERE / ('original_event_' + str(seq) + '.json')
            with dest.open('xb') as handle: handle.write(raw)
            original_receipts.append({'sequence': seq, 'path': str(dest), 'sha256': sha(raw)})

def compact_card(card, goal):
    return {**{k: card.get(k) for k in ('id', 'key', 'name', 'cost', 'sell_cost', 'edition')},
        'eternal': card.get('ability', {}).get('eternal', False),
        'perishable': card.get('ability', {}).get('perishable', False),
        'rental': card.get('ability', {}).get('rental', False),
        'gold_record': goal.get('by_key', {}).get(card.get('key'))}

choices = []
for seq in (1093, 1135):
    e, a = latest_events[seq]; c = e.get('context', {}); s = c.get('snapshot', {}); g = s.get('completionist_goal', {})
    cb, cb_anchor = latest_events[seq + 1]; after, after_anchor = latest_events[seq + 2]
    ac = after.get('context', {}); ass = ac.get('snapshot', {}); ag = ass.get('completionist_goal', {})
    action = e['details']['input']['action']; chosen = s['pack_cards'][action['index'] - 1]
    choices.append({'anchor': a, 'at': e.get('at'), 'seed': c.get('seed'), 'loaded_version': c.get('version'),
        'kind': 'Pack choice, not a shop Joker purchase', 'action': action,
        'state': {k: s.get(k) for k in ('ante', 'round', 'phase', 'dollars', 'pack_type', 'pack_choices', 'joker_limit')},
        'selected_card': compact_card(chosen, g),
        'pack_cards': [compact_card(card, g) for card in s.get('pack_cards', [])],
        'jokers_before': [compact_card(card, g) for card in s.get('jokers', [])],
        'advice': c.get('advice'), 'callback': {'anchor': cb_anchor, 'details': cb.get('details')},
        'after': {'anchor': after_anchor, 'at': after.get('at'), 'state': {k: ass.get(k) for k in ('ante', 'round', 'phase', 'dollars')},
            'selected_card_now_held': [compact_card(card, ag) for card in ass.get('jokers', []) if card.get('id') == chosen.get('id')]}})

prior_searches = summarize_searches(prior_events); latest_searches = summarize_searches(latest_search_events)
prior_pairs = [(e['preceding_start']['start_seed'], e['result']['seed']) for e in prior_searches]
latest_pairs = [(e['preceding_start']['start_seed'], e['result']['seed']) for e in latest_searches]
report = {'schema': 1, 'scope': latest['scope'], 'latest_audit': {'path': str(audit_path), 'sha256': sha(audit_path.read_bytes())},
    'prior_session': {'prefix': prefix, 'inputs': prior_inputs, 'loaded_versions': dict(prior_versions),
        'event_counts': dict(prior_counts), 'decode_errors': prior_errors, 'searches': prior_searches},
    'latest_searches': latest_searches,
    'repeated_search_pairs': {'prior': prior_pairs, 'latest': latest_pairs, 'exact_pair_sequence_equal': prior_pairs == latest_pairs,
        'qualification': 'Exact observed cursor/result repetition across distinct recorded sessions. Restart itself is not independently recorded by this passive audit.'},
    'eternal_choices': choices, 'original_event_receipts': original_receipts,
    'limits': ['No advisor or scoring evaluator was executed.', 'Only named previous-session byte prefixes were newly read; latest-session data came from already sealed bytes.',
        'The latest interrupted run remains unfinished; no new terminal outcome is imputed.', 'Observed pack choices and advice do not establish that those choices were optimal.']}
out = HERE / 'supplemental.json'
with out.open('x', encoding='utf-8') as handle: json.dump(report, handle, indent=2); handle.write('\n')
print(json.dumps({'path': str(out), 'sha256': sha(out.read_bytes()), 'prior_versions': dict(prior_versions),
    'prior_input_bytes': sum(v['bytes'] for v in prior_inputs), 'prior_decode_errors': prior_errors,
    'repeated_search_pairs': report['repeated_search_pairs'],
    'choices': [{'sequence': c['anchor']['sequence'], 'at': c['at'], 'selected_card': c['selected_card'],
        'after_selected_card_now_held': c['after']['selected_card_now_held']} for c in choices]}))
