"""Root-only C07 plan/registration after the full reviewed feature bundle is installed.

No call from this module launches a worker. --describe is read-only; only explicit
--register consumes the unused original C07 registration slot through cycle.py.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import importlib.util
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
RUNS = ROOT / 'tools/advisor_eval/runs'
BASE = RUNS / 'gold299_20260914'

def sha(path):
    with Path(path).open('rb') as stream: return hashlib.file_digest(stream, 'sha256').hexdigest()

def read(path):
    return json.loads(Path(path).read_text())

def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()

def verify_installed(installed, expected_digest, graph_path):
    installed = Path(installed).resolve(); installed.relative_to(RUNS)
    assert installed.name.endswith('_installed'), 'Use exact installed evidence, not a candidate or root checkout'
    record = read(installed / 'record.json'); policy = record['policy']
    assert record['version'] == '2.120.0-alpha', 'C07 is bound to final320, not an earlier installation'
    assert expected_digest and policy['policy_digest'] == expected_digest == digest(policy['policy_files'])
    stem = installed.name.removesuffix('_installed')
    validation_path = installed.parent / (stem + '_installed_validation/report.json')
    final_path = installed.parent / (stem + '_final/final_verification.json')
    validation = read(validation_path); final = read(final_path)
    assert validation['passed'] and validation['policy_unchanged'] and validation['tests_unchanged']
    assert validation['policy_digest'] == final['policy_digest'] == expected_digest
    assert final['version'] == record['version'] and final['installed_matches'] and final['native_unchanged']
    assert final['installed_report'] == sha(validation_path) and final['config_restored_or_modified_by_finalizer'] is False
    for name, expected in policy['policy_files'].items():
        source = (installed / 'policy' / name).resolve(); source.relative_to(installed / 'policy')
        assert sha(source) == expected, 'Frozen installed byte changed: ' + name
    features = read(HERE / 'required_features.json')['files']
    for name, expected in features.items():
        assert policy['policy_files'].get(name) == expected, 'Reviewed future feature missing/changed: ' + name
    assert 'game_speed.lua' in (installed / 'policy/Brainstorm/Core/Brainstorm.lua').read_text()
    graph = read(graph_path)
    assert graph['kind'] == 'c07_complete_installed_graph_check' and graph['passed']
    assert Path(graph['policy_root']).resolve() == installed / 'policy'
    assert graph['policy_files'] == policy['policy_files'] and graph['policy_digest'] == expected_digest
    assert graph['source_initializations'] == graph['policy_decisions'] == 0
    assert graph['graph']['gold_objective_enabled'] and not graph['graph']['retry_enabled']
    for name, expected in graph['adapter_files'].items(): assert sha(HERE / name) == expected
    assert set(graph['adapter_files']) == {'engine_run.lua','policy_wiring.lua','test_wiring.lua','check_graph.py'}
    scratch = Path(graph['scratch']).resolve(); scratch.relative_to(HERE)
    assert sha(scratch / 'raw.json') == graph['raw_report_sha256'] and sha(scratch / 'stdout.log') == graph['stdout_sha256']
    return installed, record, validation_path, final_path, graph

def plan(installed, expected_digest, graph_path):
    installed, record, validation_path, final_path, graph = verify_installed(installed, expected_digest, graph_path)
    authority = read(BASE / 'authority.json')
    assert authority['status'] == 'APPROVED' and authority['per_job_caps']['C07'] == 180
    assert not (BASE / 'CLOSED.json').exists() and not (BASE / 'C07').exists() and not (BASE / 'C07_reservation.json').exists()
    assert datetime.now(timezone.utc).timestamp() + 180 <= datetime.fromisoformat(authority['expires_at_utc']).timestamp()
    manifest = read(HERE / 'preparation_manifest.json')
    for name, expected in manifest['prepared_files'].items(): assert sha(HERE / name) == expected, 'Prepared adapter changed: ' + name
    origins = read(HERE / 'preparation_origins.json')
    prior = read(BASE / 'C06/registration.json')
    for item in origins:
        assert sha(HERE / item['file']) == item['prepared_sha256']
        assert sha(BASE / item['source']) == item['source_sha256'] == prior['files'][item['file']]
    selection = read(HERE / 'normal_seed_selection.json'); recipe = read(HERE / 'normal_opening_recipe.json')
    assert selection['seed'] == recipe['seed'] == 'M4BVSY11'
    assert selection['source_search_job'] == recipe['discovery']['job'] == 'S04'
    for name, expected in selection['search_evidence'].items(): assert sha(BASE / 'S04' / name) == expected
    assert recipe['discovery']['result_sha256'] == selection['search_evidence']['result.json']
    for name in ('normal_opening_recipe.json', 'normal_seed_selection.json'): assert sha(HERE / name) == prior['files'][name]
    assert read(BASE / 'C06/audit.json')['disposition'] == 'timeout'
    files = {name: HERE / name for name in manifest['prepared_files']}
    files['preparation_manifest.json'] = HERE / 'preparation_manifest.json'
    files.update({'authority.json': BASE / 'authority.json', 'cycle_orchestrator.py': ROOT / 'tools/advisor_eval/development299/cycle.py',
                  'installed_policy_record.json': installed / 'record.json', 'installed_final_verification.json': final_path,
                  'installed_validation.json': validation_path, 'installed_graph_check.json': Path(graph_path),
                  'inert_graph_raw.json': Path(graph['scratch']) / 'raw.json', 'inert_graph_stdout.log': Path(graph['scratch']) / 'stdout.log'})
    for job in ('C04', 'C05', 'C06'):
        for name in ('record.json', 'registration.json', 'audit.json'): files['prior_' + job + '_' + name] = BASE / job / name
    for name in selection['search_evidence']: files['observed_S04_' + name] = BASE / 'S04' / name
    for name in record['policy']['policy_files']: files['policy/' + name] = installed / 'policy' / name
    metadata = {
        'hypothesis': 'Observe whether the installed narrow Yorick additive-growth and exact-five pack/history integrations change legal discard/pack behavior and terminal progression on this dependent development seed. No isolated causal effect or numerical odds is claimed.',
        'checkpoint': 320, 'installed_version': record['version'], 'policy_digest': expected_digest, 'maximum_actions': 500, 'outer_seconds': 180,
        'attempt_scope': 'One fresh full original-source initialization; no imported state, replay, checkpoint, retry or counterfactual prefix. All errors/unsupported/timeouts/censored/losses remain explicit.',
        'seed': 'M4BVSY11', 'deck': 'b_red', 'stake': 8,
        'selection': 'Observed S04 fixed-target recipe previously used by C01/C02/C04/C06; selected dependent synthetic development, not an unseen holdout.',
        'search_receipt': selection['search_evidence'], 'opening_jokers': ['j_yorick', 'j_perkeo'],
        'conditional_later_targets': [{'key': 'j_brainstorm', 'by_ante': 5}, {'key': 'j_burnt', 'by_ante': 5}],
        'no_perishable_targets': True, 'search_cpu_mode': 'Historical S04 maximum; no new search',
        'profile': 'all_unlocked_discovered_v1', 'qualification': False,
        'source_access': 'Executable ZIP and isolated lua51.dll only; never launch Balatro.exe',
        'save_access': 'none', 'player_profile_access': False, 'native_search_in_attempt': False, 'retry_context': 'disabled_clean',
        'gold_objective_context': 'synthetic_fresh_all_missing_v1; capture must verify naturally empty loaded history and150missing0unknown before decisions. No fabricated sticker history.',
        'adapter_change': 'Preserve C06 source dispatch/terminal mechanics; require the complete current installed decision graph via frozen inert graph proof and exact reviewed feature bytes. Trace wiring label updated only.',
        'ui_scope': 'Freeze all current Core/UI/native dependency bytes including game_speed. They are not executed by source dispatch; no live search/button/cash-out/autorun/input/8x/16x timing qualification.',
        'original_action_callbacks': True, 'product_execution_ui_bypassed': True,
        'installed_final_verification_sha256': sha(final_path), 'installed_graph_check_sha256': sha(graph_path),
        'reviewed_feature_files': read(HERE / 'required_features.json')['files'],
        'confounding': 'The installed bundle contains multiple changes after frozen315 and preceding censored attempts. Fresh dependent progression cannot isolate one feature, impute a terminal result, or establish player odds/human superiority.',
        'metrics': ['terminal consistency/original callbacks/synthetic Gold deltas', 'selected-action legality/exact scores/supported floors/random gaps',
                    'actual discard counts, Yorick thresholds and growth rejection/admission', 'pack family completion/choice/physical discard history',
                    'cash/acquisition/retention/Burnt/Perkeo copies', 'ordinary140000/shop50000/consumable25000/fastclear70 work, advice/action/attempt cost'],
        'python_executable': str(Path(sys.executable).resolve()), 'python_version': sys.version,
    }
    external = [Path(p) for p in prior['external_files'] if Path(p).name.lower() in ('balatro.exe', 'lua51.dll')]
    assert {p.name.lower() for p in external} == {'balatro.exe', 'lua51.dll'}
    external.append(Path(sys.executable).resolve())
    metadata['prior_external_files'] = {str(p): prior['external_files'].get(str(p)) for p in external}
    return files, metadata, external

def register(installed, expected_digest, graph_path):
    files, metadata, external = plan(installed, expected_digest, graph_path)
    # Root-only prospective registration verifies source/runtime hashes before
    # reserving the one-use job; --describe and preparation never read them.
    prior = read(BASE / 'C06/registration.json')['external_files']
    for path in external:
        if str(path) in prior: assert sha(path) == prior[str(path)], 'Original source/runtime changed before registration'
    spec = importlib.util.spec_from_file_location('gold299_cycle', ROOT / 'tools/advisor_eval/development299/cycle.py')
    cycle = importlib.util.module_from_spec(spec); spec.loader.exec_module(cycle)
    return cycle.register('C07', files, [sys.executable, '-B', '-u', '{job}/run_attempt7.py'], metadata, external=external)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--installed-dir', type=Path, required=True)
    parser.add_argument('--expected-policy-digest', required=True); parser.add_argument('--graph-report', type=Path, required=True)
    modes = parser.add_mutually_exclusive_group(required=True); modes.add_argument('--describe', action='store_true'); modes.add_argument('--register', action='store_true')
    args = parser.parse_args()
    if args.describe:
        files, metadata, external = plan(args.installed_dir, args.expected_policy_digest, args.graph_report)
        print(json.dumps({'frozen_file_count': len(files), 'metadata': metadata, 'external_paths_not_read': list(map(str, external))}, indent=2))
    else: print(register(args.installed_dir, args.expected_policy_digest, args.graph_report))
