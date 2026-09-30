"""Preserve exact installed433 and its evidence before the new authorized audit."""
from pathlib import Path
from datetime import datetime,timezone
import json,subprocess,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes,file_digest
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text(encoding='utf-8'))
base=read(EVAL/'SESSION_RESET_433.json');installed=Path(base['installed'])
assert policy_hashes(ROOT)==policy_hashes(installed.parent)==base['policy_files']
assert read(EVAL/'development429/CLOSED.json')['remaining_authority']==0
old=read(EVAL/'development433/prework.json');prior=old['prior_files'].copy()
for folder in [EVAL/'development433',*sorted((EVAL/'runs').glob('repair433_*'))]:
 for p in folder.rglob('*'):
  if p.is_file():prior[p.relative_to(ROOT).as_posix()]=file_digest(p)
for name in ('SESSION_RESET_433.md','SESSION_RESET_433.json','NEXT_PRIORITIES_433.md','ARCHITECTURE_MAP_433.md'):
 prior[(EVAL/name).relative_to(ROOT).as_posix()]=file_digest(EVAL/name)
for rel,h in old['prior_files'].items():assert file_digest(ROOT/rel)==h,rel
before={};nav=old['navigation'];files=set(base['policy_files'])|set(test_manifest())|set(nav)
for rel in sorted(files):
 dest=HERE/'before'/rel;dest.parent.mkdir(parents=True,exist_ok=True)
 with dest.open('xb')as f:f.write((ROOT/rel).read_bytes())
 before[rel]=file_digest(dest)
record={'created_utc':datetime.now(timezone.utc).isoformat(),'installed_checkpoint':433,
 'runtime_files':base['policy_files'],'installed_runtime_files':base['policy_files'],
 'test_files':test_manifest(),'provenance':provenance(),'prior_files':prior,'navigation':nav,'before_files':before,
 'config_sha256':file_digest(installed/'config.lua'),'native_files':{p.name:file_digest(p)for p in installed.glob('*.dll')}}
assert record['config_sha256']==base['config_sha256']and record['native_files']==base['native_files_preserved']
with(HERE/'prework.json').open('x',encoding='utf-8')as f:json.dump(record,f,indent=2);f.write('\n')
(HERE/'git_status_before.txt').write_text(subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout,encoding='utf-8')
print(json.dumps({'baseline':433,'prior_files':len(prior),'before_files':len(before)}))
