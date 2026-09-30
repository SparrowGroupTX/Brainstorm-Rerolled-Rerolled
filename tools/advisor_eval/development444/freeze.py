"""Freeze unchanged2.219 runtime with repaired complete-gate scheduling."""
from pathlib import Path
from datetime import datetime,timezone
import json,sys,shutil
H=Path(__file__).resolve().parent;E=H.parent;R=E.parents[1];sys.path.insert(0,str(E))
from benchmark import file_digest,freeze_policy,policy_hashes,digest
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text())
P=read(H/'prework.json');B=P['installed'];runtime=policy_hashes(R)
assert runtime==P['runtime_files']==read(E/'runs/repair442_candidate2/freeze.json')['candidate_policy_files']
assert policy_hashes(Path(B['installed']).parent)==B['policy_files']
for rel,hash_ in P['prior_files'].items():assert file_digest(R/rel)==hash_,rel
for rel,hash_ in P['before_files'].items():assert file_digest(H/'before'/rel)==hash_,rel
out=E/('runs/repair444_candidate'+sys.argv[1]);out.mkdir(exist_ok=False)
assert freeze_policy(out/'policy')==runtime
helpers={rel:file_digest(R/rel)for rel in('tools/advisor_eval/continuation_adapter.lua','tools/advisor_eval/continuation_evidence.lua')}
F={'created_utc':datetime.now(timezone.utc).isoformat(),'candidate_version':'2.219.0-alpha','candidate_policy_digest':digest(runtime),'candidate_policy_files':runtime,'changed_from_installed440':sorted(r for r in runtime if runtime[r]!=B['policy_files'].get(r)),'test_files':test_manifest(),'validation_provenance':provenance(),'evaluation_helpers':helpers,'scope_sha256':file_digest(H/'SCOPE.md'),'runtime_equal_to_reviewed442':True}
for rel in F['test_files']|helpers:
 dest=out/('tests_source'if rel in F['test_files']else'helpers')/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(R/rel,dest)
for rel in('tests/run_lua_tests.py','tools/advisor_eval/validate_checkpoint.py'):
 dest=out/'validation_source'/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(R/rel,dest)
with(out/'freeze.json').open('x')as f:json.dump(F,f,indent=2);f.write('\n')
print(json.dumps({'candidate':str(out),'digest':F['candidate_policy_digest'],'tests':len(F['test_files']),'runtime_files':len(runtime)}))
