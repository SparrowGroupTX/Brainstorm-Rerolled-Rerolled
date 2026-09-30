"""Fresh one-use C08 source attempt. Never registers, searches or resumes."""
from pathlib import Path
import hashlib
import json
import sys

SEED='S7PXV521'
POLICY='e1d66be72a88ccf553811cb7cdb6358fb265ce9ac7e7bd85eaca7e70023b1966'
GOLD_MODE='synthetic_fresh_all_missing_v1'
def read(folder,name): return json.loads((Path(folder)/name).read_text())
def arguments(folder):
    folder=Path(folder);recipe=read(folder,'normal_opening_recipe.json');selection=read(folder,'normal_seed_selection.json')
    if (recipe.get('seed')!=SEED or recipe.get('deck')!='b_red' or recipe.get('stake')!=8 or
        recipe.get('qualification') is not False or recipe.get('discovery',{}).get('job')!='S05' or
        selection.get('seed')!=SEED or selection.get('source_search_job')!='S05' or
        selection.get('qualification') is not False or selection.get('unseen_holdout') is not False or
        recipe.get('filter_info',{}).get('native_api_version')!=9 or
        recipe.get('filter_info',{}).get('collection_search',{}).get('interchangeable_copies') is not True):
        raise ValueError('C08 requires the exact declared S05 S7PXV521 RedGold OR-copy development recipe')
    return ['--deck','b_red','--stake','8','--seed',SEED,'--unlock-profile','all_unlocked_discovered_v1',
        '--policy-root',str(folder/'policy'),'--seed-selection-evidence',str(folder/'normal_seed_selection.json'),
        '--normal-filter-recipe',str(folder/'normal_opening_recipe.json'),'--gold-objective',GOLD_MODE,
        '--episode','--debug-decisions']
def verify_registration(folder):
    folder=Path(folder);r=read(folder,'registration.json');spent=read(folder,'spent.json')
    m=r.get('metadata',{});installed=read(folder,'installed_policy_record.json')
    expected=hashlib.sha256((folder/'registration.json').read_bytes()).hexdigest()
    if (folder.name!='C08' or r.get('job')!='C08' or spent.get('job')!='C08' or
        spent.get('one_use') is not True or spent.get('registration_sha256')!=expected or
        r.get('timeout_seconds')!=180 or m.get('maximum_actions')!=500 or m.get('checkpoint')!=320 or
        m.get('seed')!=SEED or m.get('policy_digest')!=POLICY or
        installed.get('policy',{}).get('policy_digest')!=POLICY or
        installed.get('version')!='2.120.0-alpha' or m.get('installed_version')!='2.120.0-alpha' or
        m.get('retry_context')!='disabled_clean' or m.get('gold_objective_context')!=GOLD_MODE):
        raise ValueError('C08 needs its exact registered320 policy, profile and one-use spent receipt')
    if (folder/'record.json').exists(): raise ValueError('Completed C08 cannot be rerun')
def main():
    folder=Path(__file__).resolve().parent;verify_registration(folder);argv=arguments(folder)
    print(json.dumps({'type':'normal_attempt_scope','attempt':'C08','seed':SEED,'deck':'b_red','stake':8,
      'selected_dependent_development':True,'previous_same_seed_attempt':'C05','profile':'all_unlocked_discovered_v1',
      'max_actions':500,'outer_seconds':180,'qualification':False,'native_search_executed':False,
      'retry_context':'disabled_clean','gold_objective_context':GOLD_MODE,'fresh_source_initialization':True,
      'replayed_or_imported_future':False,'policy_digest':POLICY}),flush=True)
    import engine_probe
    sys.argv=[sys.argv[0],*argv]
    return engine_probe.main()
if __name__=='__main__': raise SystemExit(main())
