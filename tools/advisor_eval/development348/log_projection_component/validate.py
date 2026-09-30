from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,subprocess,sys,time
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3]
before='--before' in sys.argv;baseline='--baseline347' in sys.argv
label='baseline347' if baseline else 'before' if before else 'candidate'
fixture=OUT/'tests/advisor_auto_log_projection.lua';module=ROOT/'Brainstorm/Advisor/auto_run.lua'
if before:module=OUT/'before/Brainstorm/Advisor/auto_run.lua'
if baseline:module=ROOT/'tools/advisor_eval/runs/gold347_installed/policy/Brainstorm/Advisor/auto_run.lua'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
n=1
while (OUT/f'{label}_{n:02}.json').exists():n+=1
wrapper=OUT/f'run_{label}_{n:02}.lua'
with wrapper.open('x',encoding='utf-8')as f:
 if before or baseline:
  source=str(module.relative_to(ROOT)).replace('\\','/')
  f.write("local old=dofile;dofile=function(p)if p=='Brainstorm/Advisor/auto_run.lua'then p='"+source+"'end;return old(p)end\n")
 f.write("dofile('tools/advisor_eval/development348/log_projection_component/tests/advisor_auto_log_projection.lua')\n")
inputs=[module,fixture,wrapper,Path(__file__).resolve()]
hashes={str(p.relative_to(ROOT)):sha(p)for p in inputs}
command=[sys.executable,'tests/run_lua_tests.py',str(wrapper.relative_to(ROOT))];start=time.monotonic()
try:
 r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
 result={'exit_code':r.returncode,'stdout':r.stdout,'stderr':r.stderr}
except subprocess.TimeoutExpired as e:result={'timeout':True,'stdout':str(e.stdout),'stderr':str(e.stderr)}
result.update(schema=1,created_utc=datetime.now(timezone.utc).isoformat(),command=command,seconds=time.monotonic()-start,max_seconds=60,
 scope='Manufactured injected controller callbacks only. No real workers, game execution, original-source components, captured evaluation, searches, save/profile access or terminal experiments.',
 inputs=hashes,inputs_unchanged=all(sha(ROOT/p)==h for p,h in hashes.items()))
(OUT/f'{label}_{n:02}.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in result.items()if k!='inputs'}))
raise SystemExit(0 if result.get('exit_code')==0 else 1)
