"""Discriminating new invented regressions against exact414; not captured replay."""
from pathlib import Path
import subprocess,sys,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
results=[]
for name in ('acorn_discard','mouth_planning','teacher_rescue'):
 path=HERE/('baseline_'+name+'.lua')
 with path.open('x') as f:
  f.write("ADVISOR416_ROOT='tools/advisor_eval/runs/repair414_candidate2/policy/Brainstorm/Advisor/'\n")
  f.write("dofile('tests/advisor_"+name+"416.lua')\n")
 r=subprocess.run([sys.executable,'tests/run_lua_tests.py',str(path)],cwd=ROOT,capture_output=True,text=True,timeout=60)
 (HERE/('baseline_'+name+'.log')).write_text(r.stdout+'\n'+r.stderr,encoding='utf-8')
 results.append({'fixture':name,'exit_code':r.returncode,'expected_failure':r.returncode==1})
assert all(x['expected_failure'] for x in results)
(HERE/'baseline_manufactured.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results))
