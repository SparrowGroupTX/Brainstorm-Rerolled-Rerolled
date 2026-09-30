from pathlib import Path
import json,sys,shutil
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes,file_digest
from validate_checkpoint import test_manifest
pre=json.loads((EVAL/'development438/prework.json').read_text());base=json.loads((EVAL/'INSTALLED_CHECKPOINT_437.json').read_text())
candidate=json.loads((EVAL/'runs/repair438_candidate1/freeze.json').read_text());assert policy_hashes(ROOT)==candidate['candidate_policy_files'];base['policy_files']=candidate['candidate_policy_files']
prior=pre['prior_files'].copy()
for folder in (EVAL/'development438',EVAL/'runs/repair438_candidate1'):
 for p in folder.rglob('*'):
  if p.is_file():prior[p.relative_to(ROOT).as_posix()]=file_digest(p)
for name in ('CANDIDATE_CHECKPOINT_438.md','CANDIDATE_CHECKPOINT_438.json','SESSION_RESET_438.md','SESSION_RESET_438.json','NEXT_PRIORITIES_438.md','ARCHITECTURE_MAP_438.md'):
 prior[(EVAL/name).relative_to(ROOT).as_posix()]=file_digest(EVAL/name)
before={};files=set(base['policy_files'])|set(test_manifest())|set(pre['navigation'])|{'tools/advisor_eval/continuation_adapter.lua','tools/advisor_eval/continuation_evidence.lua'}
for rel in sorted(files):
 dest=HERE/'before'/rel;dest.parent.mkdir(parents=True,exist_ok=True)
 with dest.open('xb')as f:f.write((ROOT/rel).read_bytes())
 before[rel]=file_digest(dest)
with(HERE/'prework.json').open('x',encoding='utf-8')as f:json.dump({'baseline':438,'runtime_files':base['policy_files'],
 'test_files':test_manifest(),'navigation':pre['navigation'],'prior_files':prior,'before_files':before,
 'config_sha256':file_digest(Path(base['installed'])/'config.lua'),'native_files':pre['native_files']},f,indent=2);f.write('\n')
print('Preserved438 baseline and '+str(len(prior))+' prior artifact hashes')
