"""Preserve exact430 and closed429 before the conditional held-score repair."""
from pathlib import Path
from datetime import datetime,timezone
import json,shutil,subprocess,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes,file_digest
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(Path(p).read_text(encoding='utf-8'))
assert read(EVAL/'development429/CLOSED.json')['remaining_authority']==0
assert (EVAL/'development429/FINAL_VERIFICATION.json').exists()
f=read(EVAL/'runs/repair430_candidate1/freeze.json');base=read(EVAL/'SESSION_RESET_426.json')
assert policy_hashes(ROOT)==f['candidate_policy_files']
assert test_manifest()==f['test_files'] and provenance()==f['validation_provenance']
installed=Path(base['installed']);assert policy_hashes(installed.parent)==base['policy_files']
nav=['ADVISOR_START_HERE.md','ADVISOR_HANDOFF.md','ADVISOR_RESUME_PROMPT.md',
     'tools/advisor_eval/README.md','tools/advisor_eval/FRESH_CHAT_HANDOFF_399.md','tools/advisor_eval/INSTALLATION_POLICY.md']
assert not (HERE/'prework.json').exists()
files=set(f['candidate_policy_files'])|set(f['test_files'])|set(nav);before={}
for rel in sorted(files):
    target=HERE/'before'/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/rel,target);before[rel]=file_digest(target)
prior={}
for folder in ('development430','runs/repair430_candidate1'):
    for p in (EVAL/folder).rglob('*'):
        if p.is_file():prior[p.relative_to(ROOT).as_posix()]=file_digest(p)
prior.update(read(EVAL/'development430/prework.json')['prior_files'])
report={'created_utc':datetime.now(timezone.utc).isoformat(),'baseline_candidate':430,'installed_checkpoint':426,
        'runtime_files':f['candidate_policy_files'],'test_files':f['test_files'],'provenance':provenance(),
        'installed_runtime_files':base['policy_files'],'config_sha256':file_digest(installed/'config.lua'),
        'native_files':base['native_files_preserved'],'before_files':before,'prior_files':prior,'navigation':nav}
with (HERE/'prework.json').open('x',encoding='utf-8')as out:json.dump(report,out,indent=2);out.write('\n')
(HERE/'git_status_before.txt').write_text(subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout,encoding='utf-8')
print(json.dumps({'preserved_before':len(before),'prior_files':len(prior),'baseline':430,'installed':426}))
