from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,subprocess,sys,time
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert not(OUT/'related_validation.json').exists()
names=['advisor_gold_tarot_hold','advisor_gold_tarot_hold_pin','advisor_gold_tarot_hold_scope','advisor_gold_tarot_rows',
 'advisor_gold_acquisition_runtime','advisor_gold_cartomancer','advisor_gold_retention_runtime','advisor_perkeo_inventory','advisor_gold_planet_policy']
wrappers=[]
for name in names:
 p=OUT/f'related_{name}.lua';wrappers.append(p)
 with p.open('x',encoding='utf-8')as f:
  f.write('local old,open=dofile,io.open\nlocal map={\n')
  for module in ['gold_tarot_hold','perkeo_inventory']:
   f.write(f"['Brainstorm/Advisor/{module}.lua']='tools/advisor_eval/development346/constructor_component/Brainstorm/Advisor/{module}.lua',\n")
  f.write("}\ndofile=function(p)return old(map[p]or p)end\nio.open=function(p,...)return open(map[p]or p,...)end\n")
  f.write(f"dofile('tests/{name}.lua')\n")
files=[*sorted((ROOT/'Brainstorm/Advisor').glob('*.lua')),*sorted((OUT/'Brainstorm/Advisor').glob('*.lua')),
 *[ROOT/f'tests/{name}.lua'for name in names],ROOT/'tests/fixtures/gold_tarot_hold_support.lua',*wrappers]
inputs={str(p.relative_to(ROOT)):sha(p)for p in files}
command=[sys.executable,'tests/run_lua_tests.py',*[str(p.relative_to(ROOT))for p in wrappers]];start=time.monotonic()
r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
record={'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),'scope':'Existing manufactured fixtures against staged constructors; no source or captured player execution.',
 'command':command,'max_seconds':60,'seconds':time.monotonic()-start,'exit_code':r.returncode,'stdout':r.stdout,'stderr':r.stderr,
 'inputs':inputs,'inputs_unchanged':all(sha(ROOT/p)==v for p,v in inputs.items())}
(OUT/'related_validation.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in record.items()if k!='inputs'}));assert r.returncode==0 and record['inputs_unchanged']
