"""Freeze this newly authorized twenty-round scope without captured execution."""
from pathlib import Path
from datetime import datetime,timezone
import json,shutil,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes,file_digest
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def save(p,x):
 with p.open('x',encoding='utf-8')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
candidate=EVAL/'runs/repair438_candidate1';gate=read(candidate/'validation/report.json');freeze=read(candidate/'freeze.json')
assert gate['passed']and policy_hashes(ROOT)==policy_hashes(candidate/'policy')==gate['policy_files']
assert test_manifest()==gate['test_files']and provenance()==gate['validation_provenance']
assert not(HERE/'manifest.json').exists()and not(HERE/'EXECUTION_STARTED.json').exists()
selection=read(HERE/'CASE_SELECTION.json');source=Path(selection['source'])
assert file_digest(source)==selection['source_sha256']
cases=read(HERE/'cases.json');jobs=read(HERE/'jobs.json');assert set(cases)==set(jobs)and len(jobs)==20
assert all(0<=j['world_seed']<1000000000 and j['action_cap']==16 and j['policy_first']is True for j in jobs.values())
frozen=HERE/'frozen';frozen.mkdir(exist_ok=False);modules={}
for path in (candidate/'policy/Brainstorm/Advisor').glob('*.lua'):
 dest=frozen/path.name;shutil.copy2(path,dest);modules[path.stem]=str(dest)
for name in ('continuation_adapter.lua','continuation_evidence.lua'):
 rel='tools/advisor_eval/'+name
 assert file_digest(EVAL/name)==file_digest(candidate/'helpers'/rel)==freeze['evaluation_helpers'][rel]
 shutil.copy2(candidate/'helpers'/rel,frozen/name)
runtime=(candidate/'policy/Brainstorm/Advisor/runtime.lua').read_text(encoding='utf-8')
wiring=runtime[runtime.index('A.snapshot,'):runtime.index('function A.defaults()')]
excluded=('A.execution =','A.opening =','A.jokerless_opening =','A.retry_memory,','A.retry_generation,','A.acorn_public_hooks=')
wiring='\n'.join(x for x in wiring.splitlines()if not x.startswith(excluded))+'\nA.player_journal=module("player_journal")\n'
(frozen/'module_setup.lua').write_text(wiring,encoding='utf-8')
dll=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll');shutil.copy2(dll,frozen/'lua51.dll')
save(HERE/'registration.json',{'created_utc':datetime.now(timezone.utc).isoformat(),'max_jobs':20,'max_workers':4,
 'job_seconds':40,'reserved_seconds':800,'overall_seconds':600,'action_cap':16,'retries':0,
 'round_rewards_modeled':False,'case_selection':'CASE_SELECTION.json',
 'world_rule':'Label439:case:world0. Seed=uint32(first8 hex SHA256(label)) modulo1,000,000,000. Deck order=SHA256(label:physicalID), lexical-ID tie; rank sorting. Separate deterministic Bell/Acorn/Glass/Lucky/Heart channels.',
 'benchmark':'4 times initial available discards; completed failures included; all20 outcomes and censored prefixes retained',
 'authorization':'User: run20 more simulated rounds and count average discards; counterfactuals from current in-progress10-run session.',
 'pre_registration_correction':'Restrict SHA-derived seeds to the already-qualified adapter integer range; preliminary_seed1 preserves earlier unexecuted mapping.'})
info={'modules':modules,'policy_digest':gate['policy_digest'],'candidate_validation_sha256':file_digest(candidate/'validation/report.json'),
 'source_files':{str(p.resolve()):file_digest(p)for p in (source,candidate/'freeze.json',candidate/'validation/report.json')},
 'lua_library_source':str(dll),'lua_library_sha256':file_digest(dll),'python_version':sys.version,
 'python_sha256':file_digest(Path(sys.executable)),
 'files':{p.relative_to(HERE).as_posix():file_digest(p)for p in sorted(frozen.rglob('*'))if p.is_file()}}
save(HERE/'QUALIFICATION_INPUTS.json',info)
print(json.dumps({'policy':info['policy_digest'],'modules':len(modules),'jobs':20,'captured_evaluations':0}))
