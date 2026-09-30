"""Archive navigation and record a documentation-only preservation baseline."""
from pathlib import Path
from datetime import datetime,timezone
import json,sys,shutil,subprocess
H=Path(__file__).resolve().parent;E=H.parent;R=E.parents[1];sys.path.insert(0,str(E))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text())
B=read(E/'INSTALLED_CHECKPOINT_451.json');F=read(E/'runs/repair451_candidate1/freeze.json')
assert policy_hashes(R)==F['candidate_policy_files']==B['policy_files']
assert policy_hashes(Path(B['installed']).parent)==B['policy_files']
assert test_manifest()==F['test_files']and provenance()==F['validation_provenance']
nav=['ADVISOR_START_HERE.md','ADVISOR_HANDOFF.md','ADVISOR_RESUME_PROMPT.md',
 'tools/advisor_eval/README.md','tools/advisor_eval/FRESH_CHAT_HANDOFF_399.md']
before={rel:file_digest(R/rel)for rel in nav}
for rel,h in before.items():
    dest=H/'before'/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(R/rel,dest)
    assert file_digest(dest)==h
prior=read(E/'development451/prework.json')['prior_files']
for directory in('development451','runs/repair451_candidate1','runs/repair451_installed'):
    prior.update({p.relative_to(R).as_posix():file_digest(p)for p in(E/directory).rglob('*')if p.is_file()and'__pycache__'not in p.parts})
prior.update({p.relative_to(R).as_posix():file_digest(p)for p in E.glob('*451*')if p.is_file()})
for rel,h in prior.items():assert file_digest(R/rel)==h,rel
status=subprocess.run(['git','status','--porcelain=v1','--branch'],cwd=R,capture_output=True,text=True,check=True).stdout
(H/'git_status_before.txt').write_text(status,encoding='utf-8')
data={'created_utc':datetime.now(timezone.utc).isoformat(),'installed':B,'freeze':F,'navigation_before':before,
 'prior_files':prior,'provenance':provenance(),'test_files':test_manifest(),'policy_files':policy_hashes(R),
 'installation_policy_sha256':file_digest(E/'INSTALLATION_POLICY.md'),
 'config_sha256':file_digest(Path(B['installed'])/'config.lua'),
 'native_files':{p.name:file_digest(p)for p in(R/'Brainstorm').glob('*.dll')}}
with(H/'prework.json').open('x')as f:json.dump(data,f,indent=2);f.write('\n')
print(json.dumps({'archived_navigation':len(before),'prior_files':len(prior),'installed_version':B['version'],
 'prior_navigation_bytes':sum((R/x).stat().st_size for x in before)}))
