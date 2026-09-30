"""Bounded manufactured fixtures; no captured/source/search/run execution."""
from pathlib import Path
import hashlib,json,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[4];HERE=Path(__file__).resolve().parent
label=sys.argv[1];assert label.replace('_','').isalnum()
wrapper=HERE/('run_baseline.lua' if label.startswith('baseline') else 'run_candidate.lua')
output=HERE/label;output.mkdir(exist_ok=False)
paths=[wrapper,HERE/'tests/advisor_burnt_margin.lua',HERE/'Brainstorm/Advisor/phase_copy.lua',HERE/'before/phase_copy.lua',
 ROOT/'tools/advisor_eval/development350/yorick_component/Brainstorm/Advisor/growth.lua']
paths += [ROOT/'Brainstorm/Advisor'/p for p in ['scoring.lua','strategy.lua','search.lua','decision.lua','snapshot.lua','gold_stickers.lua','ordering.lua','consumables.lua']]
files={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
(output/'input_fixture.lua').write_bytes((HERE/'tests/advisor_burnt_margin.lua').read_bytes())
command=[sys.executable,'tests/run_lua_tests.py',wrapper.relative_to(ROOT).as_posix()]
start=time.monotonic()
try:
 r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
 status='passed' if r.returncode==0 else 'failed';code=r.returncode;log=r.stdout+'\n'+r.stderr
except subprocess.TimeoutExpired as e:status='timeout';code=None;log=str(e.stdout)+'\n'+str(e.stderr)
elapsed=time.monotonic()-start
(output/'output.log').write_text(log,encoding='utf-8')
(output/'report.json').write_text(json.dumps({'scope':'Manufactured fixture only; no captured/source/search/complete jobs',
 'command':command,'status':status,'exit_code':code,'seconds':elapsed,'cap_seconds':60,'input_hashes':files,
 'inputs_unchanged':all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in files.items()),
 'log_sha256':hashlib.sha256((output/'output.log').read_bytes()).hexdigest()},indent=2)+'\n',encoding='utf-8')
print(log);sys.exit(0 if status=='passed' else 1)
