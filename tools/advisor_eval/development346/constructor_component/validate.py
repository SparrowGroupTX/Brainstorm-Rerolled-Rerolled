from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,subprocess,sys,time
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
n=1
while (OUT/f'validation_{n:02}.json').exists():n+=1
record={'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
 'scope':'Manufactured constructor/copy/whole-inventory fixtures only. No source execution, player-policy replay, search, saves or game control.',
 'runs':[]}
for phase in ['before_tarot','before_planet','after']:
 wrapper=OUT/f'run_{n:02}_{phase}.lua'
 h=('before/' if phase=='before_tarot' else '')+'Brainstorm/Advisor/gold_tarot_hold.lua'
 p=('before/' if phase!='after' else '')+'Brainstorm/Advisor/perkeo_inventory.lua'
 with wrapper.open('x',encoding='utf-8')as f:
  f.write('local old=dofile\nlocal map={\n')
  f.write(f"['Brainstorm/Advisor/gold_tarot_hold.lua']={(OUT/h).relative_to(ROOT).as_posix()!r},\n")
  f.write(f"['Brainstorm/Advisor/perkeo_inventory.lua']={(OUT/p).relative_to(ROOT).as_posix()!r}\n}}\n")
  f.write("dofile=function(p)return old(map[p]or p)end\ndofile('tools/advisor_eval/development346/constructor_component/tests/advisor_consumable_constructor_params.lua')\n")
 files=[OUT/h,OUT/p,ROOT/'Brainstorm/Advisor/snapshot.lua',OUT/'tests/advisor_consumable_constructor_params.lua',wrapper]
 inputs={str(x.relative_to(ROOT)):sha(x)for x in files}
 command=[sys.executable,'tests/run_lua_tests.py',str(wrapper.relative_to(ROOT))];start=time.monotonic()
 try:
  r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
  row={'exit_code':r.returncode,'stdout':r.stdout,'stderr':r.stderr}
 except subprocess.TimeoutExpired as e:row={'timeout':True,'stdout':str(e.stdout),'stderr':str(e.stderr)}
 row.update(phase=phase,command=command,max_seconds=60,seconds=time.monotonic()-start,inputs=inputs,
  inputs_unchanged=all(sha(ROOT/x)==v for x,v in inputs.items()))
 record['runs'].append(row);print(json.dumps({k:v for k,v in row.items()if k!='inputs'}))
record['passed']=all(r['inputs_unchanged']and r.get('exit_code')==(0 if r['phase']=='after' else 1)for r in record['runs'])
(OUT/f'validation_{n:02}.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
raise SystemExit(0 if record['passed']else 1)
