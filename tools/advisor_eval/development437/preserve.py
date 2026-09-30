from pathlib import Path
import json,sys,shutil
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes,file_digest
from validate_checkpoint import test_manifest
pre=json.loads((EVAL/'development436/prework.json').read_text());base=json.loads((EVAL/'CANDIDATE_CHECKPOINT_436.json').read_text())
assert policy_hashes(ROOT)==base['policy_files']
prior=pre['prior_files'].copy()
for folder in (EVAL/'development436',EVAL/'runs/repair436_candidate1',EVAL/'runs/repair436_candidate2'):
 for p in folder.rglob('*'):
  if p.is_file():prior[p.relative_to(ROOT).as_posix()]=file_digest(p)
for name in ('CANDIDATE_CHECKPOINT_436.md','CANDIDATE_CHECKPOINT_436.json','NEXT_PRIORITIES_436.md','ARCHITECTURE_MAP_436.md'):
 prior[(EVAL/name).relative_to(ROOT).as_posix()]=file_digest(EVAL/name)
before={};files=set(base['policy_files'])|set(test_manifest())|set(pre['navigation'])|set(base['evaluation_helpers'])
for rel in sorted(files):
 dest=HERE/'before'/rel;dest.parent.mkdir(parents=True,exist_ok=True)
 with dest.open('xb')as f:f.write((ROOT/rel).read_bytes())
 before[rel]=file_digest(dest)
with(HERE/'prework.json').open('x',encoding='utf-8')as f:json.dump({'baseline':436,'runtime_files':base['policy_files'],
 'test_files':test_manifest(),'navigation':pre['navigation'],'prior_files':prior,'before_files':before,
 'config_sha256':pre['config_sha256'],'native_files':pre['native_files']},f,indent=2);f.write('\n')
print('Preserved436 baseline and '+str(len(prior))+' prior artifact hashes')
