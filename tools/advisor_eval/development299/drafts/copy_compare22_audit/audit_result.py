"""Independent static audit of retained M22 artifacts. Never loads/evaluates Lua."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import itertools
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
JOB = ROOT / 'tools/advisor_eval/runs/gold299_20260914/M22'
ORDER = (('baseline', 31), ('candidate', 31), ('candidate', 96), ('baseline', 96))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'), parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def structural(value):
    """Independent byte-level reconstruction of the frozen driver's Lua input receipt."""
    if value is None:
        return b'z'
    if isinstance(value, bool):
        return b'bt' if value else b'bf'
    if isinstance(value, (int, float)):
        return b'n' + format(float(value), '.17g').encode() + b';'
    if isinstance(value, str):
        data = value.encode()
        return b's' + str(len(data)).encode() + b':' + data
    items = enumerate(value, 1) if isinstance(value, list) else value.items()
    # Lua serialization assigns nil values as absent fields.
    entries = sorted((structural(key), structural(item)) for key, item in items if item is not None)
    return b't' + str(len(entries)).encode() + b'{' + b''.join(a + b for a, b in entries) + b'}'


def runtime_prefix(raw):
    text = raw.decode()
    assert text.count('\nfunction A.defaults()') == 1
    prefix = text.split('\nfunction A.defaults()')[0]
    a = prefix.index('local function module(name)')
    b = prefix.index('\nA.snapshot, A.scoring, A.search, A.strategy')
    prefix = prefix[:a] + "local function module(name)\n  assert(package.preload['probe_policy_'..name], 'Missing frozen module '..name)\n  return require('probe_policy_'..name)\nend\n" + prefix[b:]
    omitted = ["A.execution = module('execution')",
        "A.retry_memory, A.retry_policy, A.retry_journal = module('retry_memory'), module('retry_policy'), module('retry_journal')",
        'A.retry_generation, A.state_epoch = 0, 0', 'A.opening = Brainstorm.ChallengeOpening',
        'A.jokerless_opening = Brainstorm.JokerlessOpening']
    for line in omitted:
        assert prefix.count(line) == 1
        prefix = prefix.replace(line, '-- Detached hand comparison omits: ' + line)
    return prefix.encode(), omitted


def main():
    assert not (JOB / 'audit.json').exists() and not (JOB / 'RESULT.md').exists()
    before = {path.relative_to(JOB).as_posix(): sha(path) for path in JOB.rglob('*') if path.is_file()}
    registration = read(JOB / 'registration.json'); record = read(JOB / 'record.json')
    spent = read(JOB / 'spent.json'); authority = read(JOB / 'authority.json')
    summary = read(JOB / 'comparison.json'); provenance = read(JOB / 'input_provenance.json')
    assert record['registration_sha256'] == spent['registration_sha256'] == sha(JOB / 'registration.json')
    assert record['trace_sha256'] == sha(JOB / 'trace.log')
    assert record['status'] == 'complete' and record['exit_code'] == 0 and record['elapsed_seconds'] <= 30
    assert record['one_use_spent'] and spent['one_use'] and registration['job'] == spent['job'] == 'M22'
    assert record['qualification'] is False and record['outcome'] == 'pending_trace_audit'
    assert registration['timeout_seconds'] == authority['per_job_caps']['M22'] == 30
    assert registration['authority_sha256'] == sha(JOB / 'authority.json')
    assert datetime.fromisoformat(spent['started_at_utc']) < datetime.fromisoformat(authority['expires_at_utc'])
    for name, expected in registration['files'].items():
        assert sha(JOB / name) == expected, name
    for name, expected in registration['external_files'].items():
        assert sha(name) == expected, name
    assert registration['metadata']['decision_order'] == [list(row) for row in ORDER]
    assert registration['metadata']['score_call_cap'] == 560000
    assert registration['metadata']['per_decision_score_cap'] == 140000
    policy, graphs = {}, {}
    for role in ('baseline', 'candidate'):
        policy[role] = read(JOB / (role + '_record.json'))['policy']
        manifest = policy[role]['policy_files']
        assert hashlib.sha256(canonical(manifest)).hexdigest() == policy[role]['policy_digest']
        for name, expected in manifest.items():
            assert sha(JOB / role / name) == expected
        raw = (JOB / role / 'Brainstorm/Advisor/runtime.lua').read_bytes()
        prefix, omitted = runtime_prefix(raw)
        assert prefix == (JOB / (role + '_module_setup.lua')).read_bytes()
        active = '\n'.join(line for line in prefix.decode().splitlines() if not line.startswith('--'))
        names = sorted(set(re.findall(r"module\('([^']+)'\)", active)))
        assert 'execution' not in names and not set(names) & {'retry_memory', 'retry_journal', 'retry_policy'}
        assert ('hand_copy_preflight' in names) == (role == 'candidate')
        for name in names:
            assert 'Brainstorm/Advisor/' + name + '.lua' in manifest
        for edge in ('A.snapshot.perkeo_inventory = A.perkeo_inventory',
                     'A.snapshot.certificate=A.certificate', 'A.shop_scoring.certificate=A.certificate',
                     'A.shop_scoring.bell_opening=A.bell_opening',
                     'A.strategy.pack_survival = A.pack_survival', 'A.blind_finishing.pack_survival=A.pack_survival',
                     'A.shop_scoring.blind_finishing=A.blind_finishing'):
            assert edge in active
        assert all(name in names for name in ('gold_planet_policy', 'gold_goal', 'gold_perkeo', 'normal_opening'))
        graphs[role] = {'runtime_sha256': hashlib.sha256(raw).hexdigest(),
            'setup_sha256': sha(JOB / (role + '_module_setup.lua')), 'module_count': len(names),
            'modules': names, 'omitted_live_retry_integrations': omitted,
            'all_retained_runtime_edges_exact': True}
        final = read(JOB / (role + '_installed_final_verification.json'))
        validation_path = JOB / (role + '_installed_installed_validation.json')
        validation = read(validation_path)
        assert validation['passed'] and validation['policy_unchanged'] and validation['tests_unchanged']
        assert final['policy_digest'] == validation['policy_digest'] == policy[role]['policy_digest']
        assert final['installed_matches'] and final['native_unchanged'] and not final['config_restored_or_modified_by_finalizer']
        assert final['installed_report'] == sha(validation_path)
    changed = [name for name in sorted(set(policy['baseline']['policy_files']) | set(policy['candidate']['policy_files']))
               if policy['baseline']['policy_files'].get(name) != policy['candidate']['policy_files'].get(name)]
    assert changed == provenance['changed_policy_files']
    assert policy['baseline']['policy_files']['Brainstorm/Advisor/score_cache.lua'] == policy['candidate']['policy_files']['Brainstorm/Advisor/score_cache.lua']
    source = ROOT / 'tools/advisor_eval/runs/gold299_20260914/C04'
    for name, expected in provenance['source_files'].items():
        assert sha(ROOT / name) == expected
    snapshots, inputs = {}, {}
    for step in (31, 96):
        file = JOB / f'step{step}.json'; body = read(file); snapshot = body['snapshot']
        origin = provenance['snapshots'][str(step)]
        assert sha(file) == origin['snapshot_file_sha256']
        assert hashlib.sha256(canonical(snapshot)).hexdigest() == origin['snapshot_canonical_sha256']
        assert len(snapshot['hand']) == 8 and len(snapshot['jokers']) == 5
        assert snapshot['completionist_goal']['counts'] == {'total': 150, 'missing': 150, 'complete': 0, 'unknown': 0}
        assert not any((c.get('ability') or {}).get('forced_selection') for c in snapshot['hand'])
        snapshots[step] = snapshot
        inputs[str(step)] = {'snapshot_sha256': sha(file), 'canonical_sha256': origin['snapshot_canonical_sha256'],
            'structural_fingerprint_sha256': hashlib.sha256(structural(snapshot)).hexdigest(),
            'source_line': origin['trace_line'], 'source_line_sha256': origin['trace_line_sha256'],
            'discards_left': snapshot['discards_left'], 'hand_count': 8,
            'blind_key': snapshot['blind']['key'], 'blind_chips': snapshot['blind']['chips'],
            'chips': snapshot['chips'], 'dollars': snapshot['dollars'], 'inventory_count': len(snapshot['consumeables']),
            'inventory_keys': [c['key'] for c in snapshot['consumeables']],
            'joker_keys': [j['key'] for j in snapshot['jokers']]}
    found_starts, found_finishes = set(), set()
    with (source / 'trace.log').open('rb') as stream:
        for line_number, line in enumerate(stream, 1):
            if not line.startswith(b'{'):
                continue
            row = json.loads(line); step = row.get('step')
            if step not in snapshots:
                continue
            if row['type'] == 'engine_episode_decision_started':
                assert row['snapshot'] == snapshots[step]
                assert inputs[str(step)]['source_line'] == line_number
                assert inputs[str(step)]['source_line_sha256'] == hashlib.sha256(line).hexdigest()
                found_starts.add(step)
            elif row['type'] == 'engine_episode_decision':
                assert row['snapshot'] == snapshots[step]; found_finishes.add(step)
    assert found_starts == found_finishes == {31, 96}
    trace_rows = [json.loads(line) for line in (JOB / 'trace.log').read_text().splitlines() if line.startswith('{')]
    assert len(trace_rows) == 5 and trace_rows[-1] == summary
    assert [(r['policy'], r['step']) for r in trace_rows[:-1]] == list(ORDER)
    results, rows = {}, []
    for i, (role, step) in enumerate(ORDER):
        path = JOB / f'{role}_step{step}_result.json'; result = read(path); d = result['result']
        assert result['status'] == 'complete' and result['input_unchanged'] and not result.get('input_structure_error')
        assert result['policy_digest'] == policy[role]['policy_digest']
        assert result['input_fingerprint'] == inputs[str(step)]['structural_fingerprint_sha256']
        assert result['score_calls'] == d['evaluations'] and 0 <= result['score_calls'] <= 140000
        assert result['gold_context'] == 'unchanged_source_snapshot' and result['retry_context'] == 'disabled_clean'
        assert not any(result[k] for k in ('source_execution', 'action_dispatch', 'selected_action_rescore', 'terminal_evidence', 'qualification'))
        for key, value in trace_rows[i].items():
            assert result[key] == value, key
        action = result['action']; assert action == d['action']
        assert action['kind'] == 'reorder_jokers' and sorted(action['order']) == [1, 2, 3, 4, 5]
        assert action.get('area', 'jokers') == 'jokers'
        assert not any(j.get('pinned') and action['order'].index(k) + 1 != k for k, j in enumerate(snapshots[step]['jokers'], 1))
        alternatives = d['alternatives']
        expected = {indices for n in range(1, 6) for indices in itertools.combinations(range(1, 9), n)}
        assert len(alternatives) == len(expected) == 218
        assert {tuple(p['indices']) for p in alternatives} == expected
        assert all(p['legal'] and not p['uncertain'] and not p['warnings'] for p in alternatives)
        assert d['play_complete'] and not d['truncated']
        results[(role, step)] = result
        rows.append({'policy': role, 'step': step, 'result_sha256': sha(path),
            'actual_score_calls': result['score_calls'], 'evaluations': d['evaluations'],
            'classification_cache_score_calls': result['score_cache']['score_calls'],
            'wall_seconds': result['decision_wall_seconds'], 'cpu_seconds': result['decision_cpu_seconds'],
            'raw_action': action, 'result_kind': d['kind'], 'result_keys': sorted(d),
            'ordering_diagnostics': d.get('ordering_diagnostics'), 'phase_copy_diagnostics': d.get('phase_copy_diagnostics'),
            'result_complete': True, 'all218_current_scores_preserved': True})
    pairs = {}
    for step in (31, 96):
        baseline, candidate = results[('baseline', step)], results[('candidate', step)]
        a, b = baseline['result'], candidate['result']; proof = b['copy_preflight']
        assert a['alternatives'] == b['alternatives'] and a['play'] == b['play']
        assert baseline['action'] != candidate['action']
        assert dict(baseline['action'], area='jokers') == candidate['action']
        assert b['reorder_only'] and b['needs_refresh'] and proof['needs_refresh']
        assert proof['complete'] and proof['bounded'] and proof['paired_subsets'] == proof['subsets'] == 218
        assert proof['score_calls'] == proof['required_score_calls'] == 436
        assert candidate['score_calls'] == 654 == candidate['score_cache']['score_calls'] + 436
        assert proof['paired_discards'] == (218 if step == 96 else 0)
        assert proof['discard_transition_calls'] == (436 if step == 96 else 0)
        assert proof['extra_setup_actions'] == 1 and proof['copy_events_shifted'] == 1
        assert proof['copy_routes_before'] == {'card:66': {'id': 'card:59', 'key': 'j_perkeo'}}
        assert proof['copy_routes_after'] == {'card:66': {'id': 'card:60', 'key': 'j_yorick'}}
        witness = proof['held_clear']; original = next(p for p in a['alternatives'] if p['indices'] == witness['indices'])
        assert witness['baseline_score'] == original['score']
        assert witness['score'] == a['ordering']['play']['score'] and witness['indices'] == a['ordering']['play']['indices']
        assert witness['score'] >= snapshots[step]['blind']['chips'] - snapshots[step]['chips'] > a['play']['score']
        pairs[str(step)] = {'same_physical_reorder': True, 'raw_difference': '315 adds explicit area=jokers;314 leaves it absent.',
            'common_original_play_and_all218_scores_equal': True, 'proof': proof,
            'score_call_reduction': baseline['score_calls'] - candidate['score_calls'],
            'wall_seconds_reduction': baseline['decision_wall_seconds'] - candidate['decision_wall_seconds'],
            'baseline_best_current_score': a['play']['score'], 'witness_original_same_subset_score': original['score'],
            'witness_reordered_score': witness['score'],
            'baseline_ordering_truncated': a['ordering_diagnostics']['truncated']}
    total = sum(row['actual_score_calls'] for row in rows)
    assert total == summary['score_calls'] == 167562 <= 560000
    audit = {'schema': 1, 'kind': 'independent_retained_M22_audit', 'audited_at_utc': datetime.now(timezone.utc).isoformat(),
        'job': 'M22', 'disposition': 'complete_local_copy_setup_comparison',
        'worker_status': record['status'], 'outer_elapsed_seconds': record['elapsed_seconds'],
        'decisions': 4, 'errors': 0, 'timeouts': 0, 'unsupported_root_results': 0,
        'registration_sha256': sha(JOB / 'registration.json'), 'record_sha256': sha(JOB / 'record.json'),
        'trace_sha256': sha(JOB / 'trace.log'), 'comparison_sha256': sha(JOB / 'comparison.json'),
        'audit_script_sha256': sha(__file__), 'registered_file_count': len(registration['files']),
        'frozen_files_verified': True, 'external_files_verified': True, 'original_record_unmodified': True,
        'policy_digests': {role: value['policy_digest'] for role, value in policy.items()},
        'whole_policy_changed_files': changed, 'module_graphs': graphs, 'inputs': inputs,
        'decisions_audited': rows, 'pairs': pairs, 'actual_score_calls': total,
        'score_call_cap': 560000, 'per_decision_score_call_cap': 140000,
        'source_provenance': {key: provenance[key] for key in ('source_policy_digest','source_adapter_digest','source_runtime_digest',
            'source_rules_digest','profile_spec','profile_spec_digest','gold_objective_context')},
        'proof_review': 'Static review of frozen315 verifies every retained legal subset needs supported paired after_play results, exact original-score reuse, no paired score decrease, and equal complete states/effects after normalizing only row order and scored chips. For step96 all218discards require equal complete states/effects after normalizing row order only. Receipts are emitted only after full loops. Intermediate paired states were not retained and were not replayed by this audit.',
        'action_review': 'Execution.lua accepts absent area or explicit jokers for reorder_jokers; exact same valid permutations and pins. No callback/action dispatch occurred.',
        'preserved_limits': ['C04 is selected dependent synthetic development and ended in timeout; no representative cohort.',
            'Four D.run results completed; baseline96 ordering remains bounded51orders with ordering_diagnostics.truncated=true, not an exhaustive ordering optimum.',
            'Baseline phase_copy_diagnostics.complete=false/score_calls0 remain unchanged in retained results; that diagnostic is not an episode result.',
            '315 compares one useful copy setup; no claim of globally optimal order, future draw, cashout, full-blind planning, or post-reorder advice.',
            'The measured benefit is local. Machine conditions were not controlled; no repetitions or confidence interval support a general speed estimate.',
            '654actual calls include436raw after_play scores beyond218classification-cache score calls; all are charged.',
            'Snapshots/serialized JSON results are retained; intermediate transition states were checked by frozenpolicy but not independently replayed.',
            'No source initialization, gameplay execution, seed search, selected-action rescore, live profile/saves, or terminal attempt.',
            'No new win, achievement, survival-rate or odds evidence. No further worker registered/executed during this audit.'],
        'qualification': False, 'terminal_evidence': False, 'source_or_policy_evaluation_during_audit': False}
    table = '\n'.join(f"| {step} | {results[('baseline',step)]['score_calls']:,} | 654 | {results[('baseline',step)]['decision_wall_seconds']:.6f} | {results[('candidate',step)]['decision_wall_seconds']:.6f} |" for step in (31,96))
    text = f'''# M22 retained-result audit

Installed315 selected the same physical Joker reorder as installed314 in both captured states, with fewer actual score calls. All four registered decisions completed within their140000call caps;167562calls total under560000. The one-use worker completed in{record['elapsed_seconds']:.9f}s under30s. No action was executed and no run was resumed.

| C04 step | 314 score calls | 315 score calls | 314 decision seconds | 315 decision seconds |
|---|---:|---:|---:|---:|
{table}

The observed wall-time reduction was0.043031s for step31 and1.077520s for step96. These are single local measurements on selected dependent states, without controlled machine conditions or repeated samples. They do not establish a general speedup or win-rate effect. The score-count reduction is much larger than the elapsed-time reduction because the new complete resource comparisons also perform work outside scoring.

Both eight-card states initially put Perkeo first, so Brainstorm copied Perkeo.315 moves the same physical Yorick first: `[2,1,3,4,5]` at step31 and `[5,2,3,4,1]` at step96. The raw action difference is only315's explicit `area='jokers'`; frozen Execution accepts either absent or explicit area.315 marks a reorder-only result requiring fresh advice. Both old and new policies retain identical current-row scores for all218legal one-to-five-card subsets.

At step31, no discards remain. The current row's best play scores900 against1000needed. The witnessed Straight scores711 before and1343 after reordering. At step96, two discards remain; the same Straight goes from5040 to18480 against13500needed. These reordered scores also match314's preserved ordering scores. Neither witnessed hand was actually played in M22.

For each state315 completed218paired after_play comparisons (436new scores) after218existing held scores:654actual calls. Its classification-cache counter is only218; the audit verifies the outer count and decision ledger include all436raw transition scores. Step96 additionally completed218paired discards (436non-scoring transitions). The proof requires unchanged complete modeled states/effects except physical Joker order and scored chips for plays, and only row order for discards. The three Negative Empress cards and$19 input at step96 remain present; input identity is unchanged. This is a resource-preserving setup proposal, not permission to skip remaining Yorick discards or spend the copied inventory without another decision.

Every frozen input and external runtime hash matched. Both dependency graphs were independently reconstructed from their exact installed runtime initialization, retaining Certificate, Bell, Perkeo inventory/Planet and pack-survival connections. Live execution and retry integrations remain disabled. C04source-line hashes, canonical snapshots and complete type-delimited input fingerprints were independently checked. The old315versus314 cache bytes are identical; M22 is unrelated to the closed cache experiments.

Limits remain explicit.314step96 compared51complete orders with its ordering search marked truncated;315 proves one useful setup, not an exhaustive global optimum. Intermediate paired transition states were checked by the frozen policy but not retained or independently replayed by this audit. C04was a synthetic all-unlocked/discovered development attempt with150missing Gold targets and an eventual timeout. There is no unseen validation, terminal result, player achievement, new source-mechanics qualification or numerical win-odds evidence here. The next fresh decision after reordering and its action/computation costs were not measured.

The original `record.json` is preserved with `outcome='pending_trace_audit'`; this immutable `audit.json` is the subsequent disposition. Registration SHA256 `{sha(JOB/'registration.json')}`; trace SHA256 `{sha(JOB/'trace.log')}`.
'''
    assert {path: sha(JOB / path) for path in before} == before
    (JOB / 'audit.json').open('x', encoding='utf-8').write(json.dumps(audit, indent=2, allow_nan=False) + '\n')
    (JOB / 'RESULT.md').open('x', encoding='utf-8').write(text)
    print(json.dumps({'audit_sha256': sha(JOB / 'audit.json'), 'result_sha256': sha(JOB / 'RESULT.md'),
        'decisions': 4, 'actual_score_calls': total, 'registered_files_verified': len(registration['files']),
        'module_counts': {role: value['module_count'] for role, value in graphs.items()},
        'source_or_policy_evaluation': False}))


if __name__ == '__main__':
    main()
