"""Preserve435 evidence and exact installed434 before the authorized repair."""
from pathlib import Path
from datetime import datetime,timezone
import json,subprocess,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes,file_digest
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text(encoding='utf-8'))
base=read(EVAL/'SESSION_RESET_434.json');installed=Path(base['installed'])
assert policy_hashes(ROOT)==policy_hashes(installed.parent)==base['policy_files']
assert read(EVAL/'development435/CLOSED.json')['remaining_authority']==0
old=read(EVAL/'development435/prework.json');prior=old['prior_files'].copy()
for p in (EVAL/'development435').rglob('*'):
 if p.is_file():prior[p.relative_to(ROOT).as_posix()]=file_digest(p)
for name in ('SESSION_RESET_435.md','SESSION_RESET_435.json','NEXT_PRIORITIES_435.md','ARCHITECTURE_MAP_435.md'):
 prior[(EVAL/name).relative_to(ROOT).as_posix()]=file_digest(EVAL/name)
for rel,h in old['prior_files'].items():assert file_digest(ROOT/rel)==h,rel
before={};nav=old['navigation'];files=set(base['policy_files'])|set(test_manifest())|set(nav)
for rel in sorted(files):
 dest=HERE/'before'/rel;dest.parent.mkdir(parents=True,exist_ok=True)
 with dest.open('xb')as f:f.write((ROOT/rel).read_bytes())
 before[rel]=file_digest(dest)
record={'created_utc':datetime.now(timezone.utc).isoformat(),'installed_checkpoint':434,'installed':str(installed),
 'runtime_files':base['policy_files'],'test_files':test_manifest(),'provenance':provenance(),'prior_files':prior,
 'navigation':nav,'before_files':before,'config_sha256':file_digest(installed/'config.lua'),
 'native_files':{p.name:file_digest(p)for p in installed.glob('*.dll')}}
with(HERE/'prework.json').open('x',encoding='utf-8')as f:json.dump(record,f,indent=2);f.write('\n')
with(HERE/'git_status_before.txt').open('x',encoding='utf-8')as f:
 f.write(subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
print(json.dumps({'baseline':434,'prior':len(prior),'before':len(before)}))
