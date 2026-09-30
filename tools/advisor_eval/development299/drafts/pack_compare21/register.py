"""Parent-only M21 registration; import/describe never registers or runs a job."""
from pathlib import Path
import importlib.util
import json
import sys
from prepare_inputs import sha, canonical, module_setup

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
RUNS = ROOT / 'tools/advisor_eval/runs'


def read(path):
    return json.loads(Path(path).read_text())


def plan():
    binding = read(HERE / 'binding.json')
    assert binding['baseline_checkpoint'] == 312 and binding['candidate_checkpoint'] == 314
    files = {p.name: p for p in HERE.iterdir() if p.is_file() and p.suffix in ('.py', '.lua', '.json', '.md')}
    for prohibited in ('registration.json', 'spent.json', 'comparison_started.json', 'comparison.json', 'record.json'):
        assert prohibited not in files, 'Draft must not contain a prior job: ' + prohibited
    files['authority.json'] = RUNS / 'gold299_20260914/authority.json'
    prior = RUNS / 'gold299_20260914/C05'
    provenance = read(HERE / 'input_provenance.json')
    for name in ('record.json', 'registration.json', 'audit.json'):
        assert sha(prior / name) == provenance['source_files'][name]
        files['source_attempt_' + name] = prior / name
    assert sha(prior / 'trace.log') == provenance['source_files']['trace.log']
    assert provenance['source_provenance']['policy_digest'] == binding['baseline']['policy_digest']
    manifests = {}; finals = {}
    for role, version in (('baseline', '2.112.0-alpha'), ('candidate', '2.114.0-alpha')):
        info = binding[role]; installed = Path(info['installed_directory'])
        record = read(installed / 'record.json'); frozen_record = read(HERE / (role + '_record.json'))
        assert record == frozen_record and sha(installed / 'record.json') == info['record_sha256']
        assert record['version'] == version and record['policy']['policy_digest'] == info['policy_digest']
        manifest = record['policy']; manifests[role] = manifest
        import hashlib
        assert hashlib.sha256(canonical(manifest['policy_files'])).hexdigest() == manifest['policy_digest']
        for name, expected in manifest['policy_files'].items():
            source = installed / 'policy' / name
            assert sha(source) == expected, role + '/' + name
            files[role + '/' + name] = source
        prefix, omitted = module_setup((installed / 'policy/Brainstorm/Advisor/runtime.lua').read_bytes())
        assert prefix == (HERE / (role + '_module_setup.lua')).read_bytes()
        assert sha(HERE / (role + '_module_setup.lua')) == info['module_setup_sha256']
        assert omitted == info['omitted_product_integrations']
        stem = installed.name.removesuffix('_installed')
        validation_path = installed.parent / (stem + '_installed_validation/report.json')
        final_path = installed.parent / (stem + '_final/final_verification.json')
        validation = read(validation_path); final = read(final_path)
        assert validation['passed'] is True and validation['policy_unchanged'] is True and validation['tests_unchanged'] is True
        assert validation['policy_digest'] == manifest['policy_digest']
        assert final['version'] == version and final['policy_digest'] == manifest['policy_digest']
        assert final['installed_matches'] is True and final['native_unchanged'] is True
        assert final['config_restored_or_modified_by_finalizer'] is False
        assert final['installed_report'] == sha(validation_path)
        files[role + '_installed_validation.json'] = validation_path
        files[role + '_installed_final_verification.json'] = final_path
        finals[role] = {'verification_sha256': sha(final_path), 'installed_report_sha256': sha(validation_path)}
    metadata = {
        'hypothesis': 'Exact installed314 can qualify the complete free-Joker family that frozen312 rejected at C05 step12; record any full-decision change without assuming a changed action or better continuation.',
        'maximum_decisions': 2, 'decision_order': [['baseline', 12], ['candidate', 12]],
        'maximum_seconds': 30, 'score_call_cap': 100000, 'per_decision_score_cap': 50000,
        'policy_digests': {role: manifests[role]['policy_digest'] for role in manifests},
        'whole_policy_changed_files': binding['policy_changed_files'], 'installed_final_verification': finals,
        'source_attempt': 'C05 selected dependent S7PXV521 synthetic Red Gold loss592/600; this job is no terminal attempt or replay.',
        'source_trace_sha256': provenance['source_files']['trace.log'], 'source_audit_sha256': provenance['source_files']['audit.json'],
        'source_profile': provenance['source_provenance']['profile_spec'],
        'source_profile_digest': provenance['source_provenance']['profile_spec_digest'],
        'source_adapter_digest': provenance['source_provenance']['adapter_digest'],
        'source_rules_digest': provenance['source_provenance']['rules_digest'],
        'source_runtime_digest': provenance['source_provenance']['runtime_digest'],
        'source_gold_objective_spec': provenance['source_provenance']['gold_objective_spec'],
        'snapshot_canonical_sha256': provenance['snapshot_canonical_sha256'], 'input_steps': [12],
        'same_actual_public_input': True, 'gold_objective': 'Unchanged C05 naturally fresh synthetic0complete/150missing/0unknown context',
        'source_execution': False, 'action_dispatch': False, 'selected_action_rescore': False,
        'source_or_game_initialization': False, 'rng': 'Deterministic policy sampling only; math.random/source RNG unavailable',
        'zip_access': False, 'search': False, 'save_access': 'none', 'player_profile_access': False, 'retry_context': 'disabled_clean',
        'comparison': 'Full actions/results/evaluations/score calls preserved; record differences rather than require action or result equality. Only input identity and complete bounded evaluations are required.',
        'module_graph': 'Each exact frozen runtime prefix before A.defaults, filesystem loader replaced with frozen preloads and five live/retry lines omitted; C05 policy_wiring verifies current pack/Certificate/Bell/Perkeo edges.',
        'timing': 'Two host monotonic and two Lua CPU clock reads around each whole decision; no per-score timing.',
        'confounding': 'Selected dependent C05 development;312-versus314 includes every recorded intervening whole-policy difference. Historical C03 also differed in Gold objective. No imported audited future, terminal result or isolated causal win effect.',
        'scope': 'One fresh M21 lease:2decisions/30s/100000calls total, no source actions. Errors, unsupported results, caps and timeout remain without replacement.',
        'qualification': False, 'terminal_evidence': False,
        'python_executable': str(Path(sys.executable).resolve()), 'python_version': sys.version,
    }
    external = [Path(sys.executable).resolve(), Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll')]
    return files, metadata, external


def register():
    files, metadata, external = plan()  # Validate everything before spending any reservation.
    spec = importlib.util.spec_from_file_location('gold299_cycle', ROOT / 'tools/advisor_eval/development299/cycle.py')
    cycle = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cycle)
    return cycle.register('M21', files, [sys.executable, '-B', '-u', '{job}/compare_pack21.py'], metadata, external=external)


if __name__ == '__main__':
    if sys.argv[1:] == ['--describe']:
        files, metadata, external = plan()
        print(json.dumps({'frozen_file_count': len(files), 'metadata': metadata, 'external': list(map(str, external))}, indent=2))
    elif sys.argv[1:] == ['--register']:
        print(register())
    else:
        raise SystemExit('Parent only: --describe or --register; never runs the worker')
