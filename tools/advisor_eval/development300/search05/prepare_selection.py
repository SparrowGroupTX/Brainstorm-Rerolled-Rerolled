"""Post-dispatch read-only S05 audit and recipe preparation. Never search/run.

Outputs require a fresh directory; the original attempt/search records remain
unchanged. Root must independently freeze the new adapter and register C03.
"""
from pathlib import Path
import hashlib
import json
import sys
from spec import request, native_args
from normal_recipe import validate

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def build_recipe(q, result, evidence):
    if q != request() or result.get('status') != 'found':
        raise ValueError('Exact S05 found evidence is required')
    seed = result.get('seed')
    if (not isinstance(seed, str) or not 1 <= len(seed) <= 8 or any(c not in '123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ' for c in seed) or
        result.get('budget_ms') != 27000 or result.get('route') != q['route'] or
        type(result.get('screened')) is not int or result['screened'] <= 0 or
        type(result.get('exact_candidates')) is not int or not 0 < result['exact_candidates'] <= result['screened']):
        raise ValueError('The reported native match has invalid seed/counters/budget/route')
    params = native_args(q, seed)
    recipe = {'schema': 1, 'kind': 'normal_filtered_product_v1', 'qualification': False,
        'seed': seed, 'deck': 'b_red', 'stake': 8, 'expected_opening_jokers': ['j_yorick', 'j_perkeo'],
        'filter_info': {'native_api_version': 9, 'stake_level': 8, 'soul_count': 2, 'required_soul_count': 2,
            'joker_targets': params[17], 'joker_target_locations': params[19], 'no_perishable_jokers': True,
            'observatory_deadline': 0, 'deck_name': 'Red Deck', 'multi_soul_pack_consumed': False,
            'filter_params': params,
            'normal_opening': {'schema': 1, 'kind': 'normal_two_soul_v1', 'seed': seed, 'deck_key': 'b_red', 'stake': 8,
                'required_souls': 2, 'no_perishable_targets': True,
                'targets': [{'key': 'j_yorick', 'location': 'soul_pack', 'edition': 'any'},
                            {'key': 'j_perkeo', 'location': 'soul_pack', 'edition': 'any'}]},
            'collection_search': {'schema': 1, 'interchangeable_copies': True,
                'copy_alternatives': ['j_brainstorm', 'j_blueprint'], 'minimum_distinct': 0,
                'first_ante': 1, 'last_ante': 8, 'route': q['route'], 'observed_copy_key': None,
                'future_acquisition_verified': False, 'native_result': result}},
        'conditional_later_requirements': q['later_requirement'],
        'discovery': {'job': 'S05', 'api': 9, 'copy_alternatives': True, 'missing_quota': 0,
            'evidence_sha256': evidence,
            'interpretation': 'The native result does not disclose which copy branch matched. The opening recipe requires only the two Legendary acquisitions; later offers remain conditional and unobserved.'}}
    validate(recipe, seed, 'b_red', 8)
    selection = {'schema': 1, 'kind': 'declared_selected_development_seed', 'seed': seed,
        'qualification': False, 'source_search_job': 'S05', 'profile': 'all_unlocked_discovered_v1',
        'selection': 'One preregistered OR-preset development query starting at index2000000001.',
        'actual_player_profile': False, 'unseen_holdout': False, 'acquisition_retention_survival_verified': False,
        'copy_branch_observed': False, 'search_evidence': evidence}
    return recipe, selection

def main():
    if len(sys.argv) != 3:
        raise SystemExit('Usage: prepare_selection.py FROZEN_S05_FOLDER FRESH_OUTPUT_FOLDER')
    folder = Path(sys.argv[1]).resolve();out = Path(sys.argv[2]).resolve()
    evidence = {name: sha(folder/name) for name in ['record.json', 'result.json', 'raw_result.json', 'request.json', 'registration.json']}
    record = json.loads((folder/'record.json').read_text())
    registration = json.loads((folder/'registration.json').read_text())
    if (record.get('job') != 'S05' or record.get('status') != 'complete' or record.get('exit_code') != 0 or
        record.get('one_use_spent') is not True or record.get('frozen_files_unchanged') is not True or
        record.get('external_files_unchanged') is not True or record.get('registration_sha256') != evidence['registration.json']):
        raise ValueError('Completed, unchanged one-use search receipt required; preserve all other outcomes')
    for relative, expected in registration['files'].items():
        if sha(folder/relative) != expected:
            raise ValueError('Frozen S05 input changed: '+relative)
    recipe, selection = build_recipe(json.loads((folder/'request.json').read_text()),
                                    json.loads((folder/'result.json').read_text()), evidence)
    out.mkdir(parents=True, exist_ok=False)
    for name, value in [('normal_opening_recipe.json', recipe), ('normal_seed_selection.json', selection)]:
        with (out/name).open('x', encoding='utf-8') as stream:
            json.dump(value, stream, indent=2, allow_nan=False);stream.write('\n')
    print(json.dumps({'status': 'prepared', 'seed': recipe['seed'], 'output': str(out),
                      'source_attempt_executed': False, 'copy_branch_observed': False}))

if __name__ == '__main__':
    main()
