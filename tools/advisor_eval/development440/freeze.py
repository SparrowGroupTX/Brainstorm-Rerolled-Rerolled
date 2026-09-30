"""Freeze one exact manufactured-test candidate; no captured evaluations."""
from pathlib import Path
from datetime import datetime, timezone
import json, sys, shutil, difflib
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import digest,file_digest,freeze_policy,policy_hashes
from validate_checkpoint import test_manifest,provenance
from install_slice import stamp_version
def read(p):return json.loads(p.read_text(encoding='utf-8'))
base=read(EVAL/'INSTALLED_CHECKPOINT_437.json');pre=read(HERE/'prework.json')
assert policy_hashes(Path(base['installed']).parent)==base['policy_files']
for rel,h in pre['prior_files'].items():assert file_digest(ROOT/rel)==h,rel
for rel,h in pre['before_files'].items():assert file_digest(HERE/'before'/rel)==h,rel
for rel in ('Core/Brainstorm.lua','steamodded_compat.lua'):stamp_version(ROOT/'Brainstorm'/rel,rel,'2.218.0-alpha')
current=policy_hashes(ROOT);changed={r for r in current if current[r]!=base['policy_files'].get(r)}
expected={'Brainstorm/Advisor/growth.lua','Brainstorm/Advisor/scoring.lua','Brainstorm/Advisor/decision.lua',
 'Brainstorm/Advisor/player_journal.lua','Brainstorm/Advisor/search.lua','Brainstorm/Core/Brainstorm.lua','Brainstorm/steamodded_compat.lua'}
assert changed==expected,changed
number=int(sys.argv[1])if len(sys.argv)>1 else 1
out=EVAL/f'runs/repair440_candidate{number}';out.mkdir(exist_ok=False)
assert freeze_policy(out/'policy')==current
helpers={rel:file_digest(ROOT/rel)for rel in ('tools/advisor_eval/continuation_adapter.lua','tools/advisor_eval/continuation_evidence.lua')}
report={'created_utc':datetime.now(timezone.utc).isoformat(),'kind':'routine_manufactured_candidate_validation',
 'candidate_version':'2.218.0-alpha','candidate_policy_digest':digest(current),'candidate_policy_files':current,
 'changed_from_installed437':sorted(changed),'test_files':test_manifest(),'validation_provenance':provenance(),
 'evaluation_helpers':helpers,'scope_sha256':file_digest(HERE/'SCOPE.md')}
for rel in report['test_files']|helpers:
 dest=out/('tests_source'if rel in report['test_files']else'helpers')/rel
 dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/rel,dest)
with(out/'freeze.json').open('x',encoding='utf-8')as f:json.dump(report,f,indent=2);f.write('\n')
diff=[]
for rel in sorted(changed|set(helpers)|{r for r,h in report['test_files'].items()if pre['test_files'].get(r)!=h}):
 old=HERE/'before'/rel
 diff.extend(difflib.unified_diff(old.read_text(encoding='utf-8').splitlines(True)if old.exists()else[],
  (ROOT/rel).read_text(encoding='utf-8').splitlines(True),fromfile='before439/'+rel,tofile=rel))
(out/'changes.diff').write_text(''.join(diff),encoding='utf-8')
print(json.dumps({'candidate':out.name,'digest':digest(current),'tests':len(report['test_files'])}))
