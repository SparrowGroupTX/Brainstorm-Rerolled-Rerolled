"""Read redacted public trace only. Does not import an engine or open source/saves."""
from pathlib import Path
import hashlib
import json

HERE=Path(__file__).resolve().parent
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def prepare():
    base=HERE.parent/'public_trace';out=HERE/'recipes';out.mkdir(exist_ok=False)
    for n in [3,4,5]:
        path=base/f'run{n}.json';run=json.loads(path.read_text());first=run['events'][0];seed=first['seed']
        snapshot=json.loads((base/first['snapshot']).read_text());target=out/seed;target.mkdir()
        acquired=next(e for e in run['events'] if e.get('state',{}).get('phase')=='blind' and e['state']['round']==0 and len(e['state']['jokers'])==2)
        evidence={'schema':1,'kind':'redacted_public_opening_observation','seed':seed,'run_trace_sha256':sha(path),
          'initial_event':{k:first[k] for k in ['sequence','event_sha256','file','ordinal']},
          'initial_snapshot_sha256':sha(base/first['snapshot']),
          'initial':{k:snapshot[k] for k in ['phase','ante','round','deck_key','stake','normal_opening']},
          'observed_opening_jokers':sorted(j['key'] for j in acquired['state']['jokers']),
          'acquisition_event':{k:acquired[k] for k in ['sequence','event_sha256','file','ordinal']},
          'actual_player_profile_imported':False,'future_actions_imported':False}
        evidence['initial']['small_tag']=snapshot['skip_tags']['Small']
        raw=(json.dumps(evidence,indent=2,sort_keys=True)+'\n').encode();(target/'opening_public_observation.json').write_bytes(raw)
        op=snapshot['normal_opening'];explicit={k:op[k] for k in ['schema','kind','deck_key','stake','required_souls','no_perishable_targets','targets']};explicit['seed']=seed
        recipe={'schema':1,'kind':'observed_public_normal_two_soul_v1','qualification':False,'seed':seed,'deck':'b_red','stake':8,
          'expected_opening_jokers':['j_yorick','j_perkeo'],'native_search_receipt_available':False,'unseen_holdout':False,
          'future_acquisition_verified':False,'public_observation':{'file':'opening_public_observation.json','sha256':hashlib.sha256(raw).hexdigest()},
          'filter_info':{'required_soul_count':2,'soul_count':2,'multi_soul_pack_consumed':False,'normal_opening':explicit},
          'scope':'Reconstructed only from declared public product opening and observed two Legendary acquisitions. No native API/query/result is imputed; later targets are labels, not verified availability.'}
        (target/'normal_opening_recipe.json').write_text(json.dumps(recipe,indent=2,sort_keys=True)+'\n')
        selection={'schema':1,'kind':'declared_selected_development_seed','seed':seed,'qualification':False,
          'selection':'Previously observed failed public product run, selected for paired development validation','unseen_holdout':False,
          'actual_player_profile':False,'profile':'all_unlocked_discovered_v1','native_search_receipt_available':False,
          'native_search_executed_by_adapter':False,'public_observation_sha256':hashlib.sha256(raw).hexdigest(),
          'observed_run_number':n,'gold_objective_context':'synthetic_fresh_all_missing_v1','observed_gold_complete':58,'experiment_gold_complete':0}
        (target/'normal_seed_selection.json').write_text(json.dumps(selection,indent=2,sort_keys=True)+'\n')
    return {'recipes':3,'source_initializations':0,'policy_decisions':0,'searches':0}
if __name__=='__main__':print(json.dumps(prepare()))
