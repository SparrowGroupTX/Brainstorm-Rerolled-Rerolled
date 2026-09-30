"""Manufactured fixtures only. Does not run captured states or gameplay."""
from pathlib import Path
import hashlib,json,subprocess,sys,time
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
out=HERE/'root_component'/'validation_final.json'
if out.exists():raise RuntimeError('Preserve prior evidence; use a new explicit receipt')
names=['gold_tarot_hold_pin','gold_tarot_hold_scope','gold_tarot_rows','gold_retention','gold_cartomancer',
 'gold_journal','gold_acquisition_budget','gold_acquisition_runtime','gold_acquisition',
 'gold_retention_budget','gold_retention_runtime']
command=[sys.executable,'tests/run_lua_tests.py']+['tests/advisor_'+n+'.lua' for n in names]
start=time.monotonic()
result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
log=HERE/'root_component'/'validation_final.log';log.write_text(result.stdout+'\n'+result.stderr,encoding='utf-8')
receipt={'scope':'Manufactured fixture regression only; no captured/source/search/complete worker',
 'command':command,'exit_code':result.returncode,'seconds':time.monotonic()-start,'cap_seconds':60,
 'log':str(log.relative_to(ROOT)),'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),
 'files':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in command[2:]}}
out.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(result.stdout);print(result.stderr);sys.exit(result.returncode)
