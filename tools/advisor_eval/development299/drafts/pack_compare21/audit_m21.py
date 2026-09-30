"""Independent read-only M21 audit; writes audit.json once, never evaluates Lua."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json

ROOT = Path(__file__).resolve().parents[5]
JOB = ROOT / 'tools/advisor_eval/runs/gold299_20260914/M21'
ORDER = [('baseline', 12), ('candidate', 12)]


def read(path):
    return json.loads(Path(path).read_text())


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def difference(left, right, path=''):
    if left == right:
        return []
    if isinstance(left, dict) and isinstance(right, dict):
        result = []
        for key in sorted(set(left) | set(right)):
            if key not in left or key not in right:
                result.append({'path': path + '/' + key, 'operation': 'added' if key in right else 'removed',
                               'value': right[key] if key in right else left[key]})
            else:
                result.extend(difference(left[key], right[key], path + '/' + key))
        return result
    if isinstance(left, list) and isinstance(right, list) and len(left) == len(right):
        return [entry for i, (a, b) in enumerate(zip(left, right)) for entry in difference(a, b, path + '/' + str(i))]
    return [{'path': path, 'before': left, 'after': right}]


def derive_runtime_prefix(raw):
    text = raw.decode('utf-8'); boundary = '\nfunction A.defaults()'
    assert text.count(boundary) == 1
    prefix = text.split(boundary)[0]
    start = prefix.index('local function module(name)'); end = prefix.index('\nA.snapshot, A.scoring, A.search, A.strategy')
    prefix = prefix[:start] + "local function module(name)\n  assert(package.preload['probe_policy_'..name], 'Missing frozen module '..name)\n  return require('probe_policy_'..name)\nend\n" + prefix[end:]
    omitted = ["A.execution = module('execution')",
               "A.retry_memory, A.retry_policy, A.retry_journal = module('retry_memory'), module('retry_policy'), module('retry_journal')",
               'A.retry_generation, A.state_epoch = 0, 0', 'A.opening = Brainstorm.ChallengeOpening', 'A.jokerless_opening = Brainstorm.JokerlessOpening']
    for line in omitted:
        assert prefix.count(line) == 1
        prefix = prefix.replace(line, '-- Detached captured comparison omits: ' + line)
    return prefix.encode(), omitted


def main():
    assert not (JOB / 'audit.json').exists(), 'Existing audit is immutable'
    record, reg, spent = [read(JOB / n) for n in ('record.json', 'registration.json', 'spent.json')]
    assert record['job'] == reg['job'] == spent['job'] == 'M21'
    assert record['status'] == 'complete' and record['exit_code'] == 0 and record['one_use_spent'] is True
    assert record['elapsed_seconds'] == 5.5 <= 30 and record['timeout_seconds'] == reg['timeout_seconds'] == 30
    assert record['registration_sha256'] == spent['registration_sha256'] == sha(JOB / 'registration.json') == 'bae26985024892636f625d2636da79a0a065e85e2ac512260f120bda6056de75'
    assert record['trace_sha256'] == sha(JOB / 'trace.log') == 'f78ad5884f0dae781b24bc81905a0dcfdb6287e7ac89ced2f6f5722b8d45ebe4'
    assert record['frozen_files_unchanged'] and record['external_files_unchanged']
    assert not [n for n, h in reg['files'].items() if sha(JOB / n) != h]
    assert {Path(n).name.lower() for n in reg['external_files']} == {'python.exe', 'lua51.dll'}
    assert all(sha(n) == h for n, h in reg['external_files'].items())
    authority = read(JOB / 'authority.json'); started = read(JOB / 'comparison_started.json')
    assert reg['authority_sha256'] == sha(JOB / 'authority.json')
    assert authority['status'] == 'APPROVED' and authority['per_job_caps']['M21'] == 30
    assert datetime.fromisoformat(spent['started_at_utc']) < datetime.fromisoformat(authority['expires_at_utc'])
    assert started['job'] == 'M21' and started['one_use'] is True and started['registration_sha256'] == sha(JOB / 'registration.json')
    metadata = reg['metadata']; binding = read(JOB / 'binding.json'); provenance = read(JOB / 'input_provenance.json')
    assert metadata['maximum_decisions'] == 2 and metadata['decision_order'] == [list(x) for x in ORDER]
    assert metadata['score_call_cap'] == 100000 and metadata['per_decision_score_cap'] == 50000
    assert all(metadata[k] is False for k in ('source_execution', 'action_dispatch', 'selected_action_rescore', 'source_or_game_initialization', 'search', 'zip_access', 'player_profile_access', 'qualification', 'terminal_evidence'))
    assert binding['baseline_checkpoint'] == 312 and binding['candidate_checkpoint'] == 314
    manifests = {}; installed = {}
    for role, version in (('baseline', '2.112.0-alpha'), ('candidate', '2.114.0-alpha')):
        policy_record = read(JOB / (role + '_record.json')); manifest = policy_record['policy']; manifests[role] = manifest
        assert policy_record['version'] == version
        assert digest(manifest['policy_files']) == manifest['policy_digest'] == metadata['policy_digests'][role] == binding[role]['policy_digest']
        assert sha(JOB / (role + '_record.json')) == binding[role]['record_sha256']
        assert all(reg['files'][role + '/' + name] == h for name, h in manifest['policy_files'].items())
        runtime = JOB / role / 'Brainstorm/Advisor/runtime.lua'
        assert sha(runtime) == binding[role]['runtime_source_sha256']
        prefix, omitted = derive_runtime_prefix(runtime.read_bytes())
        assert prefix == (JOB / (role + '_module_setup.lua')).read_bytes()
        assert omitted == binding[role]['omitted_product_integrations']
        assert sha(JOB / (role + '_module_setup.lua')) == binding[role]['module_setup_sha256']
        validation = read(JOB / (role + '_installed_validation.json')); final = read(JOB / (role + '_installed_final_verification.json'))
        assert validation['passed'] and validation['policy_unchanged'] and validation['tests_unchanged']
        assert final['version'] == version and final['installed_matches'] and final['native_unchanged']
        assert validation['policy_digest'] == final['policy_digest'] == manifest['policy_digest']
        assert final['installed_report'] == sha(JOB / (role + '_installed_validation.json'))
        assert final['config_restored_or_modified_by_finalizer'] is False
        installed[role] = {'version': version, 'policy_digest': manifest['policy_digest'], 'policy_file_count': len(manifest['policy_files']),
                           'final_verification_sha256': sha(JOB / (role + '_installed_final_verification.json')), 'validation_sha256': sha(JOB / (role + '_installed_validation.json'))}
    a, b = [manifests[r]['policy_files'] for r in ('baseline', 'candidate')]
    changes = [k for k in sorted(set(a) | set(b)) if a.get(k) != b.get(k)]
    assert changes == binding['policy_changed_files'] == metadata['whole_policy_changed_files']
    original = ROOT / 'tools/advisor_eval/runs/gold299_20260914/C05'
    assert all(sha(original / name) == h for name, h in provenance['source_files'].items())
    c05 = read(JOB / 'C05_audit.json')
    assert c05['disposition'] == 'loss' and c05['terminal_receipt'][0]['normal_progress']['final_context']['chips'] == 592
    assert c05['provenance'] == provenance['source_provenance']
    assert c05['policy_digest'] == manifests['baseline']['policy_digest']
    assert sha(JOB / 'C05_audit.json') == provenance['source_files']['audit.json'] == sha(JOB / 'source_attempt_audit.json')
    source_registration = read(JOB / 'C05_registration.json')
    for name in ('engine_contract.lua', 'policy_wiring.lua'):
        assert sha(JOB / name) == source_registration['files'][name]
    runtime_hash = next(h for n, h in reg['external_files'].items() if Path(n).name.lower() == 'lua51.dll')
    assert runtime_hash == c05['provenance']['runtime_digest']
    snapshot = read(JOB / 'step12.json')['snapshot']
    assert snapshot['phase'] == 'pack' and snapshot['completionist_goal']['counts'] == {'complete': 0, 'missing': 150, 'total': 150, 'unknown': 0}
    assert digest(snapshot) == provenance['snapshot_canonical_sha256'] == metadata['snapshot_canonical_sha256']
    assert sha(JOB / 'step12.json') == provenance['snapshot_file_sha256']
    with (original / 'trace.log').open('rb') as stream:
        for number, line in enumerate(stream, 1):
            if number == provenance['origin']['engine_episode_decision_started']['trace_line']:
                assert hashlib.sha256(line).hexdigest() == provenance['origin']['engine_episode_decision_started']['trace_line_sha256']
                original_start = json.loads(line)
                assert original_start['snapshot'] == snapshot and original_start['step'] == 12
                break
        else:
            raise AssertionError('Original captured row missing')
    trace = [json.loads(line) for line in (JOB / 'trace.log').read_text().splitlines() if line.startswith('{')]
    comparison = read(JOB / 'comparison.json')
    assert len(trace) == 3 and trace[-1] == comparison and comparison['status'] == 'complete'
    assert [(r['policy'], r['step']) for r in trace[:2]] == ORDER
    results = {}; receipts = []
    for row, (role, step) in zip(trace[:2], ORDER):
        name = role + '_step12_result.json'; result = read(JOB / name); results[role] = result
        assert all(result[k] == v for k, v in row.items())
        assert result['policy'] == role and result['step'] == step and result['status'] == 'complete'
        assert result['policy_digest'] == manifests[role]['policy_digest']
        assert result['input_unchanged'] is True and result['decision_cap'] == 50000
        assert all(result[k] is False for k in ('source_execution', 'action_dispatch', 'selected_action_rescore', 'qualification', 'terminal_evidence'))
        assert result['retry_context'] == 'disabled_clean' and result['gold_context'] == 'unchanged_source_snapshot'
        assert result['action'] == result['result']['action']
        assert 0 <= result['score_calls'] <= 50000 and 0 <= result['result']['evaluations'] <= 50000
        assert result['score_cache'] == result['result']['score_cache']
        assert result['score_cache']['classify_calls'] == result['score_cache']['hits'] + result['score_cache']['misses']
        assert result['wiring'] == c05['policy_wiring']['wiring']
        assert len(result['wiring']['connections']) == 34 and len(result['wiring']['modules']) == 48
        receipts.append({'role': role, 'step': 12, 'result_sha256': sha(JOB / name), 'action': result['action'],
                         'selected_offer': {'key': snapshot['pack_cards'][result['action']['index'] - 1]['key'], 'id': snapshot['pack_cards'][result['action']['index'] - 1]['id']},
                         'input_fingerprint': result['input_fingerprint'], 'input_unchanged': True,
                         'score_calls': result['score_calls'], 'evaluations': result['result']['evaluations'],
                         'decision_wall_seconds': result['decision_wall_seconds'], 'decision_cpu_seconds': result['decision_cpu_seconds'],
                         'wiring_sha256': digest(result['wiring']), 'survival_priority': result['result']['pack_diagnostics']['survival_priority']})
    left, right = results['baseline'], results['candidate']
    assert left['input_fingerprint'] == right['input_fingerprint']
    assert left['action'] == right['action'] == {'kind': 'choose', 'area': 'pack_cards', 'index': 1}
    assert snapshot['pack_cards'][0]['key'] == 'j_certificate'
    assert left['score_calls'] == right['score_calls'] == left['result']['evaluations'] == right['result']['evaluations'] == 4178
    diffs = difference(left['result'], right['result'])
    paths = {p + '/' + key for p in ('/pack_diagnostics/survival_priority', '/strategy/pack_diagnostics/survival_priority') for key in ('before_clearing_samples', 'complete', 'incumbent_index', 'reason')}
    assert len(diffs) == 8 and {r['path'] for r in diffs} == paths
    old = left['result']['pack_diagnostics']['survival_priority']; new = right['result']['pack_diagnostics']['survival_priority']
    assert old['complete'] is False and new['complete'] is True and new['before_clearing_samples'] == 1 and new['incumbent_index'] == 1
    assert old['reason'] == 'The offers do not share one complete root family.'
    assert new['reason'] == 'No fixed all-clearing policy preserves the admitted owned assets and separate successful-world rewards.'
    assert comparison['comparison']['actions_equal'] is True and comparison['comparison']['results_equal'] is False
    assert comparison['comparison']['baseline_survival_priority'] == old and comparison['comparison']['candidate_survival_priority'] == new
    assert comparison['score_calls'] == sum(r['score_calls'] for r in results.values()) == 8356 <= 100000
    audit = {'schema': 1, 'job': 'M21', 'status': 'audited_complete_family_qualification_action_unchanged',
             'audited_at_utc': datetime.now(timezone.utc).isoformat(), 'audit_script_sha256': sha(__file__),
             'record_sha256': sha(JOB / 'record.json'), 'registration_sha256': sha(JOB / 'registration.json'), 'spent_sha256': sha(JOB / 'spent.json'),
             'trace_sha256': sha(JOB / 'trace.log'), 'comparison_sha256': sha(JOB / 'comparison.json'),
             'input_provenance_sha256': sha(JOB / 'input_provenance.json'), 'snapshot_canonical_sha256': digest(snapshot),
             'frozen_files_reverified': len(reg['files']), 'frozen_changes_found': [], 'external_files_rehashed': reg['external_files'],
             'external_scope': 'Only registered Python and lua51 bytes hashed; neither runtime was loaded and the game executable was not opened by this audit.',
             'installed_policies': installed, 'whole_policy_changed_files': changes,
             'graph_verification': 'Each exact frozen runtime prefix independently rederived; only filesystem loader/five documented live-retry lines differ. Both receipts equal C05 frozen48module/34edge verifier output.',
             'captured_input': 'Exact original C05step12 public snapshot and naturally fresh syntheticGold150 context; original raw line hash checked. No input or future state substituted.',
             'decisions': receipts, 'full_result_differences': diffs,
             'comparison_conclusion': 'Only four survival_priority fields, duplicated at top level and strategy, changed. Candidate314 qualifies the complete root family but finds no all-clearing policy preserving admitted owned assets and separate successful-world rewards. Both recommendations remain Certificate.',
             'selected_action_legality': 'The recommendation targets existing pack offer1 Certificate; no M21 source action was dispatched or legality/scoring verified against source.',
             'budget': {'one_use_spent': True, 'lease': 'M21', 'decisions': 2, 'outer_seconds': 5.5, 'outer_cap_seconds': 30, 'actual_score_calls': 8356, 'aggregate_score_cap': 100000, 'per_decision_cap': 50000, 'violations': []},
             'outcomes': {'complete_captured_comparisons': 1, 'errors': 0, 'unsupported': 0, 'timeouts': 0, 'censored': 0, 'terminal_attempts': 0, 'wins': 0, 'losses': 0},
             'historical_source_outcome': 'C05 remains an independent selected synthetic loss592/600. This comparison does not execute or rescue its continuation.',
             'limits': ['One dependent captured pack state; no source initialization/dispatch/rescore, no terminal, acquisition, retention, Gold progress or win-rate evidence.',
                        'Full policy manifests differ in seven files; the observed full decision difference is limited to the recorded diagnostic fields, without an isolated win-effect claim.',
                        'Whole-decision timings0.31420999998227s and0.33274840004742s are single local observations, not measured general speed gains.',
                        'The completed root-family diagnostic is local comparison qualification; the whole source adapter and player populations remain unqualified.'],
             'qualification': False, 'terminal_evidence': False, 'source_execution': False, 'player_achievement_progress': False, 'game_control': 'none'}
    with (JOB / 'audit.json').open('x', encoding='utf-8') as stream:
        json.dump(audit, stream, indent=2, allow_nan=False)
    assert sha(JOB / 'record.json') == audit['record_sha256']
    print(json.dumps({'status': audit['status'], 'audit_sha256': sha(JOB / 'audit.json'), 'calls': 8356, 'outer_seconds': 5.5, 'result_differences': len(diffs), 'source_actions': 0}))


if __name__ == '__main__':
    main()
