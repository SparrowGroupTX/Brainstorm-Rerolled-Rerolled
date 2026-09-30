from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,subprocess,sys,time
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3]
MODULE='Brainstorm/Advisor/gold_retention.lua'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
n=1
while (OUT/f'validation_{n:02}.json').exists():n+=1
wrapper=OUT/f'run_{n:02}.lua'
with wrapper.open('x',encoding='utf-8') as f:
 f.write("local old=dofile\ndofile=function(p)if p=='Brainstorm/Advisor/gold_retention.lua'then p='tools/advisor_eval/development345/retention_component/Brainstorm/Advisor/gold_retention.lua'end;return old(p)end\n")
 f.write("dofile('tools/advisor_eval/development345/retention_component/tests/advisor_gold_retention.lua')\n")
inputs=sorted((ROOT/'Brainstorm/Advisor').glob('*.lua'))+[OUT/MODULE,OUT/'tests/advisor_gold_retention.lua',wrapper]
hashes={str(p.relative_to(ROOT)):sha(p) for p in inputs}
start=time.monotonic();command=[sys.executable,'tests/run_lua_tests.py',str(wrapper.relative_to(ROOT))]
try:
 r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
 result={'exit_code':r.returncode,'stdout':r.stdout,'stderr':r.stderr}
except subprocess.TimeoutExpired as error:result={'timeout':True,'stdout':str(error.stdout),'stderr':str(error.stderr)}
result.update(schema=1,created_utc=datetime.now(timezone.utc).isoformat(),command=command,seconds=time.monotonic()-start,max_seconds=60,
 scope='Manufactured data with pure production dependency initialization. No original-source execution or player-policy replay.',
 inputs=hashes,inputs_unchanged=all(sha(ROOT/p)==h for p,h in hashes.items()))
(OUT/f'validation_{n:02}.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in result.items()if k!='inputs'}));raise SystemExit(0 if result.get('exit_code')==0 else 1)
