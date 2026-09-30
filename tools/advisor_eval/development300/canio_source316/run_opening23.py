"""One separately registered source opening component; max3 actions, no blind play."""
from pathlib import Path
import hashlib,json,sys
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def arguments(folder):
    return ['--deck','b_red','--stake','8','--seed','ITKSGS21',
      '--unlock-profile','all_unlocked_discovered_v1','--policy-root',str(folder/'policy'),
      '--seed-selection-evidence',str(folder/'normal_seed_selection.json'),
      '--normal-filter-recipe',str(folder/'normal_opening_recipe.json'),
      '--gold-objective','synthetic_only_canio_missing_v1','--episode','--debug-decisions',
      '--stop-on-opening-complete','--opening-only-actions','--stop-after-step','3']
def main():
    folder=Path(__file__).resolve().parent
    registration=json.loads((folder/'registration.json').read_text());spent=json.loads((folder/'spent.json').read_text())
    assert registration['job']==spent['job']=='M23'and registration['timeout_seconds']==30
    assert spent['registration_sha256']==sha(folder/'registration.json')
    metadata=registration['metadata']
    assert metadata['maximum_actions']==3 and metadata['policy_version']=='2.115.0-alpha'
    recipe=json.loads((folder/'normal_opening_recipe.json').read_text())
    assert recipe['seed']=='ITKSGS21'and recipe['expected_opening_jokers']==['j_caino','j_perkeo']
    assert recipe['filter_info']['collection_search']['minimum_distinct']==1
    print(json.dumps(dict(type='M23_opening_scope',seed='ITKSGS21',policy_version='2.115.0-alpha',
      maximum_actions=3,outer_seconds=30,allowed_actions=['skip_initial_Small','choose_Soul','choose_Soul'],
      source_action_legal_checks='existing original source and selected-action contract',
      profile_mode='synthetic_only_canio_missing_v1',initial_expected_counts=dict(total=150,complete=149,missing=1,unknown=0),
      before_decisions_receipt='engine_gold_objective_context.initial_goal',
      end_counts_receipt='engine_opening_setup_complete.snapshot.completionist_goal',
      native_search=False,blind_play=False,purchases=False,terminal_claim=False,qualification=False)),flush=True)
    import engine_probe
    sys.argv=[sys.argv[0],*arguments(folder)]
    return engine_probe.main()
if __name__=='__main__':raise SystemExit(main())
