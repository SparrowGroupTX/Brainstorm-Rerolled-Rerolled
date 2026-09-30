"""Compare preserved C06/C07 inputs and receipts only; never execute policy/source."""
from pathlib import Path
from collections import Counter
import hashlib
import json

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / 'tools/advisor_eval/runs/gold299_20260914'
OUT = Path(__file__).with_name('development_comparison.json')


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def compact(value, depth=0):
    if isinstance(value, str) and len(value) > 700:
        return {'characters': len(value), 'sha256': hashlib.sha256(value.encode()).hexdigest()}
    if depth >= 5 and isinstance(value, (dict, list)):
        return {'type': type(value).__name__, 'entries': len(value), 'sha256': digest(value)}
    if isinstance(value, dict):
        return {k: compact(v, depth+1) for k, v in value.items()}
    if isinstance(value, list):
        return [compact(v, depth+1) for v in value]
    return value


def read(job):
    folder = BASE / job
    record = json.loads((folder / 'record.json').read_text())
    trace_sha = sha(folder / 'trace.log')
    assert trace_sha == record['trace_sha256']
    decisions = {}; profiles = {}; resolved = set(); started = {}
    malformed = []
    with (folder / 'trace.log').open('rb') as stream:
        for number, line in enumerate(stream, 1):
            if not line.startswith(b'{'):
                continue
            try:
                row = json.loads(line)
            except (ValueError, UnicodeDecodeError) as error:
                malformed.append({'line': number, 'reason': str(error)})
                break
            kind = row['type']
            if kind == 'engine_episode_decision':
                result = row['result']
                decisions[row['step']] = {
                    'snapshot': row['snapshot'], 'action': result.get('action'),
                    'growth': compact(result.get('growth')),
                    'growth_diagnostics': compact(result.get('growth_diagnostics')),
                    'pack_diagnostics': compact(result.get('pack_diagnostics')),
                }
            elif kind == 'engine_episode_decision_started':
                started[row['step']] = row['snapshot']
            elif kind == 'engine_episode_resolved':
                resolved.add(row['step'])
            elif kind == 'engine_episode_profile':
                profiles[row['step']] = {k: row[k] for k in ('score_calls', 'advisor_seconds') if k in row}
    completed = sorted(set(decisions) & resolved & set(profiles))
    assert completed == list(range(1, len(completed)+1))
    return {'record': record, 'record_sha256': sha(folder / 'record.json'),
            'audit_sha256': sha(folder / 'audit.json'), 'decisions': decisions,
            'completed': completed, 'started': started, 'profiles': profiles,
            'malformed_rows': malformed}


def main():
    assert not OUT.exists(), 'Existing comparison is immutable'
    records = {job: read(job) for job in ('C06', 'C07')}
    a, b = records.values()
    shared = sorted(set(a['completed']) & set(b['completed']))
    input_differences = []; action_differences = []; growth_differences = []
    exact_inputs = []
    for step in shared:
        old, new = a['decisions'][step], b['decisions'][step]
        same_input = old['snapshot'] == new['snapshot']
        if same_input:
            exact_inputs.append(step)
        else:
            input_differences.append({'step': step, 'differing_top_level_fields':
                                     [key for key in sorted(set(old['snapshot']) | set(new['snapshot']))
                                      if old['snapshot'].get(key) != new['snapshot'].get(key)],
                                     'C06_snapshot_sha256': digest(old['snapshot']),
                                     'C07_snapshot_sha256': digest(new['snapshot'])})
        if old['action'] != new['action']:
            action_differences.append({'step': step, 'same_complete_public_input': same_input,
                                      'C06': old['action'], 'C07': new['action']})
        if old['growth_diagnostics'] != new['growth_diagnostics'] or old['growth'] != new['growth']:
            growth_differences.append({'step': step, 'same_complete_public_input': same_input,
                                      'same_selected_action': old['action'] == new['action'],
                                      **{job: {key: value for key, value in row.items() if key.startswith('growth')}
                                         for job, row in (('C06', old), ('C07', new))}})
    # Match exact inputs across all completed step numbers, then recheck the
    # complete objects themselves; digest equality alone is not the comparison.
    by_digest = {}
    for step in a['completed']:
        by_digest.setdefault(digest(a['decisions'][step]['snapshot']), []).append(step)
    cross_matches = []; cross_action_differences = []
    for new_step in b['completed']:
        new = b['decisions'][new_step]
        for old_step in by_digest.get(digest(new['snapshot']), []):
            old = a['decisions'][old_step]
            if old['snapshot'] != new['snapshot']:
                continue
            cross_matches.append([old_step, new_step])
            if old['action'] != new['action']:
                cross_action_differences.append({'C06_step': old_step, 'C07_step': new_step,
                                                'snapshot_sha256': digest(new['snapshot']),
                                                'C06_action': old['action'], 'C07_action': new['action']})
    output = {'schema': 1, 'scope': 'Read-only exact complete public-input and recorded receipt comparison. No policy, source, scoring, hidden RNG or counterfactual execution.',
              'records': {job: {key: value for key, value in rows.items() if key in ('record', 'record_sha256', 'audit_sha256', 'malformed_rows')}
                          for job, rows in records.items()},
              'completed_counts': {job: len(rows['completed']) for job, rows in records.items()},
              'same_step_exact_public_input_count': len(exact_inputs), 'same_step_exact_public_input_steps': exact_inputs,
              'same_step_input_differences': input_differences, 'same_step_action_differences': action_differences,
              'all_step_exact_public_input_matches': cross_matches, 'exact_input_action_differences': cross_action_differences,
              'growth_receipt_differences': growth_differences,
              'actual_growth_actions': {job: [{'step': step, 'action': rows['decisions'][step]['action'],
                                               'growth': rows['decisions'][step]['growth']}
                                              for step in rows['completed'] if rows['decisions'][step]['growth']]
                                        for job, rows in records.items()},
              'growth_diagnostics_by_job': {job: [{'step': step, 'action': rows['decisions'][step]['action'],
                                                  'diagnostics': rows['decisions'][step]['growth_diagnostics']}
                                                 for step in rows['completed'] if rows['decisions'][step]['growth_diagnostics']]
                                            for job, rows in records.items()},
              'limits': ['Both are selected dependent synthetic development attempts on M4BVSY11, not unseen holdouts or a representative cohort.',
                         'Each timeout remains a timeout; extra completed actions or elapsed throughput are not a terminal improvement.',
                         'Snapshot equality concerns the full recorded public input, not hidden RNG/save equivalence.',
                         'Diagnostic candidate counts and local estimates are separate from actual selected source actions.']}
    with OUT.open('x', encoding='utf-8') as stream:
        json.dump(output, stream, indent=2); stream.write('\n')
    print(json.dumps({'output': str(OUT), 'sha256': sha(OUT),
                      'completed_counts': output['completed_counts'], 'same_inputs': len(exact_inputs),
                      'input_differences': input_differences[:2], 'action_differences': action_differences[:3],
                      'exact_input_action_differences': cross_action_differences[:3],
                      'growth_difference_steps': [row['step'] for row in growth_differences],
                      'actual_growth_steps': {job: [row['step'] for row in rows] for job, rows in output['actual_growth_actions'].items()}}, indent=2))


if __name__ == '__main__':
    main()
