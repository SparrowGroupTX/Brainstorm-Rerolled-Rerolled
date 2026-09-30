"""Read-only projections of completed C04/C06 decisions; no policy/source execution."""
from pathlib import Path
import hashlib
import json
from collections import Counter

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / 'tools/advisor_eval/runs/gold299_20260914'


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def compact(value, depth=0):
    if isinstance(value, str) and len(value) > 600:
        return {'characters': len(value), 'sha256': hashlib.sha256(value.encode()).hexdigest()}
    if depth >= 5 and isinstance(value, (dict, list)):
        return {'type': type(value).__name__, 'entries': len(value), 'sha256': digest(value)}
    if isinstance(value, dict): return {key: compact(v, depth+1) for key, v in value.items()}
    if isinstance(value, list): return [compact(v, depth+1) for v in value]
    return value


def read(job):
    record = json.loads((BASE/job/'record.json').read_text())
    trace = BASE/job/'trace.log'
    with trace.open('rb') as f:
        assert hashlib.file_digest(f, 'sha256').hexdigest() == record['trace_sha256']
    decisions = {}; profiles = {}; completed = set(); final_start = None
    with trace.open('rb') as f:
        for line in f:
            if not line.startswith(b'{'): continue
            r = json.loads(line); kind = r.get('type')
            if kind == 'engine_episode_decision':
                s, result = r['snapshot'], r['result']; action = result['action']
                selected = [s['hand'][i-1] for i in action.get('indices', [])]
                items = {k: compact(result[k]) for k in ('play','discard','growth','growth_diagnostics','consumable','consumable_diagnostics','copy_preflight','clear_shortcut','fast_clear','shop_diagnostics','shop_sequence','gold_planet_diagnostics') if k in result}
                strategy = result.get('strategy', {})
                strategy_projection = {k: compact(strategy[k]) for k in ('title','lines','warnings','action','scoring_evidence','pack_diagnostics','shop_sequence') if k in strategy}
                decisions[r['step']] = {
                    'step': r['step'], 'snapshot_digest': digest(s), 'phase': s['phase'], 'ante': s['ante'], 'round': s['round'],
                    'action': action, 'dollars': s['dollars'], 'hands_left': s['hands_left'], 'discards_left': s['discards_left'],
                    'discards_used': s['discards_used'], 'hands_played': s['hands_played'], 'blind': s['blind'], 'chips': s['chips'],
                    'hand': s['hand'], 'selected': selected, 'jokers': s['jokers'], 'consumeables': s['consumeables'],
                    'shop_jokers': s.get('shop_jokers'), 'pack_cards': s.get('pack_cards'), 'round_resets': s.get('round_resets'),
                    'hand_stats': s.get('hand_stats'), 'deck_count': len(s.get('deck', [])), 'hand_size': s.get('hand_size'),
                    'population_enhancements': dict(Counter(c.get('enhancement', 'c_base') for c in s.get('playing_cards', []))),
                    'result_keys': sorted(result), 'result': items, 'strategy': strategy_projection,
                }
            elif kind == 'engine_episode_profile': profiles[r['step']] = r
            elif kind == 'engine_episode_resolved': completed.add(r['step'])
            elif kind == 'engine_episode_decision_started': final_start = {'step': r['step'], 'snapshot_digest': digest(r['snapshot']), 'phase': r['snapshot']['phase']}
    return {step: {**entry, 'profile': profiles.get(step)} for step, entry in decisions.items() if step in completed and step in profiles}, record, final_start


def main():
    old, old_record, _ = read('C04')
    current, record, final = read('C06')
    by_snapshot = {}
    for step, value in old.items(): by_snapshot.setdefault(value['snapshot_digest'], []).append(step)
    matches = []
    for step, value in current.items():
        matched = by_snapshot.get(value['snapshot_digest'])
        if matched:
            matches.append({'current_step': step, 'snapshot_digest': value['snapshot_digest'], 'previous': [old[n] for n in matched]})
    value = {'schema': 1, 'scope': 'Recorded completed decision projections only; no evaluated counterfactual',
             'records': {'C04': old_record, 'C06': record}, 'completed': list(current.values()),
             'exact_public_snapshot_matches': matches, 'last_started': final,
             'extractor_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    path = Path(__file__).with_name('recorded_decisions.json')
    with path.open('x', encoding='utf8') as f: json.dump(value, f, indent=2)
    print(json.dumps({'completed': len(current), 'matching_public_snapshots': len(matches), 'output': str(path)}))


if __name__ == '__main__': main()
