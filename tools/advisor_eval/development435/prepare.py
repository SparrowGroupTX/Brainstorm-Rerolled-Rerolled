"""Passive extraction and preservation only. Never invokes an advisor."""
from pathlib import Path
import hashlib,json,shutil,sqlite3,subprocess,sys
from datetime import datetime,timezone
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes,file_digest
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def save(p,x):
 p.parent.mkdir(parents=True,exist_ok=True)
 with p.open('x',encoding='utf-8')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
base=read(EVAL/'SESSION_RESET_434.json');installed=Path(base['installed'])
assert policy_hashes(ROOT)==policy_hashes(installed.parent)==base['policy_files']
old=read(EVAL/'development434/prework.json');prior=old['prior_files'].copy()
for folder in [EVAL/'development434',*sorted((EVAL/'runs').glob('repair434_*'))]:
 for p in folder.rglob('*'):
  if p.is_file():prior[p.relative_to(ROOT).as_posix()]=file_digest(p)
for name in ('SESSION_RESET_434.md','SESSION_RESET_434.json','NEXT_PRIORITIES_434.md','ARCHITECTURE_MAP_434.md','TARGETED_EXPERIMENT_PROPOSAL_435.md'):
 prior[(EVAL/name).relative_to(ROOT).as_posix()]=file_digest(EVAL/name)
for rel,h in prior.items():assert file_digest(ROOT/rel)==h,rel
before={};files=set(base['policy_files'])|set(test_manifest())|set(old['navigation'])
for rel in sorted(files):
 dest=HERE/'before'/rel;dest.parent.mkdir(parents=True,exist_ok=True)
 with dest.open('xb')as f:f.write((ROOT/rel).read_bytes())
 before[rel]=file_digest(dest)
save(HERE/'prework.json',{'created_utc':datetime.now(timezone.utc).isoformat(),'runtime_files':base['policy_files'],
 'installed':str(installed),'test_files':test_manifest(),'provenance':provenance(),'prior_files':prior,
 'navigation':old['navigation'],'before_files':before,'config_sha256':file_digest(installed/'config.lua'),
 'native_files':{p.name:file_digest(p)for p in installed.glob('*.dll')}})
with(HERE/'git_status_before.txt').open('x',encoding='utf-8')as f:
 f.write(subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
modules={}
for rel,h in base['policy_files'].items():
 dest=HERE/'frozen/policy'/rel;dest.parent.mkdir(parents=True,exist_ok=True)
 with dest.open('xb')as f:f.write((ROOT/rel).read_bytes())
 assert file_digest(dest)==h
 if rel.startswith('Brainstorm/Advisor/')and rel.endswith('.lua'):modules[Path(rel).stem]=str(dest)
runtime=(ROOT/'Brainstorm/Advisor/runtime.lua').read_text(encoding='utf-8')
wiring=runtime[runtime.index('A.snapshot,'):runtime.index('function A.defaults()')]
excluded=('A.execution =','A.opening =','A.jokerless_opening =','A.retry_memory,','A.retry_generation,','A.acorn_public_hooks=')
wiring='\n'.join(x for x in wiring.splitlines()if not x.startswith(excluded))+'\nA.player_journal=module("player_journal")\n'
with(HERE/'frozen/module_setup.lua').open('x',encoding='utf-8')as f:f.write(wiring)
dll=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll')
with(HERE/'frozen/lua51.dll').open('xb')as f:f.write(dll.read_bytes())
save(HERE/'frozen/runtime.json',{'modules':modules,'excluded_wiring_lines':excluded,'lua_library_source':str(dll),
 'lua_library_sha256':file_digest(dll),'python':sys.executable,'python_sha256':file_digest(Path(sys.executable)),'python_version':sys.version})
source=EVAL/'development434/captures/001/events.sqlite3'
db=sqlite3.connect(source.as_uri()+'?mode=ro',uri=True)
cases={};jobs={};diagnostics=[];pairs=[]
for seq in (10067,10102,13255,18317,27883):
 kind,run,raw=db.execute('SELECT kind,run,data FROM events WHERE seq=?',(seq,)).fetchone()
 assert kind=='teacher_observation';event=json.loads(raw);s=event['context']['snapshot'];key=str(seq)
 cases[key]={'sequence':seq,'run':run,'snapshot':s,'raw_event_sha256':hashlib.sha256(raw.encode()).hexdigest()}
 diag='diag_'+key;diagnostics.append(diag);pack=seq==10067
 jobs[diag]={'case':key,'mode':'pack_diagnostic'if pack else'admission'}
 ids=[c['id']for c in s['playing_cards'if pack else'deck']];assert len(ids)==len(set(ids))
 for w in range(8 if pack else 4):
  label=f'435:{key}:{w}';seed=int(hashlib.sha256(label.encode()).hexdigest()[:8],16)
  order=sorted(ids,key=lambda x:(hashlib.sha256((label+':'+x).encode()).hexdigest(),x))
  roles=['j_sly','j_trio']if pack else['default','five'];pair=[]
  for role in roles[::1 if w%2==0 else -1]:
   job=f'{key}_w{w}_{role}';pair.append(job)
   jobs[job]={'case':key,'mode':'continuation','pack':pack,'world':w,'world_seed':seed,'world_order':order,
    'sorting':'rank'if w%2==0 else'suit','role':role,'action_cap':16,'diagnostic':diag}
  pairs.append(pair)
db.close();assert len(jobs)==53 and len(pairs)==24
save(HERE/'cases.json',cases);save(HERE/'jobs.json',jobs)
save(HERE/'registration.json',{'diagnostics':diagnostics,'pairs':pairs,'max_workers':4,'max_jobs':53,
 'job_seconds':15,'aggregate_reserved_seconds':795,'overall_seconds':900,'source':str(source),
 'source_sha256':file_digest(source),'world_rule':'SHA256(435:case:world:physicalID), lexical ID tie; seed first8 hex SHA256(435:case:world)',
 'diagnostic_admission':'fixed adapter.lua before execution; no replacements; complete family or already-five'})
print(json.dumps({'preserved':len(prior),'before':len(before),'cases':len(cases),'registered':len(jobs),'policy_files':len(base['policy_files'])}))
