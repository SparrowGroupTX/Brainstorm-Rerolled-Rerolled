"""Preserve exact prior work and prepare passive/descriptive helpers only."""
from pathlib import Path
from datetime import datetime,timezone
import json,shutil,sys
H=Path(__file__).resolve().parent;E=H.parent;R=E.parents[1];sys.path.insert(0,str(E))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text())
B=read(E/'INSTALLED_CHECKPOINT_446.json');F=read(E/'runs/repair447_candidate1/freeze.json')
assert policy_hashes(R)==F['candidate_policy_files']
assert policy_hashes(Path(B['installed']).parent)==B['policy_files']
assert test_manifest()==F['test_files']and provenance()==F['validation_provenance']
nav=['ADVISOR_START_HERE.md','ADVISOR_HANDOFF.md','ADVISOR_RESUME_PROMPT.md','tools/advisor_eval/README.md',
 'tools/advisor_eval/FRESH_CHAT_HANDOFF_399.md','tools/advisor_eval/INSTALLATION_POLICY.md']
before={**policy_hashes(R),**test_manifest(),**{rel:file_digest(R/rel)for rel in nav}}
for rel,h in before.items():
 p=H/'before'/rel;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(R/rel,p);assert file_digest(p)==h
prior={p.relative_to(R).as_posix():file_digest(p)for d in ('development447','runs/repair447_candidate1','development446/install')
 for p in(E/d).rglob('*')if p.is_file()and'__pycache__'not in p.parts}
data={'created_utc':datetime.now(timezone.utc).isoformat(),'installed':B,'candidate_freeze':F,'before_files':before,
 'navigation':nav,'prior_files':prior,'provenance':provenance(),
 'config_sha256':file_digest(Path(B['installed'])/'config.lua'),
 'native_files':{p.name:file_digest(p)for p in (R/'Brainstorm').glob('*.dll')}}
assert data['native_files']=={p.name:file_digest(p)for p in Path(B['installed']).glob('*.dll')}
with(H/'prework.json').open('x')as f:json.dump(data,f,indent=2);f.write('\n')
capture=(E/'development446/install/capture.py').read_text().replace('EVAL=HERE.parents[1]','EVAL=HERE.parent')
capture=capture.replace('session-20260928T183037Z-1','session-20260928T193840Z-1').replace('INSTALLED_CHECKPOINT_444','INSTALLED_CHECKPOINT_446')
capture=capture.replace('latest-session release capture','current-session analysis capture')
with(H/'capture.py').open('x')as f:f.write(capture)
analyze=(E/'development447/analyze_public.py').read_text().replace("HERE.parent/'development446/install/captures/001/", "HERE/'captures/001/")
with(H/'analyze_public.py').open('x')as f:f.write(analyze)
print(json.dumps({'before':len(before),'prior':len(prior),'installed':B['version'],'candidate':F['candidate_version']}))
