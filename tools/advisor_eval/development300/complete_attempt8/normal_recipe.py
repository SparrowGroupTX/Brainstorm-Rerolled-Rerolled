"""Validate disclosed normal product recipes; pure JSON, no source/game access.

API8 remains supported. The new API9 branch binds the two real starting Souls
separately from its conditional Blueprint-or-Brainstorm later query.
"""
import hashlib
import json
from pathlib import Path

def validate(record, seed, deck, stake):
    if (not isinstance(record, dict) or record.get('schema') != 1 or
        record.get('kind') != 'normal_filtered_product_v1' or record.get('qualification') is not False or
        record.get('seed') != seed or record.get('deck') != deck or record.get('stake') != stake):
        raise ValueError('Normal filter recipe identity/schema mismatch')
    info = record.get('filter_info');expected = record.get('expected_opening_jokers')
    if not isinstance(info, dict) or not isinstance(expected, list) or sorted(expected) != ['j_perkeo', 'j_yorick']:
        raise ValueError('Two distinct starting Legendary identities are required')
    api = info.get('native_api_version');params = info.get('filter_params')
    if (api not in (8, 9) or info.get('stake_level') != stake or info.get('required_soul_count') != 2 or
        info.get('soul_count') != 2 or info.get('multi_soul_pack_consumed') is not False or
        info.get('no_perishable_jokers') is not True or
        info.get('deck_name') != {'b_red': 'Red Deck', 'b_zodiac': 'Zodiac Deck'}.get(deck) or
        not isinstance(info.get('joker_targets'), str) or not isinstance(info.get('joker_target_locations'), str) or
        not isinstance(params, list) or len(params) != (22 if api == 8 else 28) or
        params[0] != seed or params[3] != 'Charm Tag' or params[4] != 2):
        raise ValueError('Normal filter recipe omits exact two-Soul product metadata')
    targets = info['joker_targets'].split('\x1f');locations = info['joker_target_locations'].split('\x1f')
    if (len(targets) != len(locations) or len(targets) > 5 or
        {t for t, loc in zip(targets, locations) if loc == 'soul_pack'} != {'Yorick', 'Perkeo'}):
        raise ValueError('Starting Charm locations do not bind Yorick and Perkeo')
    if (params[17] != info['joker_targets'] or params[18] != info['deck_name'] or
        params[19] != info['joker_target_locations'] or params[20] != stake or params[21] is not True):
        raise ValueError('Normal recipe and preserved native query disagree')
    if api == 9:
        if (stake != 8 or targets != ['Yorick', 'Brainstorm', 'Burnt Joker', 'Perkeo', ''] or
            locations != ['soul_pack', 'by_ante_5', 'by_ante_5', 'soul_pack', 'ante_1'] or
            params[1:17] != ['', '', 'Charm Tag', 2, False, 0, False, False, False, False, False,
                              'No Filter', 'Kings', 'Any Suit', 0, 0] or
            params[22] is not True or params[23:] != ['', 0, 1, 8, 27000]):
            raise ValueError('This disclosed API9 route requires the exact bounded OR preset')
        explicit = info.get('normal_opening')
        wanted = {'schema': 1, 'kind': 'normal_two_soul_v1', 'seed': seed, 'deck_key': deck, 'stake': 8,
                  'required_souls': 2, 'no_perishable_targets': True,
                  'targets': [{'key': 'j_yorick', 'location': 'soul_pack', 'edition': 'any'},
                              {'key': 'j_perkeo', 'location': 'soul_pack', 'edition': 'any'}]}
        if explicit != wanted:
            raise ValueError('API9 opening must bind only the two starting Legendary cards')
        collection = info.get('collection_search')
        if (not isinstance(collection, dict) or collection.get('schema') != 1 or
            collection.get('interchangeable_copies') is not True or
            collection.get('copy_alternatives') != ['j_brainstorm', 'j_blueprint'] or
            collection.get('minimum_distinct') != 0 or collection.get('first_ante') != 1 or collection.get('last_ante') != 8 or
            collection.get('route') != 'conditional_no_reroll_stock_and_buffoon' or
            collection.get('future_acquisition_verified') is not False or collection.get('observed_copy_key') is not None):
            raise ValueError('API9 copy requirements cannot be relabeled as observed acquisitions')
    return record

def load(path, seed, deck, stake):
    if path is None:
        return None
    raw = Path(path).read_bytes();record = validate(json.loads(raw), seed, deck, stake)
    return {'spec': record, 'recipe_digest': hashlib.sha256(raw).hexdigest(), 'qualification': False,
            'native_search_executed_by_adapter': False, 'progress_route': 'explicit_product_used_filter_seeded_false',
            'selection': 'externally_registered_selected_synthetic_development'}
