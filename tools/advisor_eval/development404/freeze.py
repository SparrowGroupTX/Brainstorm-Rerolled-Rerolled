"""Freeze the complete repaired runtime and declared validation inputs, no install."""
from datetime import datetime, timezone
from pathlib import Path
import argparse
import json
import sys

EVAL=Path(__file__).resolve().parents[1]
ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import digest,file_digest,freeze_policy,policy_hashes
from validate_checkpoint import test_manifest,provenance

CHANGED={
 'Brainstorm/Advisor/'+name+'.lua' for name in (
 'acorn_ordering','collection_search','decision','draws','growth','player_journal',
 'runtime','score_cache','scoring','search','snapshot','strategy')}
CHANGED.update({'Brainstorm/Core/auto_run_product.lua','Brainstorm/Core/Brainstorm.lua',
                'Brainstorm/steamodded_compat.lua'})

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--name',required=True)
    args=parser.parse_args()
    assert args.name.startswith('repair404_candidate') and args.name.replace('_','').isalnum()
    out=EVAL/'runs'/args.name
    base=json.loads((EVAL/'SESSION_RESET_400.json').read_text())
    installed=Path(base['installed'])
    assert policy_hashes(installed.parent)==base['policy_files']
    assert {p.name:file_digest(p) for p in installed.glob('*.dll')}==base['native_files_preserved']
    current=policy_hashes(ROOT)
    delta={rel for rel in current.keys()|base['policy_files'].keys()
           if current.get(rel)!=base['policy_files'].get(rel)}
    assert delta==CHANGED,sorted(delta)
    for rel in ('Core/Brainstorm.lua','steamodded_compat.lua'):
        assert '2.195.0-alpha' in (ROOT/'Brainstorm'/rel).read_text()
    out.mkdir(parents=True,exist_ok=False)
    frozen=freeze_policy(out/'policy');assert current==frozen
    report={'created_utc':datetime.now(timezone.utc).isoformat(),
        'kind':'routine_candidate_validation_no_gameplay_experiment',
        'baseline_release':400,'baseline_version':base['version'],
        'baseline_policy_digest':base['policy_digest'],
        'candidate_version':'2.195.0-alpha','candidate_policy_digest':digest(frozen),
        'candidate_policy_files':frozen,'changed_runtime_files':sorted(CHANGED),
        'test_files':test_manifest(),'validation_provenance':provenance(),
        'scope_sha256':file_digest(EVAL/'development404/SCOPE.md'),
        'public_captures':['development403/capture/verification.json','development404/prework.json'],
        'installed_or_running_game_modified':False,'new_training_or_gameplay_experiment':False}
    (out/'freeze.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'path':str(out),'digest':digest(frozen),'runtime_files':len(frozen),
        'changed_files':len(CHANGED),'test_files':len(report['test_files'])}))

if __name__=='__main__':main()
