"""Freeze the newly authorized ten cases; still no captured evaluation."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,shutil,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes,file_digest
from validate_checkpoint import test_manifest
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def save(p,x):
 with p.open('x',encoding='utf-8')as f:json.dump(x,f,indent=2);f.write('\n')
candidate=EVAL/'runs/repair437_candidate2';gate=read(candidate/'validation/report.json');freeze=read(candidate/'freeze.json')
assert gate['passed']and policy_hashes(ROOT)==gate['policy_files']and test_manifest()==gate['test_files']
assert not(HERE/'manifest.json').exists()and not(HERE/'EXECUTION_STARTED.json').exists()
frozen=HERE/'frozen';frozen.mkdir(exist_ok=False);modules={}
for path in (candidate/'policy/Brainstorm/Advisor').glob('*.lua'):
 dest=frozen/path.name;shutil.copy2(path,dest);modules[path.stem]=str(dest)
for name in ('continuation_adapter.lua','continuation_evidence.lua'):
 assert file_digest(EVAL/name)==freeze['evaluation_helpers']['tools/advisor_eval/'+name];shutil.copy2(EVAL/name,frozen/name)
runtime=(ROOT/'Brainstorm/Advisor/runtime.lua').read_text(encoding='utf-8')
wiring=runtime[runtime.index('A.snapshot,'):runtime.index('function A.defaults()')]
excluded=('A.execution =','A.opening =','A.jokerless_opening =','A.retry_memory,','A.retry_generation,','A.acorn_public_hooks=')
wiring='\n'.join(x for x in wiring.splitlines()if not x.startswith(excluded))+'\nA.player_journal=module("player_journal")\n'
(frozen/'module_setup.lua').write_text(wiring,encoding='utf-8')
dll=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll');shutil.copy2(dll,frozen/'lua51.dll')
save(HERE/'registration.json',{'created_utc':datetime.now(timezone.utc).isoformat(),'max_jobs':10,'max_workers':4,'job_seconds':40,
 'reserved_seconds':400,'overall_seconds':600,'action_cap':16,'retries':0,'round_rewards_modeled':False,
 'case_selection':'CASE_SELECTION.json','world_rule':'SHA256(437:case:world0:physicalID), lexical-ID tie; fixed rank sorting',
 'benchmark':'4 times initial available discards; all ten outcomes/censored prefixes retained',
 'authorization':'User expressly requested ten targeted round continuations after discard repair; prior435 remains closed'})
runtime_info={'modules':modules,'policy_digest':gate['policy_digest'],'candidate_validation_sha256':file_digest(candidate/'validation/report.json'),
 'source_files':{str(p.resolve()):file_digest(p)for p in (EVAL/'development434/captures/001/events.sqlite3',candidate/'freeze.json',candidate/'validation/report.json')},
 'lua_library_source':str(dll),'lua_library_sha256':file_digest(dll),'python_version':sys.version,'python_sha256':file_digest(Path(sys.executable)),
 'files':{p.relative_to(HERE).as_posix():file_digest(p)for p in sorted(frozen.rglob('*'))if p.is_file()}}
save(HERE/'QUALIFICATION_INPUTS.json',runtime_info)
print(json.dumps({'policy':gate['policy_digest'],'modules':len(modules),'qualified_inputs_frozen':True,'captured_evaluations':0}))
