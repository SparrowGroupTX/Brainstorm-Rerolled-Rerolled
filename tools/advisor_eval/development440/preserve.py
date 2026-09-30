from pathlib import Path
import json,sys,shutil
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes,file_digest
from validate_checkpoint import test_manifest
pre=json.loads((EVAL/'development439/prework.json').read_text());base=json.loads((EVAL/'INSTALLED_CHECKPOINT_437.json').read_text())
candidate=json.loads((EVAL/'runs/repair438_candidate1/freeze.json').read_text());assert policy_hashes(ROOT)==candidate['candidate_policy_files'];base['policy_files']=candidate['candidate_policy_files']
prior=pre['prior_files'].copy()
for folder in (EVAL/'development439',):
 for p in folder.rglob('*'):
  if p.is_file():prior[p.relative_to(ROOT).as_posix()]=file_digest(p)
for name in ('EXPERIMENT_CHECKPOINT_439.md','EXPERIMENT_CHECKPOINT_439.json','SESSION_RESET_439.md','SESSION_RESET_439.json','NEXT_PRIORITIES_439.md','ARCHITECTURE_MAP_439.md'):
 prior[(EVAL/name).relative_to(ROOT).as_posix()]=file_digest(EVAL/name)
before={};files=set(base['policy_files'])|set(test_manifest())|set(pre['navigation'])|{'tools/advisor_eval/continuation_adapter.lua','tools/advisor_eval/continuation_evidence.lua'}
for rel in sorted(files):
 dest=HERE/'before'/rel;dest.parent.mkdir(parents=True,exist_ok=True)
 with dest.open('xb')as f:f.write((ROOT/rel).read_bytes())
 before[rel]=file_digest(dest)
with(HERE/'prework.json').open('x',encoding='utf-8')as f:json.dump({'baseline':439,'runtime_files':base['policy_files'],
 'test_files':test_manifest(),'navigation':pre['navigation'],'prior_files':prior,'before_files':before,
 'config_sha256':file_digest(Path(base['installed'])/'config.lua'),'native_files':pre['native_files']},f,indent=2);f.write('\n')
print('Preserved439 baseline and '+str(len(prior))+' prior artifact hashes')
