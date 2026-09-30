from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, subprocess, sys, time
OUT=Path(__file__).resolve().parent; ROOT=OUT.parents[3]
fixture=OUT/'tests/advisor_gold_retention_order_runtime.lua'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
inputs=sorted((ROOT/'Brainstorm/Advisor').glob('*.lua'))+[ROOT/'tests/fixtures/gold_tarot_hold_support.lua',fixture,Path(__file__).resolve()]
hashes={str(p.relative_to(ROOT)):sha(p) for p in inputs}
n=1
while (OUT/f'runtime_{n:02}.json').exists(): n+=1
command=[sys.executable,'tests/run_lua_tests.py',str(fixture.relative_to(ROOT))]
start=time.monotonic()
try:
 r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
 result={'exit_code':r.returncode,'stdout':r.stdout,'stderr':r.stderr}
except subprocess.TimeoutExpired as e: result={'timeout':True,'stdout':str(e.stdout),'stderr':str(e.stderr)}
result.update(schema=1,created_utc=datetime.now(timezone.utc).isoformat(),command=command,seconds=time.monotonic()-start,max_seconds=60,
 scope='Manufactured public states through actual original runtime Decision/Shop/scoring/phase-copy/retry wiring; ordinary incumbent family focused by fixture only. No captured policy evaluation, original-source execution or terminal experiment.',
 inputs=hashes,inputs_unchanged=all(sha(ROOT/p)==h for p,h in hashes.items()))
(OUT/f'runtime_{n:02}.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in result.items()if k!='inputs'}))
raise SystemExit(0 if result.get('exit_code')==0 else 1)
