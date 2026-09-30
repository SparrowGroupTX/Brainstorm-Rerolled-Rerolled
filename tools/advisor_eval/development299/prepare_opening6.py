"""Build disclosed frozen recipe from S04 evidence; no native/source execution."""
from pathlib import Path
import hashlib
import json
here=Path(__file__).resolve().parent;base=here.parent/'runs/gold299_20260914';search=base/'S04'
result=json.loads((search/'result.json').read_text());request=json.loads((search/'request.json').read_text())
assert result['status']=='found' and result['seed']=='M4BVSY11' and request['copy_alternatives'] is False
seed=result['seed'];targets='\x1f'.join(request['targets']+['']);locations='\x1f'.join(request['locations']+['ante_1'])
params=[seed,'','','Charm Tag',2,False,0,False,False,False,False,False,'No Filter','Kings','Any Suit',0,0,targets,request['deck'],locations,8,True]
recipe={'schema':1,'kind':'normal_filtered_product_v1','qualification':False,'seed':seed,'deck':'b_red','stake':8,
        'expected_opening_jokers':['j_yorick','j_perkeo'],
        'filter_info':{'native_api_version':8,'stake_level':8,'soul_count':2,'required_soul_count':2,
                       'joker_targets':targets,'joker_target_locations':locations,'no_perishable_jokers':True,
                       'observatory_deadline':0,'deck_name':request['deck'],'multi_soul_pack_consumed':False,'filter_params':params},
        'discovery':{'job':'S04','api':9,'copy_alternatives':False,'missing_quota':0,
                     'result_sha256':hashlib.sha256((search/'result.json').read_bytes()).hexdigest(),
                     'interpretation':'v9 fixed targets use the existing API8 opening receipt; no OR/quota behavior is substituted.'}}
selection={'schema':1,'kind':'declared_selected_development_seed','seed':seed,'qualification':False,
           'source_search_job':'S04','profile':'all_unlocked_discovered_v1','selection':'native fixed-filter deterministic development discovery',
           'actual_player_profile':False,'unseen_holdout':False,'acquisition_retention_survival_verified':False,
           'search_evidence':{name:hashlib.sha256((search/name).read_bytes()).hexdigest() for name in ['record.json','result.json','registration.json','request.json']}}
for name,value in [('normal_opening_recipe.json',recipe),('normal_seed_selection.json',selection)]:
    with (here/name).open('x') as stream:json.dump(value,stream,indent=2)
print('Prepared disclosed S04 recipe and selection; no source/native execution')
