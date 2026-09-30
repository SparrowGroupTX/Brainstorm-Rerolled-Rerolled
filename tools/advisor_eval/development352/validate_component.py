"""Bounded manufactured fixtures. No player replay or source execution."""
from pathlib import Path
import hashlib,json,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
label=sys.argv[1];fixtures=sys.argv[2:]
assert label.replace('_','').isalnum() and fixtures
output=HERE/'root_component'/label
output.mkdir(parents=True,exist_ok=False)
command=[sys.executable,'tests/run_lua_tests.py']+fixtures
paths=fixtures+['tests/fixtures/gold_tarot_hold_support.lua','Brainstorm/Core/auto_run_product.lua']+[p.relative_to(ROOT).as_posix() for p in (ROOT/'Brainstorm/Advisor').glob('*.lua')]
files={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}
start=time.monotonic()
try:
 r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
 status='passed' if r.returncode==0 else 'failed';code=r.returncode;log=r.stdout+'\n'+r.stderr
except subprocess.TimeoutExpired as e:status='timeout';code=None;log=str(e.stdout)+'\n'+str(e.stderr)
elapsed=time.monotonic()-start
(output/'output.log').write_text(log,encoding='utf-8')
(output/'report.json').write_text(json.dumps({'scope':'Manufactured fixture validation only; no captured/source/search/complete jobs',
 'command':command,'status':status,'exit_code':code,'seconds':elapsed,'cap_seconds':60,'input_hashes':files,
 'inputs_unchanged':all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in files.items()),
 'log_sha256':hashlib.sha256((output/'output.log').read_bytes()).hexdigest()},indent=2)+'\n',encoding='utf-8')
print(log);sys.exit(0 if status=='passed' else 1)
