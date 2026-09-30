from pathlib import Path
from datetime import datetime,timezone
import json,shutil,sys
H=Path(__file__).resolve().parent;E=H.parent;R=E.parents[1];sys.path.insert(0,str(E))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text())
B=read(E/'INSTALLED_CHECKPOINT_449.json');F=read(E/'runs/repair449_candidate2/freeze.json')
assert policy_hashes(R)==F['candidate_policy_files']==B['policy_files']
assert policy_hashes(Path(B['installed']).parent)==B['policy_files']
assert test_manifest()==F['test_files'] and provenance()==F['validation_provenance']
nav=['ADVISOR_START_HERE.md','ADVISOR_HANDOFF.md','ADVISOR_RESUME_PROMPT.md','tools/advisor_eval/README.md',
 'tools/advisor_eval/FRESH_CHAT_HANDOFF_399.md','tools/advisor_eval/INSTALLATION_POLICY.md']
before={**policy_hashes(R),**test_manifest(),**{rel:file_digest(R/rel)for rel in nav}}
for rel,h in before.items():
 p=H/'before'/rel;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(R/rel,p);assert file_digest(p)==h
prior=read(E/'development449/prework.json')['prior_files']
prior.update({p.relative_to(R).as_posix():file_digest(p)for d in('development449','runs/repair449_candidate1','runs/repair449_candidate2','runs/repair449_installed')
 for p in(E/d).rglob('*')if p.is_file()and'__pycache__'not in p.parts})
for rel,h in prior.items():assert file_digest(R/rel)==h,rel
data={'created_utc':datetime.now(timezone.utc).isoformat(),'installed':B,'candidate_freeze':F,'before_files':before,
 'navigation':nav,'prior_files':prior,'provenance':provenance(),'config_sha256':file_digest(Path(B['installed'])/'config.lua'),
 'native_files':{p.name:file_digest(p)for p in(R/'Brainstorm').glob('*.dll')}}
assert data['native_files']=={p.name:file_digest(p)for p in Path(B['installed']).glob('*.dll')}
with(H/'prework.json').open('x')as f:json.dump(data,f,indent=2);f.write('\n')
for name in('capture.py','analyze_public.py','audit.py'):
 source=(E/'development449'/name).read_text()
 if name=='capture.py':source=source.replace('session-20260928T193840Z-1','session-20260929T022428Z-1').replace('INSTALLED_CHECKPOINT_446','INSTALLED_CHECKPOINT_449')
 with(H/name).open('x')as f:f.write(source)
print(json.dumps({'before':len(before),'prior':len(prior),'installed':B['version']}))
