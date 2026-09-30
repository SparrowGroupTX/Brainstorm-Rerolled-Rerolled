"""Bind passive audit inputs, installed bytes and preservation evidence."""
from pathlib import Path
from datetime import datetime,timezone
import json,sys,subprocess
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes,file_digest
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(Path(p).read_text(encoding='utf-8'))
baseline=read(EVAL/'SESSION_RESET_431.json');installed=Path(baseline['installed'])
assert policy_hashes(ROOT)==policy_hashes(installed.parent)==baseline['policy_files']
prior=read(EVAL/'development431/prework.json')['prior_files']
for folder in ('development431','runs/repair431_candidate1','runs/repair431_installed'):
 for p in (EVAL/folder).rglob('*'):
  if p.is_file():prior[p.relative_to(ROOT).as_posix()]=file_digest(p)
for name in ('SESSION_RESET_431.md','SESSION_RESET_431.json','CANDIDATE_CHECKPOINT_431.md','CANDIDATE_CHECKPOINT_431.json','NEXT_PRIORITIES_431.md','ARCHITECTURE_MAP_431.md'):
 prior[(EVAL/name).relative_to(ROOT).as_posix()]=file_digest(EVAL/name)
nav=read(EVAL/'development431/prework.json')['navigation'];before={}
for rel in nav:
 target=HERE/'navigation_before'/rel;target.parent.mkdir(parents=True,exist_ok=True)
 with target.open('xb')as f:f.write((ROOT/rel).read_bytes())
 before[rel]=file_digest(target)
capture=EVAL/'development430/captures/002';m=read(capture/'manifest.json');s=read(capture/'summary.json')
for x in m['segments']:assert file_digest(capture/'logs'/x['name'])==x['sha256']
assert file_digest(capture/'events.sqlite3')==s['database_sha256']
record={'created_utc':datetime.now(timezone.utc).isoformat(),'installed_revision':431,
 'policy_files':baseline['policy_files'],'test_files':test_manifest(),'provenance':provenance(),
 'prior_files':prior,'navigation':nav,'before_files':before,'capture':capture.relative_to(ROOT).as_posix(),
 'manifest_sha256':file_digest(capture/'manifest.json'),'summary_sha256':file_digest(capture/'summary.json'),
 'database_sha256':s['database_sha256'],'analysis_kind':'passive_only_no_policy_or_scorer_execution'}
with (HERE/'prework.json').open('x',encoding='utf-8')as f:json.dump(record,f,indent=2);f.write('\n')
(HERE/'git_status_before.txt').write_text(subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout,encoding='utf-8')
print(json.dumps({'preserved_hashes':len(prior),'capture':record['capture'],'installed':431}))
