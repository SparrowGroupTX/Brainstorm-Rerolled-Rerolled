"""Freeze combined428+430+431 bytes without touching the active installation."""
from pathlib import Path
from datetime import datetime,timezone
import json,shutil,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import digest,file_digest,freeze_policy,policy_hashes
from validate_checkpoint import test_manifest,provenance
from install_slice import stamp_version
CHANGED={'Brainstorm/Advisor/acorn_belief.lua','Brainstorm/Advisor/acorn_discard.lua','Brainstorm/Advisor/growth.lua','Brainstorm/Advisor/player_journal.lua',
         'Brainstorm/Core/Brainstorm.lua','Brainstorm/steamodded_compat.lua'}
base=json.loads((EVAL/'SESSION_RESET_426.json').read_text());installed=Path(base['installed'])
assert policy_hashes(installed.parent)==base['policy_files']
assert {p.name:file_digest(p)for p in installed.glob('*.dll')}==base['native_files_preserved']
for rel in ('Core/Brainstorm.lua','steamodded_compat.lua'):stamp_version(ROOT/'Brainstorm'/rel,rel,'2.212.0-alpha')
current=policy_hashes(ROOT)
delta={r for r in current.keys()|base['policy_files'].keys()if current.get(r)!=base['policy_files'].get(r)}
assert delta==CHANGED,sorted(delta)
out=EVAL/'runs/repair431_candidate1';out.mkdir(exist_ok=False)
frozen=freeze_policy(out/'policy');assert frozen==current
report={'created_utc':datetime.now(timezone.utc).isoformat(),'kind':'routine_manufactured_candidate_validation_no_experiment',
    'baseline_candidate':430,'baseline_release':426,'baseline_version':base['version'],'baseline_policy_digest':base['policy_digest'],
    'candidate_version':'2.212.0-alpha','candidate_policy_digest':digest(frozen),'candidate_policy_files':frozen,
    'changed_runtime_files':sorted(CHANGED),'test_files':test_manifest(),'validation_provenance':provenance(),
    'scope_sha256':file_digest(HERE/'SCOPE.md'),'installed_or_running_game_modified':False}
for rel in report['test_files']:
    dest=out/'tests_source'/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/rel,dest)
with (out/'freeze.json').open('x',encoding='utf-8')as f:json.dump(report,f,indent=2);f.write('\n')
print(json.dumps({'candidate':'repair431_candidate1','digest':digest(frozen),'runtime':len(frozen),'changed':len(CHANGED),'tests':len(report['test_files'])}))
