"""Exact combined437 validation freeze; this does not run targeted cases."""
from pathlib import Path
from datetime import datetime,timezone
import json,shutil,sys,difflib
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import digest,file_digest,freeze_policy,policy_hashes
from validate_checkpoint import test_manifest,provenance
from install_slice import stamp_version
def read(p):return json.loads(p.read_text())
base=read(EVAL/'CANDIDATE_CHECKPOINT_436.json');installed=read(EVAL/'SESSION_RESET_434.json');pre=read(HERE/'prework.json')
assert policy_hashes(Path(installed['installed']).parent)==installed['policy_files']
for rel,h in pre['prior_files'].items():assert file_digest(ROOT/rel)==h,rel
for rel,h in pre['before_files'].items():assert file_digest(HERE/'before'/rel)==h,rel
for rel in ('Core/Brainstorm.lua','steamodded_compat.lua'):stamp_version(ROOT/'Brainstorm'/rel,rel,'2.216.0-alpha')
current=policy_hashes(ROOT);changed={r for r in current if current[r]!=base['policy_files'].get(r)}
assert changed=={'Brainstorm/Advisor/search.lua','Brainstorm/Core/Brainstorm.lua','Brainstorm/steamodded_compat.lua'},changed
number=int(sys.argv[1])if len(sys.argv)>1 else 1;out=EVAL/f'runs/repair437_candidate{number}';out.mkdir(exist_ok=False)
assert freeze_policy(out/'policy')==current
helpers={p.relative_to(ROOT).as_posix():file_digest(p)for p in (EVAL/'continuation_evidence.lua',EVAL/'continuation_adapter.lua')}
report={'created_utc':datetime.now(timezone.utc).isoformat(),'kind':'routine_manufactured_candidate_validation',
 'candidate_version':'2.216.0-alpha','candidate_policy_digest':digest(current),'candidate_policy_files':current,
 'changed_from436':sorted(changed),'changed_from_installed434':sorted(r for r in current if current[r]!=installed['policy_files'].get(r)),
 'test_files':test_manifest(),'validation_provenance':provenance(),'evaluation_helpers':helpers}
for rel in report['test_files']|helpers:
 dest=out/('tests_source'if rel in report['test_files']else'helpers')/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/rel,dest)
with(out/'freeze.json').open('x',encoding='utf-8')as f:json.dump(report,f,indent=2);f.write('\n')
diff=[]
for rel in sorted(changed|set(helpers)|{r for r,h in report['test_files'].items()if pre['test_files'].get(r)!=h}):
 old=HERE/'before'/rel
 diff.extend(difflib.unified_diff(old.read_text(encoding='utf-8').splitlines(True)if old.exists()else[],
  (ROOT/rel).read_text(encoding='utf-8').splitlines(True),fromfile='before436/'+rel,tofile=rel))
(out/'changes.diff').write_text(''.join(diff),encoding='utf-8')
print(json.dumps({'candidate':out.name,'digest':digest(current),'tests':len(report['test_files'])}))
