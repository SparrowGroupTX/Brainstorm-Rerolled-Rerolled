"""Preserve the delivered431 and passive432 audit before combined repairs."""
from pathlib import Path
from datetime import datetime, timezone
import json, shutil, subprocess, sys
HERE=Path(__file__).resolve().parent; EVAL=HERE.parent; ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes,file_digest
from validate_checkpoint import test_manifest,provenance
def read(p): return json.loads(Path(p).read_text(encoding='utf-8'))
base=read(EVAL/'SESSION_RESET_431.json'); installed=Path(base['installed'])
assert policy_hashes(ROOT)==policy_hashes(installed.parent)==base['policy_files']
assert read(EVAL/'development429/CLOSED.json')['remaining_authority']==0
prior=read(EVAL/'development432/prework.json')['prior_files']
for folder in ('development432',):
 for p in (EVAL/folder).rglob('*'):
  if p.is_file(): prior[p.relative_to(ROOT).as_posix()]=file_digest(p)
for name in ('NEXT_PRIORITIES_432.md','ARCHITECTURE_MAP_432.md'):
 prior[(EVAL/name).relative_to(ROOT).as_posix()]=file_digest(EVAL/name)
nav=read(EVAL/'development432/prework.json')['navigation']; before={}
files=set(base['policy_files'])|set(test_manifest())|set(nav)
for rel in sorted(files):
 target=HERE/'before'/rel; target.parent.mkdir(parents=True,exist_ok=True)
 with target.open('xb') as f: f.write((ROOT/rel).read_bytes())
 before[rel]=file_digest(target)
record={'created_utc':datetime.now(timezone.utc).isoformat(),'installed_checkpoint':431,
 'runtime_files':base['policy_files'],'installed_runtime_files':base['policy_files'],
 'test_files':test_manifest(),'provenance':provenance(),'prior_files':prior,
 'navigation':nav,'before_files':before,'config_sha256':file_digest(installed/'config.lua'),
 'native_files':{p.name:file_digest(p) for p in installed.glob('*.dll')}}
with (HERE/'prework.json').open('x',encoding='utf-8') as f: json.dump(record,f,indent=2);f.write('\n')
(HERE/'git_status_before.txt').write_text(subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout,encoding='utf-8')
print(json.dumps({'preserved_before':len(before),'prior_files':len(prior),'baseline':431}))
