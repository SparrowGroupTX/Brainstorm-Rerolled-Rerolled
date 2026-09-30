from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,subprocess,sys,time
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3]
before='--before' in sys.argv;related='--related' in sys.argv
label='before' if before else 'related' if related else 'candidate'
base=OUT/'before' if before else OUT
files=['decision.lua','concealed_belief.lua','phase_copy.lua']
fixtures=['tools/advisor_eval/development350/copy_component/tests/advisor_concealed_copy_order.lua']
if related:fixtures=['tests/advisor_concealed_belief.lua','tests/advisor_concealed_continuation.lua','tests/advisor_concealed_nine_card.lua','tests/advisor_phase_copy.lua']
n=1
while (OUT/f'{label}_{n:02}.json').exists():n+=1
wrappers=[]
for index,fixture in enumerate(fixtures):
 p=OUT/f'run_{label}_{n:02}_{index}.lua';wrappers.append(p)
 mappings={f'Brainstorm/Advisor/{f}':str((base/'Brainstorm/Advisor'/f).relative_to(ROOT)).replace('\\','/')for f in files}
 p.write_text('local map={'+','.join('[%s]=%s'%(json.dumps(k),json.dumps(v))for k,v in mappings.items())+'}\nlocal old=dofile;dofile=function(p)return old(map[p]or p)end\ndofile('+json.dumps(fixture)+')\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
inputs=[base/'Brainstorm/Advisor'/f for f in files]+[ROOT/f for f in fixtures]+wrappers+[Path(__file__).resolve()]
hashes={str(p.relative_to(ROOT)):sha(p)for p in inputs}
command=[sys.executable,'tests/run_lua_tests.py']+[str(p.relative_to(ROOT))for p in wrappers];start=time.monotonic()
try:
 r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
 result={'exit_code':r.returncode,'stdout':r.stdout,'stderr':r.stderr}
except subprocess.TimeoutExpired as e:result={'timeout':True,'stdout':str(e.stdout),'stderr':str(e.stderr)}
result.update(schema=1,created_utc=datetime.now(timezone.utc).isoformat(),command=command,seconds=time.monotonic()-start,max_seconds=60,
 scope='Manufactured fixtures only; no captured policy, original source, searches, attempts, save/profile access or game control.',
 inputs=hashes,inputs_unchanged=all(sha(ROOT/p)==h for p,h in hashes.items()))
(OUT/f'{label}_{n:02}.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in result.items()if k!='inputs'}))
raise SystemExit(0 if result.get('exit_code')==0 else 1)
