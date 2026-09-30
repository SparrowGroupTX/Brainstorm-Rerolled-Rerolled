"""Preserve exact424 candidate and installed424 before425 edits before runtime edits."""
from pathlib import Path
from datetime import datetime, timezone
import json, shutil, subprocess, sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
prior=EVAL/'runs/repair424_candidate1'
freeze=json.loads((prior/'freeze.json').read_text())
base=json.loads((EVAL/'SESSION_RESET_424.json').read_text());installed=Path(base['installed'])
assert policy_hashes(ROOT)==policy_hashes(prior/'policy')==freeze['candidate_policy_files']
assert test_manifest()==freeze['test_files'] and provenance()==freeze['validation_provenance']
assert policy_hashes(installed.parent)==base['policy_files']
assert {p.name:file_digest(p) for p in installed.glob('*.dll')}==base['native_files_preserved']
nav=['ADVISOR_START_HERE.md','ADVISOR_HANDOFF.md','ADVISOR_RESUME_PROMPT.md']+[
 'tools/advisor_eval/'+n for n in ('WIN_RATE_RESEARCH.md','FRESH_CHAT_HANDOFF_399.md','INSTALLATION_POLICY.md')]
files=set(freeze['candidate_policy_files'])|set(test_manifest())|set(nav)
assert not (HERE/'prework.json').exists()
before={}
for rel in sorted(files):
 p=HERE/'before'/rel;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/rel,p);before[rel]=file_digest(p)
status=subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout
(HERE/'git_status_before.txt').write_text(status,encoding='utf-8')
folders=(EVAL/'development424',EVAL/'runs/repair424_installed',prior,EVAL/'runs/repair421_installed',EVAL/'development421',EVAL/'development422',EVAL/'development423',EVAL/'runs/repair423_candidate1',EVAL/'release_policy20260927')
prior_files=[p for folder in folders for p in folder.rglob('*') if p.is_file()]
prior_files += [EVAL/n for n in ('SESSION_RESET_421.md','SESSION_RESET_424.json','NEXT_PRIORITIES_421.md','ARCHITECTURE_MAP_421.md','CANDIDATE_CHECKPOINT_421.md','CANDIDATE_CHECKPOINT_421.json','SESSION_RESET_424.md','SESSION_RESET_424.json','CANDIDATE_CHECKPOINT_424.md','CANDIDATE_CHECKPOINT_424.json','NEXT_PRIORITIES_424.md','ARCHITECTURE_MAP_424.md','CANDIDATE_CHECKPOINT_423.md','CANDIDATE_CHECKPOINT_423.json','NEXT_PRIORITIES_423.md','ARCHITECTURE_MAP_423.md')]
report={'created_utc':datetime.now(timezone.utc).isoformat(),'baseline_candidate':424,'installed_checkpoint':424,
 'runtime_files':freeze['candidate_policy_files'],'installed_runtime_files':base['policy_files'],
 'test_files':test_manifest(),'provenance':provenance(),'before_files':before,'navigation':nav,
 'config_sha256':file_digest(installed/'config.lua'),'native_files':base['native_files_preserved'],
 'prior_files':{p.relative_to(ROOT).as_posix():file_digest(p) for p in prior_files},
 'active_journals_read':False}
(HERE/'prework.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'backed_files':len(before),'prior_files':len(prior_files),'runtime':len(report['runtime_files']),'tests':len(report['test_files'])}))
