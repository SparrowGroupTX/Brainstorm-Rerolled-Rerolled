"""Exact combined433 manufactured validation freeze; no experimental authority."""
from pathlib import Path
from datetime import datetime,timezone
import json,shutil,sys,difflib
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import digest,file_digest,freeze_policy,policy_hashes
from validate_checkpoint import test_manifest,provenance
from install_slice import stamp_version
CHANGED={'Brainstorm/Advisor/'+n+'.lua' for n in ('growth','decision','strategy','player_journal','shop_scoring','blind_finishing','joker_plan')}
CHANGED|={'Brainstorm/Core/Brainstorm.lua','Brainstorm/steamodded_compat.lua'}
base=json.loads((EVAL/'SESSION_RESET_431.json').read_text());installed=Path(base['installed'])
pre=json.loads((HERE/'prework.json').read_text())
assert policy_hashes(installed.parent)==base['policy_files']
assert {p.name:file_digest(p)for p in installed.glob('*.dll')}==pre['native_files']
for rel,h in pre['prior_files'].items():assert file_digest(ROOT/rel)==h,rel
for rel,h in pre['before_files'].items():assert file_digest(HERE/'before'/rel)==h,rel
for rel in ('Core/Brainstorm.lua','steamodded_compat.lua'):stamp_version(ROOT/'Brainstorm'/rel,rel,'2.213.0-alpha')
current=policy_hashes(ROOT)
delta={r for r in current.keys()|base['policy_files'].keys() if current.get(r)!=base['policy_files'].get(r)}
assert delta==CHANGED,sorted(delta)
number=int(sys.argv[1])if len(sys.argv)>1 else 1
out=EVAL/f'runs/repair433_candidate{number}';out.mkdir(exist_ok=False)
frozen=freeze_policy(out/'policy');assert frozen==current
report={'created_utc':datetime.now(timezone.utc).isoformat(),'kind':'routine_manufactured_candidate_validation_no_experiment',
 'baseline_release':431,'baseline_version':base['version'],'baseline_policy_digest':base['policy_digest'],
 'candidate_version':'2.213.0-alpha','candidate_policy_digest':digest(frozen),'candidate_policy_files':frozen,
 'changed_runtime_files':sorted(CHANGED),'test_files':test_manifest(),'validation_provenance':provenance(),
 'scope_sha256':file_digest(HERE/'SCOPE.md'),'installed_or_running_game_modified':False}
for rel in report['test_files']:
 dest=out/'tests_source'/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/rel,dest)
with (out/'freeze.json').open('x',encoding='utf-8')as f:json.dump(report,f,indent=2);f.write('\n')
diff=[]
for rel in sorted(CHANGED|{r for r,h in report['test_files'].items()if pre['test_files'].get(r)!=h}):
 old=HERE/'before'/rel
 diff.extend(difflib.unified_diff(old.read_text(encoding='utf-8').splitlines(True)if old.exists()else [],
  (ROOT/rel).read_text(encoding='utf-8').splitlines(True),fromfile='before/'+rel,tofile=rel))
(out/'changes.diff').write_text(''.join(diff),encoding='utf-8')
print(json.dumps({'candidate':out.name,'digest':digest(frozen),'runtime':len(frozen),'changed':len(CHANGED),'tests':len(report['test_files'])}))
