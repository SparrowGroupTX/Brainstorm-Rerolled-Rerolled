"""Validate disclosed normal filtered starts; never search or access player data."""
import hashlib
import json
from pathlib import Path

def load(path, seed, deck, stake):
    if path is None:
        return None
    raw=Path(path).read_bytes();record=json.loads(raw)
    if (not isinstance(record,dict) or record.get('schema')!=1 or
            record.get('kind')!='normal_filtered_product_v1' or record.get('qualification') is not False or
            record.get('seed')!=seed or record.get('deck')!=deck or record.get('stake')!=stake):
        raise ValueError('Normal filter recipe identity/schema mismatch')
    info=record.get('filter_info');expected=record.get('expected_opening_jokers')
    if (not isinstance(info,dict) or info.get('native_api_version')!=8 or info.get('stake_level')!=stake or
            info.get('required_soul_count')!=2 or info.get('soul_count')!=2 or
            info.get('multi_soul_pack_consumed') is not False or
            info.get('no_perishable_jokers') is not True or
            info.get('deck_name')!={'b_red':'Red Deck','b_zodiac':'Zodiac Deck'}.get(deck) or
            not isinstance(info.get('joker_targets'),str) or not isinstance(info.get('joker_target_locations'),str) or
            not isinstance(info.get('filter_params'),list) or len(info['filter_params'])!=22 or
            info['filter_params'][0]!=seed or info['filter_params'][3]!='Charm Tag' or
            info['filter_params'][4]!=2 or set(expected or [])!={'j_yorick','j_perkeo'} or len(expected)!=2):
        raise ValueError('Normal filter recipe omits the exact two-Soul product metadata')
    targets=info['joker_targets'].split('\x1f');locations=info['joker_target_locations'].split('\x1f')
    if (len(targets)!=len(locations) or len(targets)>5 or
            {t for t,l in zip(targets,locations) if l=='soul_pack'}!={'Yorick','Perkeo'}):
        raise ValueError('Normal recipe target locations do not bind Yorick/Perkeo to Starting Charm')
    params=info['filter_params']
    if (params[17]!=info['joker_targets'] or params[18]!=info['deck_name'] or
            params[19]!=info['joker_target_locations'] or params[20]!=stake or params[21] is not True):
        raise ValueError('Normal recipe metadata and preserved native query disagree')
    return {'spec':record,'recipe_digest':hashlib.sha256(raw).hexdigest(),'qualification':False,
            'native_search_executed_by_adapter':False,'progress_route':'explicit_product_used_filter_seeded_false',
            'selection':'externally_registered_selected_synthetic_development'}
