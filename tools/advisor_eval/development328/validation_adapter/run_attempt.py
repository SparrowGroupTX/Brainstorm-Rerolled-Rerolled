"""Registered one-use worker only. Root reserves/launches; this never registers."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib
import json
import re
import sys

from benchmark import policy_hashes,digest
from normal_recipe import load as recipe_load,OBSERVED_KIND

SEEDS=('S7PXV521','RH45AD21','YAEARC31')
GOLD_MODE='synthetic_fresh_all_missing_v1'
SCOPE_MODE='stop_before_concealed_joker_decision_v1'
ADAPTER_FILES=('engine_probe.py','engine_probe.lua','engine_run.lua','engine_contract.lua','opening_support.py',
  'benchmark.py','normal_recipe.py','normal_terminal.lua','gold_objective_spec.py','gold_objective_context.lua',
  'policy_wiring.lua','information_scope.lua','run_attempt.py')
def read(folder,name):return json.loads((Path(folder)/name).read_text())
def sha(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as stream:
        for raw in iter(lambda:stream.read(1048576),b''):h.update(raw)
    return h.hexdigest()
def arguments(folder):
    folder=Path(folder);r=read(folder,'registration.json');m=r['metadata'];seed=m.get('seed')
    if seed not in SEEDS:raise ValueError('Attempt seed is outside this declared dependent validation batch')
    recipe=recipe_load(folder/'normal_opening_recipe.json',seed,'b_red',8)
    selected=read(folder,'normal_seed_selection.json')
    if (recipe['spec']['kind']!=OBSERVED_KIND or selected.get('seed')!=seed or
        selected.get('qualification') is not False or selected.get('unseen_holdout') is not False or
        selected.get('native_search_receipt_available') is not False or
        selected.get('public_observation_sha256')!=recipe['observation_sha256']):
        raise ValueError('Selected evidence differs from the exact public opening recipe')
    return ['--install',m['source_install'],'--deck','b_red','--stake','8','--seed',seed,
      '--unlock-profile','all_unlocked_discovered_v1','--policy-root',str(folder/'policy'),
      '--seed-selection-evidence',str(folder/'normal_seed_selection.json'),
      '--normal-filter-recipe',str(folder/'normal_opening_recipe.json'),'--gold-objective',GOLD_MODE,
      '--episode','--debug-decisions']
def verify_registration(folder):
    folder=Path(folder).resolve();r=read(folder,'registration.json');spent=read(folder,'spent.json');m=r.get('metadata',{})
    authority=read(folder,'authority.json');installed=read(folder,'installed_policy_record.json')
    job=folder.name
    if (not re.fullmatch('C0[1-6]',job) or r.get('job')!=job or spent.get('job')!=job or
        spent.get('one_use') is not True or spent.get('registration_sha256')!=sha(folder/'registration.json') or
        r.get('authority_sha256')!=sha(folder/'authority.json') or authority.get('kind')!='fresh_loss_validation_authority' or
        authority.get('limits',{}).get('complete_attempt_jobs')!=6 or authority['limits'].get('seconds_per_complete_attempt')!=180 or
        authority['limits'].get('total_worker_seconds')!=1260 or authority['limits'].get('search_jobs')!=0 or
        r.get('timeout_seconds')!=180 or m.get('maximum_actions')!=500 or m.get('outer_seconds')!=180 or
        m.get('seed') not in SEEDS or m.get('deck')!='b_red' or m.get('stake')!=8 or
        m.get('profile')!='all_unlocked_discovered_v1' or m.get('gold_objective_context')!=GOLD_MODE or
        m.get('retry_context')!='disabled_clean' or m.get('information_scope')!=SCOPE_MODE or
        m.get('qualification') is not False or m.get('native_search_in_attempt') is not False or
        m.get('save_access') is not False or m.get('player_profile_access') is not False or
        installed.get('policy',{}).get('policy_digest')!=m.get('policy_digest') or
        installed.get('version')!=m.get('installed_version')):
        raise ValueError('Attempt requires exact fresh authority, policy, profile and one-use limits')
    if (folder/'record.json').exists() or (folder/'worker_started.json').exists():
        raise ValueError('Started or completed workers cannot be rerun')
    frozen=r.get('files',{})
    required=set(ADAPTER_FILES)|{'normal_opening_recipe.json','normal_seed_selection.json','opening_public_observation.json',
      'installed_policy_record.json','installed_graph_check.json'}
    if not required.issubset(frozen):raise ValueError('Registration omits required adapter/provenance files')
    for relative,expected in frozen.items():
        p=(folder/relative).resolve();p.relative_to(folder)
        if sha(p)!=expected:raise ValueError('Registered file changed: '+relative)
    hashes=policy_hashes(folder/'policy')
    if hashes!=installed['policy']['policy_files'] or digest(hashes)!=m['policy_digest']:
        raise ValueError('Whole frozen product differs from the tested checkpoint')
    if any(frozen.get('policy/'+name)!=value for name,value in hashes.items()):
        raise ValueError('Registration omits exact complete product files')
    graph=read(folder,'installed_graph_check.json')
    if (graph.get('passed') is not True or graph.get('policy_digest')!=m['policy_digest'] or
        graph.get('source_initializations')!=0 or graph.get('policy_decisions')!=0):
        raise ValueError('Exact policy requires its inert graph verification')
    if graph.get('policy_files',hashes)!=hashes:
        raise ValueError('Inert graph binds different policy bytes')
    for name,expected in graph.get('adapter_files',{}).items():
        if sha(folder/name)!=expected:raise ValueError('Inert graph adapter binding changed: '+name)
    external=r.get('external_files',{});source=Path(m['source_install']).resolve()
    needed={str(source/'Balatro.exe'),str(source/'lua51.dll'),str(Path(sys.executable).resolve())}
    if set(external)!=needed:raise ValueError('Registration must bind exact source and runtimes only')
    for path,expected in external.items():
        if sha(path)!=expected:raise ValueError('Registered external binary changed')
    return r
def main():
    folder=Path(__file__).resolve().parent;r=verify_registration(folder);argv=arguments(folder);m=r['metadata']
    with (folder/'worker_started.json').open('x',encoding='utf-8') as stream:
        json.dump({'job':r['job'],'registration_sha256':sha(folder/'registration.json'),
          'started_at_utc':datetime.now(timezone.utc).isoformat(),'one_use':True},stream)
    print(json.dumps({'type':'normal_attempt_scope','attempt':r['job'],'seed':m['seed'],'deck':'b_red','stake':8,
      'selected_dependent_development':True,'profile':m['profile'],'gold_objective_context':GOLD_MODE,
      'observed_player_gold_complete':58,'synthetic_gold_complete':0,'max_actions':500,'outer_seconds':180,
      'qualification':False,'native_search_executed':False,'native_search_receipt_available':False,
      'retry_context':'disabled_clean','information_scope':SCOPE_MODE,'policy_digest':m['policy_digest'],
      'fresh_source_initialization':True,'replayed_or_imported_future':False}),flush=True)
    import engine_probe
    sys.argv=[sys.argv[0],*argv]
    return engine_probe.main()
if __name__=='__main__':raise SystemExit(main())
