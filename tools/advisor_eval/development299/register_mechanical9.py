"""Prepare M09 only after root supplies a coherent candidate policy record."""
from pathlib import Path
import json
import sys
from cycle import ROOT, BASE, register

here = Path(__file__).resolve().parent
candidate_path = Path(sys.argv[1]).resolve()
baseline_path = ROOT / 'tools/advisor_eval/runs/phaseopening300_installed/record.json'
records = {'baseline300': baseline_path, 'candidate': candidate_path}
files = {name: here / name for name in ('compare_cap9.py',)}
files.update({'authority.json': BASE / 'authority.json', 'step205.json': here / 'c01_analysis/step205.json',
              'source_attempt_record.json': BASE / 'C01/record.json', 'source_attempt_audit.json': BASE / 'C01/audit.json',
              'captured_snapshot_pair.py': ROOT / 'tools/advisor_eval/captured_snapshot_pair.py',
              'captured_snapshot_pair.lua': ROOT / 'tools/advisor_eval/captured_snapshot_pair.lua',
              'engine_run.lua': BASE / 'C01/engine_run.lua', 'engine_contract.lua': BASE / 'C01/engine_contract.lua'})
digests = {}
for role, path in records.items():
    record = json.loads(path.read_text()); policy = path.parent / 'policy'
    digests[role] = record['policy']['policy_digest']
    files[role + '_record.json'] = path
    files.update({role + '/' + name: policy / name for name in record['policy']['policy_files']})
runtime = Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll')
register('M09', files, [sys.executable, '-B', '-u', '{job}/compare_cap9.py'],
         {'hypothesis': 'Sharing the existing140000 ordinary allowance preserves C01step205 complete93-candidate owned-Moon rescue and exact chosen action while removing stacked ordering work above the limit.',
          'mechanical_boundary': 'Exactly two detached public-snapshot decisions, baseline300 then candidate,30s total. No original source execution, action dispatch, replay, seed search, terminal attempt or additional counterfactual.',
          'policy_digests': digests, 'source_snapshot': 'C01step205', 'profile': 'captured selected synthetic all_unlocked_discovered_v1',
          'seed': 'M4BVSY11', 'qualification': False, 'save_access': 'none', 'source_execution': False,
          'runtime_access': 'isolated lua51.dll', 'options': 'product_defaults_no_overrides', 'retry_context': 'disabled_clean',
          'expected_baseline_score_calls': 150172, 'candidate_maximum': 140000,
          'legality_scope': 'Detached action equality to audited source205; no additional source action. Generic driver reports use legality unsupported; do not convert it into new source verification.'}, [runtime])
