"""Independent read-only M19 audit. Creates audit.json once; no policy evaluation."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
JOB = ROOT / 'tools/advisor_eval/runs/gold299_20260914/M19'
ORDER = [('baseline', 85), ('candidate', 85), ('candidate', 185), ('baseline', 185)]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def digest(value):
    return hashlib.sha256(canonical(value)).hexdigest()


def main():
    record, registration, spent = [read(JOB / name) for name in ('record.json', 'registration.json', 'spent.json')]
    assert record['job'] == registration['job'] == spent['job'] == 'M19'
    assert record['status'] == 'complete' and record['exit_code'] == 0
    assert record['timeout_seconds'] == registration['timeout_seconds'] == 30
    assert record['elapsed_seconds'] <= 30 and record['one_use_spent'] is True
    assert record['registration_sha256'] == spent['registration_sha256'] == sha(JOB / 'registration.json')
    assert record['trace_sha256'] == sha(JOB / 'trace.log')
    changed = [name for name, expected in registration['files'].items() if sha(JOB / name) != expected]
    assert not changed
    manifests = {role: read(JOB / (role + '_record.json'))['policy'] for role in ('baseline', 'candidate')}
    for role, manifest in manifests.items():
        assert digest(manifest['policy_files']) == manifest['policy_digest']
        assert registration['metadata']['policy_digests'][role] == manifest['policy_digest']
    a, b = manifests['baseline']['policy_files'], manifests['candidate']['policy_files']
    assert set(a) == set(b)
    assert [key for key in a if a[key] != b[key]] == ['Brainstorm/Advisor/score_cache.lua']
    raw_trace = [json.loads(line) for line in (JOB / 'trace.log').read_text().splitlines() if line.startswith('{')]
    assert len(raw_trace) == 5 and [(r['policy'], r['step']) for r in raw_trace[:-1]] == ORDER
    comparison = read(JOB / 'comparison.json')
    assert raw_trace[-1] == comparison and comparison['status'] == 'passed'
    results, receipts = {}, []
    for role, step in ORDER:
        name = f'{role}_step{step}_result.json'
        result = read(JOB / name)
        assert result['policy'] == role and result['step'] == step and result['status'] == 'complete'
        assert result['policy_digest'] == manifests[role]['policy_digest']
        assert result['input_unchanged'] is True and result['source_execution'] is False
        assert result['action_dispatch'] is False and result['selected_action_rescore'] is False
        assert result['retry_context'] == 'disabled_clean' and result['gold_context'] == 'unchanged_source_snapshot'
        assert result['score_calls'] <= 140000 and result['result']['evaluations'] <= 140000
        assert result['score_cache'] == result['result']['score_cache']
        cache = result['score_cache']
        assert cache['capacity'] == cache['stored'] == 8192
        assert cache['classify_calls'] == cache['hits'] + cache['misses']
        trace_row = raw_trace[len(receipts)]
        assert all(trace_row[key] == result[key] for key in trace_row)
        snapshot = read(JOB / f'step{step}.json')['snapshot']
        assert snapshot['phase'] == 'hand'
        assert snapshot['completionist_goal']['counts'] == {'complete': 0, 'missing': 150, 'total': 150, 'unknown': 0}
        results[(role, step)] = result
        receipts.append({'role': role, 'step': step, 'file': name, 'sha256': sha(JOB / name),
                         'decision_wall_seconds': result['decision_wall_seconds'],
                         'decision_lua_os_clock_seconds': result['decision_cpu_seconds'],
                         'score_calls': result['score_calls'], 'evaluations': result['result']['evaluations'],
                         'cache': cache, 'score_calls_outside_classification_counter': result['score_calls'] - cache['classify_calls']})
    pairs = []
    for step in (85, 185):
        left, right = results[('baseline', step)], results[('candidate', step)]
        left_semantic = {key: value for key, value in left['result'].items() if key != 'score_cache'}
        right_semantic = {key: value for key, value in right['result'].items() if key != 'score_cache'}
        assert left_semantic == right_semantic
        assert left['action'] == right['action']
        assert left['score_calls'] == right['score_calls'] == left['result']['evaluations'] == right['result']['evaluations']
        assert left['input_fingerprint'] == right['input_fingerprint']
        old, new = left['score_cache'], right['score_cache']
        pairs.append({'step': step, 'semantic_equal_excluding_only_top_level_score_cache': True,
                      'semantic_sha256': digest(left_semantic), 'same_action': left['action'],
                      'same_input_fingerprint': left['input_fingerprint'], 'same_score_calls': left['score_calls'],
                      'same_evaluations': left['result']['evaluations'],
                      'classifications_per_role': old['classify_calls'],
                      'misses_baseline': old['misses'], 'misses_candidate': new['misses'],
                      'misses_reduced': old['misses'] - new['misses'],
                      'miss_reduction_fraction': (old['misses'] - new['misses']) / old['misses'],
                      'candidate_evictions': new['evictions'],
                      'wall_seconds_baseline': left['decision_wall_seconds'],
                      'wall_seconds_candidate': right['decision_wall_seconds'],
                      'wall_seconds_increase': right['decision_wall_seconds'] - left['decision_wall_seconds'],
                      'candidate_to_baseline_wall_ratio': right['decision_wall_seconds'] / left['decision_wall_seconds']})
    calls = sum(r['score_calls'] for r in results.values())
    assert calls == comparison['score_calls'] == 559992 <= 560000
    sums = {role: sum(results[(role, step)]['decision_wall_seconds'] for step in (85, 185))
            for role in ('baseline', 'candidate')}
    audit = {'schema': 1, 'job': 'M19', 'status': 'audited_semantic_pass_local_timing_regression',
             'audited_at_utc': datetime.now(timezone.utc).isoformat(), 'audit_script_sha256': sha(__file__),
             'original_record_unchanged': True, 'original_record_sha256': sha(JOB / 'record.json'),
             'registration_sha256': sha(JOB / 'registration.json'), 'spent_sha256': sha(JOB / 'spent.json'),
             'trace_sha256': sha(JOB / 'trace.log'), 'comparison_sha256': sha(JOB / 'comparison.json'),
             'input_provenance_sha256': sha(JOB / 'input_provenance.json'),
             'frozen_files_reverified': len(registration['files']), 'frozen_changes_found': [],
             'external_provenance': registration['external_files'],
             'external_verification': 'Root registration/run verified external hashes before/after execution; auditor did not reread executable/runtime binaries.',
             'baseline_policy_digest': manifests['baseline']['policy_digest'],
             'candidate_policy_digest': manifests['candidate']['policy_digest'],
             'only_policy_change': 'Brainstorm/Advisor/score_cache.lua FIFO replacement at unchanged8192 capacity',
             'decision_order': ORDER, 'decisions': receipts, 'paired_audits': pairs,
             'budget': {'lease': 'one distinct mechanical M19', 'one_use_spent': True,
                        'outer_seconds': record['elapsed_seconds'], 'outer_cap_seconds': 30,
                        'actual_score_calls': calls, 'aggregate_score_cap': 560000, 'per_decision_cap': 140000},
             'timing_totals': {'decision_wall_seconds': sums,
                               'candidate_to_baseline_wall_ratio': sums['candidate'] / sums['baseline'],
                               'outer_minus_measured_decisions_seconds': record['elapsed_seconds'] - sum(sums.values())},
             'semantic_conclusion': 'All four complete decisions preserve full results except the declared top-level score_cache diagnostic, exact actions/evaluations/actual calls and input fingerprints.',
             'performance_conclusion': 'FIFO lowers classification misses but is slower in both observed pairs. This evidence does not support installation as a speed improvement.',
             'recommendation': 'Do not install this FIFO candidate from M19; preserve the negative timing evidence.',
             'limits': ['Only two selected dependent C04 states and one pair per state; no confidence interval or controlled-system timing claim.',
                        'Root reports full candidate310 regression finished before M19 and installation/final validation began only after M19 exit; other agents may have run inert fixtures, and the live game remained undisturbed.',
                        'The cause of slower timings is unmeasured. Cache insertion/deletion/allocation or garbage collection are hypotheses, not findings.',
                        'A higher hit count is not itself faster advice; classification counters exclude116 raw scoring calls at step85 on both policies.',
                        'No source initialization, action dispatch, selected-action rescore, terminal attempt, player progress or win-rate measurement occurred.',
                        'C04 remains an independent preserved timeout/censored attempt without a terminal result.'],
             'qualification': False, 'terminal_evidence': False, 'source_execution': False,
             'player_achievement_progress': False, 'game_control': 'none'}
    with (JOB / 'audit.json').open('x', encoding='utf-8') as stream:
        json.dump(audit, stream, indent=2, allow_nan=False);stream.write('\n')
    assert sha(JOB / 'record.json') == audit['original_record_sha256']
    print(json.dumps({'audit': str(JOB / 'audit.json'), 'status': audit['status'], 'score_calls': calls,
                      'pair_wall_ratios': [p['candidate_to_baseline_wall_ratio'] for p in pairs],
                      'outer_seconds': record['elapsed_seconds']}))


if __name__ == '__main__':
    main()
