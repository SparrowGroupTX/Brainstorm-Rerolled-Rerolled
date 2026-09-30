"""Parent-only prospective registration. Import/describe performs no registration."""
from pathlib import Path
import importlib.util
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
RUNS = ROOT / 'tools/advisor_eval/runs'


def plan():
    baseline_root = RUNS / 'certificate309_installed/policy'
    prior = RUNS / 'gold299_20260914/C04'
    baseline = json.loads((HERE / 'baseline_record.json').read_text())['policy']
    candidate = json.loads((HERE / 'candidate_record.json').read_text())['policy']
    names = ('compare_cache20.py', 'driver.lua', 'lua_bytes.py', 'module_setup.lua', 'engine_contract.lua',
             'baseline_record.json', 'candidate_record.json', 'step85.json', 'step185.json', 'input_provenance.json')
    files = {name: HERE / name for name in names}
    files['authority.json'] = RUNS / 'gold299_20260914/authority.json'
    for old_name in ('audit.json','record.json','comparison.json','registration.json'):
        files['M19_' + old_name] = RUNS / 'gold299_20260914/M19' / old_name
    for name in ('record.json', 'registration.json', 'audit.json'):
        files['source_attempt_' + name] = prior / name
    for name in baseline['policy_files']:
        files['baseline/' + name] = baseline_root / name
        files['candidate/' + name] = HERE / 'candidate_score_cache.lua' if name == 'Brainstorm/Advisor/score_cache.lua' else baseline_root / name
    metadata = {'hypothesis': 'Dense prime-indexed two-way exact-key replacement at the same8192 ceiling avoids sparse numeric-key deletion/insertion overhead while retaining later classifications; M19 FIFO was slower and is not installed.',
                'maximum_decisions': 4, 'decision_order': [['baseline', 85], ['candidate', 85], ['candidate', 185], ['baseline', 185]],
                'score_call_cap': 560000, 'per_decision_score_cap': 140000, 'cache_capacity': 8192, 'reachable_entries': 8186, 'ways': 2, 'prime_buckets': 4093,
                'policy_digests': {'baseline': baseline['policy_digest'], 'candidate': candidate['policy_digest']},
                'source_execution': False, 'action_dispatch': False, 'selected_action_rescore': False,
                'source_or_game_initialization': False, 'search': False, 'save_access': 'none',
                'gold_objective': 'preserve captured synthetic completionist_goal unchanged', 'retry_context': 'disabled_clean',
                'source_attempt': 'C04 timeout, selected dependent development; no terminal outcome',
                'input_steps': [85, 185], 'only_changed_policy_file': 'Brainstorm/Advisor/score_cache.lua',
                'semantic_comparison': 'Full result equality except top-level score_cache diagnostics; same actions/evaluations/actual score calls/inputs mandatory',
                'timing': 'Only whole-decision host monotonic wall and Lua os.clock; no per-score timers',
                'scope': 'Fresh distinct M20; one30s cap includes all four decisions/compilation/I/O. Errors and timeouts are retained without replacement.',
                'prior_negative_evidence': 'Frozen M19 audit/record/comparison: fewer FIFO misses, slower on both pairs; no repeat of that candidate',
                'negative_stop_rule': 'No further cache workers after M20 if negative',
                'qualification': False, 'terminal_evidence': False, 'python_executable': str(Path(sys.executable).resolve()), 'python_version': sys.version}
    external = [Path(sys.executable).resolve(), Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll')]
    return files, metadata, external


def register():
    spec = importlib.util.spec_from_file_location('gold299_cycle', ROOT / 'tools/advisor_eval/development299/cycle.py')
    cycle = importlib.util.module_from_spec(spec);spec.loader.exec_module(cycle)
    files, metadata, external = plan()
    return cycle.register('M20', files, [sys.executable, '-B', '-u', '{job}/compare_cache20.py'], metadata, external=external)


if __name__ == '__main__':
    if sys.argv[1:] == ['--describe']:
        files, metadata, external = plan()
        print(json.dumps({'frozen_file_count': len(files), 'metadata': metadata, 'external': list(map(str, external))}, indent=2))
    elif sys.argv[1:] == ['--register']:
        print(register())
    else:
        raise SystemExit('Parent only: --describe or --register; never runs the job')
