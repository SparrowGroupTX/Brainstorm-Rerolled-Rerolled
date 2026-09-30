"""Read completed S06 receipts and prepare source inputs; never run source/search."""
from pathlib import Path
from types import SimpleNamespace
import hashlib,json,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
sys.path.insert(0,str(HERE.parent/'search06'))
from spec import native_args
from normal_recipe import validate
from gold_objective_spec import build
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text())
def create(p,v):
    with p.open('x',encoding='utf-8')as out:json.dump(v,out,indent=2,allow_nan=False);out.write('\n')
def main():
    f=ROOT/'tools/advisor_eval/runs/gold299_20260914/S06';a=read(f/'audit.json');r=read(f/'result.json')
    assert a['status']=='found_native_route'and a['seed']==r['found']['seed']=='ITKSGS21'
    assert all(sha(f/name)==digest for name,digest in a['evidence_sha256'].items())
    found=r['found'];q=found['query'];native=found['receipt']['result'];seed=found['seed'];primary=q['primary_legendary_key']
    assert primary=='j_caino'and q['burnt_required']and found['phase']==1
    params=native_args(q,seed)
    targets=[dict(key=primary,location='soul_pack',edition='any'),
      dict(key='j_brainstorm',location='by_ante_5',edition='any'),
      dict(key='j_burnt',location='by_ante_5',edition='any'),
      dict(key='j_perkeo',location='soul_pack',edition='any')]
    collection=dict(schema=1,interchangeable_copies=True,copy_alternatives=['j_brainstorm','j_blueprint'],
      minimum_distinct=1,missing_names='Canio',first_ante=1,last_ante=8,route=q['route'],quota_mode='auto',
      burnt_required=True,burnt_relaxed=False,primary_legendary_key=primary,opening_adapted=True,opening_note=q['opening_note'],
      original_native_budget_ms=27000,total_native_reserved_ms=9000,profile_id=q['profile_id'],
      profile_token=read(f/'request.json')['profile_token'],future_acquisition_verified=False,
      observed_copy_key=None,native_result=native,external_native_receipt=found['receipt'],
      external_receipt_method='S06_serial_native_worker_v1; not a live LOVE thread receipt')
    info=dict(native_api_version=9,stake_level=8,soul_count=2,required_soul_count=2,
      joker_targets=q['target_jokers'],joker_target_locations=q['target_locations'],no_perishable_jokers=True,
      observatory_deadline=0,deck_name=q['deck'],multi_soul_pack_consumed=False,filter_params=params,
      normal_opening=dict(schema=1,kind='normal_two_soul_v1',deck_key='b_red',stake=8,seed=seed,
        required_souls=2,no_perishable_targets=True,targets=targets),collection_search=collection)
    recipe=dict(schema=1,kind='normal_filtered_product_v1',qualification=False,seed=seed,deck='b_red',stake=8,
      expected_opening_jokers=[primary,'j_perkeo'],filter_info=info,
      conditional_later_requirements=[dict(any_of=['j_brainstorm','j_blueprint'],by_ante=5),dict(key='j_burnt',by_ante=5)],
      discovery=dict(job='S06',evidence_sha256=a['evidence_sha256'],copy_branch_observed=False,
        interpretation='Exact observed native conditional alternate opening; later copy and Burnt acquisition remain unobserved.'))
    validate(recipe,seed,'b_red',8)
    selection=dict(schema=1,kind='declared_selected_development_seed',seed=seed,qualification=False,
      source_search_job='S06',profile='all_unlocked_discovered_v1',
      objective_profile='synthetic_only_canio_missing_v1',actual_player_profile=False,unseen_holdout=False,
      acquisition_retention_survival_verified=False,copy_branch_observed=False,
      selection='Single prospective Auto alternate-Canio query at index3000000001; selected synthetic development.',
      search_evidence=a['evidence_sha256'])
    spec=build(SimpleNamespace(gold_objective='synthetic_only_canio_missing_v1',episode=True,deck='b_red',stake=8,
      unlock_profile='all_unlocked_discovered_v1',normal_filter_recipe='normal_opening_recipe.json',
      seed_selection_evidence='normal_seed_selection.json'))
    create(HERE/'normal_opening_recipe.json',recipe);create(HERE/'normal_seed_selection.json',selection)
    create(HERE/'gold_objective_profile_spec.json',spec)
    create(HERE/'preparation_receipt.json',dict(schema=1,seed=seed,source_search_job='S06',audit_sha256=sha(f/'audit.json'),
      recipe_sha256=sha(HERE/'normal_opening_recipe.json'),selection_sha256=sha(HERE/'normal_seed_selection.json'),
      objective_profile_sha256=sha(HERE/'gold_objective_profile_spec.json'),
      source_worker_executed=False,source_zip_read=False,policy_evaluation_performed=False,
      profile_history='Only prospective source in-memory initialization; 149 synthetic prior rows are not new wins.',
      adapter_changes=['normal_recipe.py','gold_objective_spec.py','gold_objective_context.lua']))
    print('Prepared alternate Canio source inputs only; no registration or execution.')
if __name__=='__main__':main()
