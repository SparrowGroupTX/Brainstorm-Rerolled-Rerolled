"""Run the independently invented new tie cases against frozen candidate1."""
from pathlib import Path
import subprocess,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
source=(ROOT/'tests/advisor_perkeo_exit414.lua').read_text()
target=HERE/'tie_before.lua'
with target.open('x') as f:f.write(source.replace("'Brainstorm/Advisor/","'tools/advisor_eval/runs/repair414_candidate1/policy/Brainstorm/Advisor/"))
r=subprocess.run([sys.executable,'tests/run_lua_tests.py',str(target)],cwd=ROOT,capture_output=True,text=True,creationflags=subprocess.CREATE_NO_WINDOW)
with (HERE/'tie_before.log').open('x') as f:f.write(r.stdout+'\n'+r.stderr)
assert r.returncode!=0,'Expected old strict positive-gain gate to fail the new tie preference'
print(r.stdout+r.stderr)
