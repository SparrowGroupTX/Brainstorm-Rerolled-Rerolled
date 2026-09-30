"""Parent-only registration preparation; --describe never registers or executes."""
from pathlib import Path
import importlib.util
import hashlib
import json
import sys
from prepare_inputs import canonical, module_setup, sha, DIGESTS

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
RUNS = ROOT / 'tools/advisor_eval/runs'


def plan():
    binding = json.loads((HERE / 'binding.json').read_text())
    assert binding['job'] == 'M22' and binding['baseline_checkpoint'] == 314 and binding['candidate_checkpoint'] == 315
    provenance = json.loads((HERE / 'input_provenance.json').read_text())
    records = {role: json.loads((HERE / (role + '_record.json')).read_text())['policy']
               for role in ('baseline', 'candidate')}
    roots = {'baseline': RUNS / 'pack314_installed/policy', 'candidate': RUNS / 'copy315_installed/policy'}
    names = ('compare_copy22.py', 'driver.lua', 'lua_bytes.py', 'baseline_module_setup.lua',
             'candidate_module_setup.lua', 'engine_contract.lua', 'baseline_record.json',
             'candidate_record.json', 'step31.json', 'step96.json', 'input_provenance.json',
             'register.py', 'prepare_inputs.py', 'INTEGRATION.md', 'test_spec.py', 'test_driver.lua', 'binding.json')
    files = {name: HERE / name for name in names}
    files['authority.json'] = RUNS / 'gold299_20260914/authority.json'
    for name, expected in provenance['source_files'].items():
        assert sha(ROOT / name) == expected, 'C04 source provenance changed: ' + name
    for name in ('record.json', 'registration.json', 'audit.json'):
        files['source_attempt_' + name] = RUNS / 'gold299_20260914/C04' / name
    for step in (31, 96):
        path = HERE / f'step{step}.json'; snap = json.loads(path.read_text())['snapshot']
        origin = provenance['snapshots'][str(step)]
        assert sha(path) == origin['snapshot_file_sha256']
        assert hashlib.sha256(canonical(snap)).hexdigest() == origin['snapshot_canonical_sha256']
    finals = {}
    for role, policy in records.items():
        info = binding['roles'][role]
        actual_records = {}
        for kind, bound in info['files'].items():
            path = ROOT / bound['path']
            assert sha(path) == bound['sha256'], 'Bound installed evidence changed: ' + str(path)
            actual_records[kind] = json.loads(path.read_text())
            files[role + '_installed_' + kind + '.json'] = path
        record = actual_records['record']; validation = actual_records['installed_validation']; final = actual_records['final_verification']
        assert record == json.loads((HERE / (role + '_record.json')).read_text())
        assert record['version'] == info['version'] and policy['policy_digest'] == info['policy_digest'] == DIGESTS[role]
        assert hashlib.sha256(canonical(policy['policy_files'])).hexdigest() == DIGESTS[role]
        assert validation['passed'] is True and validation['policy_unchanged'] is True and validation['tests_unchanged'] is True
        assert validation['policy_digest'] == DIGESTS[role]
        assert final['version'] == info['version'] and final['policy_digest'] == DIGESTS[role]
        assert final['installed_matches'] is True and final['native_unchanged'] is True
        assert final['config_restored_or_modified_by_finalizer'] is False
        assert final['installed_report'] == info['files']['installed_validation']['sha256']
        prefix, omitted = module_setup((roots[role] / 'Brainstorm/Advisor/runtime.lua').read_bytes())
        assert prefix == (HERE / (role + '_module_setup.lua')).read_bytes()
        assert omitted == provenance['module_setups'][role]['omitted_product_integrations']
        assert sha(HERE / (role + '_module_setup.lua')) == provenance['module_setups'][role]['derived_setup_sha256']
        for name in policy['policy_files']:
            assert sha(roots[role] / name) == policy['policy_files'][name], 'Frozen policy changed: ' + role + '/' + name
            files[role + '/' + name] = roots[role] / name
        finals[role] = info['files']
    metadata = {
        'hypothesis': 'Exact315 can prove the same useful Perkeo-to-Yorick scoring copy setup before expensive draw planning, with complete paired resources and charged score work. Both success and fallback remain observable.',
        'maximum_decisions': 4,
        'decision_order': [['baseline', 31], ['candidate', 31], ['candidate', 96], ['baseline', 96]],
        'score_call_cap': 560000, 'per_decision_score_cap': 140000,
        'policy_digests': {role: p['policy_digest'] for role, p in records.items()},
        'installed_verification': finals,
        'source_trace_sha256': next(value for key, value in provenance['source_files'].items() if Path(key).name == 'trace.log'),
        'snapshot_canonical_sha256': {step: value['snapshot_canonical_sha256'] for step, value in provenance['snapshots'].items()},
        'source_adapter_digest': provenance['source_adapter_digest'],
        'source_rules_digest': provenance['source_rules_digest'], 'source_runtime_digest': provenance['source_runtime_digest'],
        'source_profile_spec': provenance['profile_spec'], 'source_profile_digest': provenance['profile_spec_digest'],
        'source_gold_objective_spec': provenance['gold_objective_context'],
        'policy_comparison': 'Exact whole installed314 versus315; four Advisor files plus release metadata differ. Both full dependency graphs derived from respective frozen runtime.',
        'source_execution': False, 'action_dispatch': False, 'selected_action_rescore': False,
        'source_or_game_initialization': False, 'search': False, 'save_access': 'none',
        'gold_objective': 'Captured synthetic completionist_goal unchanged:150missing,0complete,0unknown.',
        'retry_context': 'disabled_clean', 'source_attempt': 'C04 timeout; selected dependent development, no terminal result.',
        'input_steps': [31, 96], 'selection': 'Eight held cards, ordinary Perkeo/Yorick/Brainstorm/Droll/Supernova; Brainstorm copies first Perkeo. Step31 no discards,step96 two. Prior decisions pure reorder with clear; static evidence only.',
        'comparison': 'Preserve full results, exact raw actions, score counts, complete-input identity, proof diagnostics. Actions/results/counts may differ; no full semantic equivalence assumption.',
        'timing': 'Whole-decision monotonic wall and Lua os.clock only; no per-score timing.',
        'scope': 'One30second wall cap for four decisions plus compilation/I/O. Fresh isolated Lua state per decision. No post-reorder decision or play execution. Error/timeout retained without replacement.',
        'cache_stop_rule': 'Prior M19/M20 cache workers closed; this tests copy planning only and changes no cache bytes.',
        'qualification': False, 'terminal_evidence': False,
        'python_executable': str(Path(sys.executable).resolve()), 'python_version': sys.version}
    external = [Path(sys.executable).resolve(), Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll')]
    return files, metadata, external


def register():
    files, metadata, external = plan()  # All binding validation precedes any reservation.
    spec = importlib.util.spec_from_file_location('gold299_cycle', ROOT / 'tools/advisor_eval/development299/cycle.py')
    cycle = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cycle)
    return cycle.register('M22', files, [sys.executable, '-B', '-u', '{job}/compare_copy22.py'], metadata, external=external)


if __name__ == '__main__':
    if sys.argv[1:] == ['--describe']:
        files, metadata, external = plan()
        print(json.dumps({'frozen_file_count': len(files), 'metadata': metadata, 'external': list(map(str, external))}, indent=2))
    elif sys.argv[1:] == ['--register']:
        print(register())
    else:
        raise SystemExit('Parent only: --describe or --register; never runs the job')
