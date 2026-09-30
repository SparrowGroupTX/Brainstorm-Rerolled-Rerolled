"""Root-only C06 plan/registration after exact315 installed final verification."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
RUNS = ROOT / 'tools/advisor_eval/runs'
BASE = RUNS / 'gold299_20260914'


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def read(path):
    return json.loads(Path(path).read_text())


def plan(installed):
    installed = Path(installed).resolve()
    record = read(installed / 'record.json'); policy = record['policy']
    assert record['version'] == '2.115.0-alpha'
    assert hashlib.sha256(json.dumps(policy['policy_files'], sort_keys=True, separators=(',', ':')).encode()).hexdigest() == policy['policy_digest']
    stem = installed.name.removesuffix('_installed')
    validation_path = installed.parent / (stem + '_installed_validation/report.json')
    final_path = installed.parent / (stem + '_final/final_verification.json')
    validation = read(validation_path); final = read(final_path)
    assert validation['passed'] and validation['policy_unchanged'] and validation['tests_unchanged']
    assert validation['policy_digest'] == final['policy_digest'] == policy['policy_digest']
    assert final['version'] == '2.115.0-alpha' and final['installed_matches'] and final['native_unchanged']
    assert final['installed_report'] == sha(validation_path) and final['config_restored_or_modified_by_finalizer'] is False
    assert 'Brainstorm/Advisor/hand_copy_preflight.lua' in policy['policy_files']
    runtime = (installed / 'policy/Brainstorm/Advisor/runtime.lua').read_text()
    prefix = runtime.split('\nfunction A.defaults()')[0]
    assert prefix.count("A.hand_copy_preflight = module('hand_copy_preflight')") == 1
    origins = read(HERE / 'preparation_origins.json')
    for item in origins:
        assert sha(HERE / item['file']) == item.get('prepared_sha256', item['source_sha256'])
        assert sha(BASE / item['source']) == item['source_sha256']
    recipe = read(HERE / 'normal_opening_recipe.json'); selection = read(HERE / 'normal_seed_selection.json')
    assert recipe['seed'] == selection['seed'] == 'M4BVSY11'
    assert recipe['discovery']['job'] == selection['source_search_job'] == 'S04'
    for name, expected in selection['search_evidence'].items():
        assert sha(BASE / 'S04' / name) == expected
    assert recipe['discovery']['result_sha256'] == selection['search_evidence']['result.json']
    prior = read(BASE / 'C04/registration.json')
    assert sha(HERE / 'normal_opening_recipe.json') == prior['files']['normal_opening_recipe.json']
    assert sha(HERE / 'normal_seed_selection.json') == prior['files']['normal_seed_selection.json']
    assert read(BASE / 'C04/audit.json')['disposition'] == 'timeout'
    files = {p.name: p for p in HERE.iterdir() if p.is_file() and p.suffix in ('.py', '.lua', '.json', '.md')}
    assert not any(n in files for n in ('registration.json', 'spent.json', 'record.json', 'trace.log'))
    files.update({'authority.json': BASE / 'authority.json', 'installed_policy_record.json': installed / 'record.json',
                  'installed_final_verification.json': final_path, 'installed_validation.json': validation_path})
    for job in ('C04', 'C05'):
        for name in ('record.json', 'registration.json', 'audit.json'):
            files['prior_' + job + '_' + name] = BASE / job / name
    for name in selection['search_evidence']:
        files['observed_S04_' + name] = BASE / 'S04' / name
    for name, expected in policy['policy_files'].items():
        source = installed / 'policy' / name
        assert sha(source) == expected
        files['policy/' + name] = source
    metadata = {
        'hypothesis': 'Exact installed315 complete current-hand copy preflight may reduce avoidable long decisions and preserve supported complete action/resource comparisons on the previously censored M4BVSY11 route; actual terminal and timing outcomes remain unknown.',
        'checkpoint': 315, 'maximum_actions': 500, 'outer_seconds': 180,
        'attempt_scope': 'One fresh full source initialization,180s/500actions; no imported state, replay, checkpoint, retry, continuation or counterfactual prefix. Every error/unsupported/timeout/censored/loss is preserved.',
        'seed': 'M4BVSY11', 'deck': 'b_red', 'stake': 8,
        'selection': 'Actual S04 observed recipe, previously used by C01/C02/C04; selected dependent synthetic development, not unseen holdout.',
        'search_receipt': selection['search_evidence'], 'opening_jokers': ['j_yorick', 'j_perkeo'],
        'conditional_later_targets': [{'key': 'j_brainstorm', 'by_ante': 5}, {'key': 'j_burnt', 'by_ante': 5}],
        'filter_scope': 'Exact S04 fixed-target receipt, not S05/S7 OR-copy or optional-target recipe; nativeAPI9 discovery using observedAPI8 opening metadata.',
        'no_perishable_targets': True, 'search_cpu_mode': 'Historical S04 maximum; no new search',
        'profile': 'all_unlocked_discovered_v1', 'qualification': False,
        'source_access': 'Executable ZIP and isolated lua51.dll only; never launch Balatro.exe',
        'save_access': 'none', 'player_profile_access': False, 'native_search_in_attempt': False, 'retry_context': 'disabled_clean',
        'gold_objective_context': 'synthetic_fresh_all_missing_v1; source capture must verify naturally empty loaded history and150missing0unknown before decisions. No fabricated sticker history.',
        'adapter_change': 'From exact C05 source adapter: add actual hand_copy_preflight root module and require prepare/compare interfaces in315 verifier. No new module edges; all34 existing graph edges retained.',
        'policy_digest': policy['policy_digest'], 'installed_final_verification_sha256': sha(final_path),
        'confounding': 'C04 was frozen303 and censored;315 contains all later registered policy changes. This fresh dependent attempt cannot isolate one change, infer a missing terminal, or establish player odds/human superiority.',
        'metrics': ['terminal callbacks and actual synthetic Gold deltas', 'selected-action legality/exact scores/random gaps', 'copy preflight admission/complete actions and counters', 'pack family completion and actual choice', 'cash/acquisition/retention/Yorick discards/Perkeo copies', 'ordinary140000/shop50000/consumable25000/fastclear70 work and computation/action/attempt cost'],
        'python_executable': str(Path(sys.executable).resolve()), 'python_version': sys.version,
    }
    external = [Path(p) for p in prior['external_files']]
    assert {p.name.lower() for p in external} == {'balatro.exe', 'lua51.dll'}
    external.append(Path(sys.executable).resolve())
    return files, metadata, external


def register(installed):
    files, metadata, external = plan(installed)
    spec = importlib.util.spec_from_file_location('gold299_cycle', ROOT / 'tools/advisor_eval/development299/cycle.py')
    cycle = importlib.util.module_from_spec(spec); spec.loader.exec_module(cycle)
    return cycle.register('C06', files, [sys.executable, '-B', '-u', '{job}/run_attempt6.py'], metadata, external=external)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--installed-dir', type=Path, required=True)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--describe', action='store_true'); modes.add_argument('--register', action='store_true')
    args = parser.parse_args()
    if args.describe:
        files, metadata, external = plan(args.installed_dir)
        print(json.dumps({'frozen_file_count': len(files), 'metadata': metadata, 'external': list(map(str, external))}, indent=2))
    else:
        print(register(args.installed_dir))
