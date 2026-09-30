"""DRAFT ONLY. Root may register M10 after a coherent repaired policy is frozen.

Importing does not register or run. Executing this script registers only; the
separate root-owned cycle runner consumes and launches the one-use job.
"""
from pathlib import Path
import json
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
from cycle import ROOT, BASE, register


def main(candidate_path):
    candidate_path = Path(candidate_path).resolve()
    baseline_path = ROOT / 'tools/advisor_eval/runs/phaseopening300_installed/record.json'
    records = {'baseline300': baseline_path, 'candidate': candidate_path}
    files = {name: HERE / name for name in ('compare_shop10.py', 'driver_shop10.lua', 'lua_bytes.py')}
    files.update({'authority.json': BASE / 'authority.json',
                  'step138.json': HERE.parents[1] / 'c01_analysis/step138.json',
                  'step139.json': HERE.parents[1] / 'c01_analysis/step139.json',
                  'source_attempt_record.json': BASE / 'C01/record.json',
                  'source_attempt_audit.json': BASE / 'C01/audit.json',
                  'captured_snapshot_pair.py': ROOT / 'tools/advisor_eval/captured_snapshot_pair.py',
                  'engine_run.lua': BASE / 'C01/engine_run.lua',
                  'engine_contract.lua': BASE / 'C01/engine_contract.lua'})
    digests = {}
    for role, path in records.items():
        record = json.loads(path.read_text()); policy = path.parent / 'policy'
        digests[role] = record['policy']['policy_digest']
        files[role + '_record.json'] = path
        files.update({role + '/' + name: policy / name for name in record['policy']['policy_files']})
    runtime = Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll')
    register('M10', files, [sys.executable, '-B', '-u', '{job}/compare_shop10.py'],
             {'hypothesis': 'One legal fixed scoring setup across the same four worlds removes the artificial loss of copied Yorick scoring caused solely by the Perkeo shop-exit reorder; every projected reorder remains an explicitly priced action.',
              'mechanical_boundary': 'Exactly four detached decisions: baseline300 step138, baseline300 step139, candidate step138, candidate step139. Thirty seconds total including loading/serialization. No original source execution, action dispatch, extra score audit, follow-up projection, seed search, complete attempt or fifth decision.',
              'policy_digests': digests,
              'captured_pair_job': True,
              'captured_policy_evaluations_planned': 4,
              'source_snapshot': 'C01 steps138/139, original preserved development snapshots; no player saves',
              'source_snapshots': ['C01step138', 'C01step139'],
              'profile': 'preserved selected synthetic all_unlocked_discovered_v1; actual player profile unavailable',
              'seed': 'M4BVSY11', 'qualification': False, 'save_access': 'none',
              'source_execution': False, 'runtime_access': 'isolated lua51.dll',
              'options': 'product_defaults_no_overrides', 'retry_context': 'disabled_clean',
              'maximum_decisions': 4, 'candidate_shop_score_cap': 50000,
              'expected': ['Both policy inputs remain unchanged and identically fingerprinted per step.',
                           'Original snapshots differ only in the order of the same physical Jokers.',
                           'Frozen300 reproduces equal opening scores but unequal whole-blind means.',
                           'Candidate selects the same physical fixed order and the same non-setup trajectories/resources in all four worlds for both policies.',
                           'Candidate projected setup actions and paired action costs remain explicit.'],
              'non_requirements': ['No required choice to retain or sell Perkeo.',
                                   'No requirement that the final action remains the same across snapshots or policies.',
                                   'No terminal outcome, acquisition, win-rate, player progress, or adapter qualification inference.'],
              'failure_preservation': 'Any timeout, error, incomplete projection or failed invariant spends M10 permanently; preserve all partial result files and do not substitute a fifth decision.'},
             [runtime])


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('Registration draft: pass a coherent repaired frozen policy record; this does not run M10.')
    main(sys.argv[1])
