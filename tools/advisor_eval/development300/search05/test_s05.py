"""Routine pure request/parser fixtures. No native/source/game/search calls."""
import ast
import copy
import hashlib
import json
from pathlib import Path
import time
from spec import request, seed_at, native_args, NATIVE_NAME
from prepare_selection import build_recipe
from normal_recipe import validate

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
checks = 0

def check(value, message):
    global checks
    checks += 1
    if not value:
        raise AssertionError(message)

def rejected(value, label):
    try:
        validate(value, 'TEST', 'b_red', 8)
    except ValueError:
        check(True, label)
    else:
        check(False, label)

def main():
    started = time.perf_counter()
    files = sorted(HERE.glob('*.py')) + [HERE/'profile_assumption.json']
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    for p in files:
        if p.suffix == '.py':
            ast.parse(p.read_text(encoding='utf-8'));check(True, 'Python source parses without executing '+p.name)
    q = request();args = native_args(q)
    check(len(args) == 28 and len(args[17].split('\x1f')) == 5 and len(args[19].split('\x1f')) == 5, 'exact five-slot v9 ABI')
    check(args[22] is True and args[24] == 0 and args[27] == 27000, 'OR enabled, quota zero, native27s')
    check(q['start_index'] == 2000000001 and q['seed'] == seed_at(2000000001), 'explicit independent development cursor')
    check(q['max_indices'] == 10**12 and q['outer_cap_seconds'] == 30, 'prospective cost bounds')
    check(seed_at(1) == '1' and seed_at(8) == '11111111' and seed_at(9) == '21111111', 'native seed coefficient order')
    check(seed_at(2318107019760) == 'ZZZZZZZZ', 'last native index')
    check(q['native_file'] == NATIVE_NAME and q['matches'] == 1, 'exact sidecar and one requested match')
    changed = copy.deepcopy(q);changed['budget_ms'] = 30000
    try:
        native_args(changed)
    except ValueError:
        check(True, 'worker refuses changed preregistered native budget')
    else:
        check(False, 'changed request accepted')
    result = {'schema': 1, 'status': 'found', 'seed': 'TEST', 'screened': 100, 'exact_candidates': 2,
              'budget_ms': 27000, 'threads': 2, 'seconds': .01, 'route': q['route']}
    recipe, selection = build_recipe(q, result, {'fixture': 'synthetic'})
    check(validate(recipe, 'TEST', 'b_red', 8) is recipe, 'exact new OR recipe accepted')
    opening = recipe['filter_info']['normal_opening']
    check([t['key'] for t in opening['targets']] == ['j_yorick', 'j_perkeo'], 'opening declares only two actual required Souls')
    check(recipe['conditional_later_requirements'][0]['any_of'] == ['j_brainstorm', 'j_blueprint'], 'copy alternatives retained separately')
    check(selection['unseen_holdout'] is False and selection['copy_branch_observed'] is False, 'development selection has no invented copy observation')
    check(recipe['filter_info']['collection_search']['observed_copy_key'] is None, 'undisclosed native branch remains unknown')
    check(recipe['filter_info']['filter_params'][0] == 'TEST', 'run receipt uses matched seed rather than start index seed')
    for field, value in [('native_api_version', 8), ('required_soul_count', 1), ('multi_soul_pack_consumed', True),
                         ('no_perishable_jokers', False), ('deck_name', 'Zodiac Deck')]:
        bad = copy.deepcopy(recipe);bad['filter_info'][field] = value;rejected(bad, 'reject invalid '+field)
    for index, value in [(0, 'OTHER'), (3, ''), (18, 'Zodiac Deck'), (20, 1), (21, False), (22, False), (24, 1), (27, 30000)]:
        bad = copy.deepcopy(recipe);bad['filter_info']['filter_params'][index] = value;rejected(bad, 'reject changed native position '+str(index))
    for field, value in [('observed_copy_key', 'j_brainstorm'), ('future_acquisition_verified', True),
                         ('interchangeable_copies', False), ('copy_alternatives', ['j_brainstorm'])]:
        bad = copy.deepcopy(recipe);bad['filter_info']['collection_search'][field] = value;rejected(bad, 'reject false or weakened copy evidence')
    bad = copy.deepcopy(recipe);bad['filter_info']['normal_opening']['targets'].append({'key': 'j_brainstorm', 'location': 'by_ante_5', 'edition': 'any'})
    rejected(bad, 'future OR copy cannot be recast as required starting acquisition')
    for status in ['not_found', 'timeout', 'cancelled', 'invalid', 'error']:
        failed = copy.deepcopy(result);failed['status'] = status
        try:
            build_recipe(q, failed, {})
        except ValueError:
            check(True, 'non-found outcome cannot prepare source selection')
        else:
            check(False, status+' was imputed as found')
    old = json.loads((ROOT/'tools/advisor_eval/development299/normal_opening_recipe.json').read_text())
    check(validate(old, old['seed'], 'b_red', 8) is old, 'disclosed API8 prior recipe remains accepted unchanged')
    check(all(hashlib.sha256((HERE/name).read_bytes()).hexdigest() == digest for name, digest in hashes.items()), 'all pure fixture inputs unchanged')
    report = {'schema': 1, 'status': 'passed', 'checks': checks, 'elapsed_seconds': time.perf_counter()-started,
              'files_sha256': hashes, 'scope': 'Pure Python request/parser fixtures; no native loading, search registration, source execution or game/save/profile operation.'}
    with (HERE/'synthetic_fixture_report.json').open('x', encoding='utf-8') as stream:
        json.dump(report, stream, indent=2);stream.write('\n')
    print(json.dumps(report))

if __name__ == '__main__':
    main()
