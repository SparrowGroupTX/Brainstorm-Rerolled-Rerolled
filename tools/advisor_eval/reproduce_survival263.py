"""One bounded real-scorer reproduction against frozen installed263; no episode."""
from pathlib import Path
import hashlib
import json
import subprocess

root = Path('tools/advisor_eval/runs/development263_installed/policy').resolve()
out = Path('tools/advisor_eval/runs/shop_survival263_reproduction')
out.mkdir(exist_ok=False)
text = Path('tests/advisor_shop_survival.lua').read_text().split('local checks=0')[0]
text = text.replace("dofile('Brainstorm/Advisor/", "dofile('" + root.as_posix() + '/Brainstorm/Advisor/')
text += '''
local result=Decision.run(state(),modules);local e=result.strategy.scoring_evidence
assert(result.action.kind=='buy' and e.complete_finishing and
  e.before_finishing.selected.clearing_samples==4 and e.after_finishing.selected.clearing_samples==0)
print('Frozen263 buys Golden: dollars5 to2, four supported clears to zero; target95.')
'''
fixture = out / 'reproduction.lua'
fixture.write_text(text)
result = subprocess.run(['python', 'tests/run_lua_tests.py', str(fixture)], timeout=20,
                        creationflags=subprocess.CREATE_NO_WINDOW, capture_output=True, text=True)
(out / 'reproduction.log').write_text(result.stdout + '\n' + result.stderr)
(out / 'manifest.json').write_text(json.dumps({
    'policy_root': str(root), 'policy_record_sha256': hashlib.sha256((root.parent / 'record.json').read_bytes()).hexdigest(),
    'fixture_sha256': hashlib.sha256(fixture.read_bytes()).hexdigest(), 'timeout_seconds': 20, 'exit_code': result.returncode,
    'scope': 'constructed deterministic decision, no source episode or measured win evidence'}, indent=2))
print(result.stdout)
print(result.stderr)
raise SystemExit(result.returncode)
