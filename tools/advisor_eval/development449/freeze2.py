"""Freeze this Idol product-floor repair and all combined runtime bytes."""
from pathlib import Path
from datetime import datetime, timezone
import json, sys, shutil
H=Path(__file__).resolve().parent;E=H.parent;R=E.parents[1];sys.path.insert(0,str(E))
from benchmark import file_digest,freeze_policy,policy_hashes,digest
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text())
P=read(H/'prework.json');B=P['installed'];runtime=policy_hashes(R)
assert policy_hashes(Path(B['installed']).parent)==B['policy_files']
for rel,h in P['prior_files'].items():assert file_digest(R/rel)==h,rel
for rel,h in P['before_files'].items():assert file_digest(H/'before'/rel)==h,rel
assert provenance()==P['provenance']
assert file_digest(Path(B['installed'])/'config.lua')==P['config_sha256']
for root in (R/'Brainstorm',Path(B['installed'])):
    assert {p.name:file_digest(p)for p in root.glob('*.dll')}==P['native_files']
changed=sorted(r for r in runtime if runtime[r]!=B['policy_files'].get(r))
assert set(changed)=={'Brainstorm/Advisor/shop_scoring.lua','Brainstorm/Advisor/growth.lua','Brainstorm/Core/Brainstorm.lua','Brainstorm/steamodded_compat.lua'}
tests=test_manifest();assert len(tests)==381 and len(runtime)==110
assert set(tests)-set(P['candidate_freeze']['test_files'])=={'tests/advisor_idol_product449.lua'}
for rel,h in P['candidate_freeze']['test_files'].items():assert tests[rel]==h,rel
out=E/'runs/repair449_candidate2';out.mkdir(exist_ok=False)
assert freeze_policy(out/'policy')==runtime
helpers={r:file_digest(R/r)for r in ('tools/advisor_eval/continuation_adapter.lua','tools/advisor_eval/continuation_evidence.lua')}
F={'created_utc':datetime.now(timezone.utc).isoformat(),'candidate_version':'2.224.0-alpha',
 'candidate_policy_digest':digest(runtime),'candidate_policy_files':runtime,
 'changed_from_installed446':changed,'test_files':tests,
 'validation_provenance':provenance(),'evaluation_helpers':helpers,
 'scope_sha256':file_digest(H/'SCOPE.md'),'baseline_installed_checkpoint':446}
for rel in F['test_files']|helpers:
    dest=out/('tests_source'if rel in F['test_files']else'helpers')/rel
    dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(R/rel,dest)
for rel in ('tests/run_lua_tests.py','tools/advisor_eval/validate_checkpoint.py'):
    dest=out/'validation_source'/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(R/rel,dest)
with (out/'freeze.json').open('x')as f:json.dump(F,f,indent=2);f.write('\n')
print(json.dumps({'candidate':str(out),'digest':F['candidate_policy_digest'],'tests':len(tests),
 'runtime_files':len(runtime),'changed':changed}))
