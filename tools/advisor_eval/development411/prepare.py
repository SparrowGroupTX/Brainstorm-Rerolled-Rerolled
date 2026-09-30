"""Preserve candidate410 and installed409 before the next coherent repair."""
from pathlib import Path
from datetime import datetime, timezone
import json, shutil, subprocess, sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
prior=EVAL/'runs/repair410_candidate1'
freeze=json.loads((prior/'freeze.json').read_text())
base=json.loads((EVAL/'SESSION_RESET_409.json').read_text());installed=Path(base['installed'])
assert policy_hashes(ROOT)==policy_hashes(prior/'policy')==freeze['candidate_policy_files']
assert test_manifest()==freeze['test_files'] and provenance()==freeze['validation_provenance']
assert policy_hashes(installed.parent)==base['policy_files']
assert {p.name:file_digest(p) for p in installed.glob('*.dll')}==base['native_files_preserved']
nav=['ADVISOR_START_HERE.md','ADVISOR_HANDOFF.md','ADVISOR_RESUME_PROMPT.md']+[
 'tools/advisor_eval/'+n for n in ('WIN_RATE_RESEARCH.md','FRESH_CHAT_HANDOFF_399.md')]
files=set(freeze['candidate_policy_files'])|set(test_manifest())|set(nav)
assert not (HERE/'prework.json').exists()
before={}
for rel in sorted(files):
 p=HERE/'before'/rel;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/rel,p);before[rel]=file_digest(p)
status=subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout
(HERE/'git_status_before.txt').write_text(status,encoding='utf-8')
prior_files=[p for folder in (prior,EVAL/'development410') for p in folder.rglob('*') if p.is_file()]
prior_files += [EVAL/n for n in ('CANDIDATE_CHECKPOINT_410.md','NEXT_PRIORITIES_410.md','ARCHITECTURE_MAP_410.md')]
report={'created_utc':datetime.now(timezone.utc).isoformat(),'baseline_candidate':410,'installed_checkpoint':409,
 'runtime_files':freeze['candidate_policy_files'],'installed_runtime_files':base['policy_files'],
 'test_files':test_manifest(),'provenance':provenance(),'before_files':before,'navigation':nav,
 'config_sha256':file_digest(installed/'config.lua'),'native_files':base['native_files_preserved'],
 'prior410_files':{p.relative_to(ROOT).as_posix():file_digest(p) for p in prior_files},
 'active_journals_read':False}
(HERE/'prework.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'backed_files':len(before),'prior410_files':len(prior_files),'runtime':len(report['runtime_files']),'tests':len(report['test_files'])}))
