"""One separately registered fresh C06 attempt; never registers or resumes itself."""
from pathlib import Path
import hashlib
import json
import sys

SEED = 'M4BVSY11'
GOLD_MODE = 'synthetic_fresh_all_missing_v1'


def arguments(folder):
    folder = Path(folder)
    recipe = json.loads((folder / 'normal_opening_recipe.json').read_text())
    selection = json.loads((folder / 'normal_seed_selection.json').read_text())
    if (recipe.get('seed') != SEED or recipe.get('deck') != 'b_red' or recipe.get('stake') != 8
            or recipe.get('qualification') is not False or recipe.get('discovery', {}).get('job') != 'S04'
            or selection.get('seed') != SEED or selection.get('source_search_job') != 'S04'
            or selection.get('qualification') is not False or selection.get('unseen_holdout') is not False):
        raise ValueError('C06 requires the exact declared M4BVSY11/S04 Red Gold development recipe')
    return ['--deck', 'b_red', '--stake', '8', '--seed', SEED,
            '--unlock-profile', 'all_unlocked_discovered_v1', '--policy-root', str(folder / 'policy'),
            '--seed-selection-evidence', str(folder / 'normal_seed_selection.json'),
            '--normal-filter-recipe', str(folder / 'normal_opening_recipe.json'),
            '--gold-objective', GOLD_MODE, '--episode', '--debug-decisions']


def verify_registration(folder):
    def read(name):
        return json.loads((folder / name).read_text())
    registration = read('registration.json'); spent = read('spent.json')
    actual_hash = hashlib.sha256((folder / 'registration.json').read_bytes()).hexdigest()
    if (folder.name != 'C06' or registration.get('job') != 'C06' or spent.get('job') != 'C06'
            or spent.get('one_use') is not True or spent.get('registration_sha256') != actual_hash
            or registration.get('timeout_seconds') != 180
            or registration.get('metadata', {}).get('maximum_actions') != 500
            or registration.get('metadata', {}).get('seed') != SEED
            or registration.get('metadata', {}).get('checkpoint') != 315):
        raise ValueError('C06 requires root registration and its one-use spent receipt')
    if (folder / 'record.json').exists():
        raise ValueError('Completed C06 cannot be rerun')


def main():
    folder = Path(__file__).resolve().parent
    verify_registration(folder)
    argv = arguments(folder)
    print(json.dumps({'type': 'normal_attempt_scope', 'attempt': 'C06', 'seed': SEED,
                     'deck': 'b_red', 'stake': 8, 'selected_dependent_development': True,
                     'previous_same_seed_attempt': 'C04', 'profile': 'all_unlocked_discovered_v1',
                     'max_actions': 500, 'outer_seconds': 180, 'qualification': False,
                     'native_search_executed': False, 'retry_context': 'disabled_clean',
                     'gold_objective_context': GOLD_MODE, 'fresh_source_initialization': True,
                     'replayed_or_imported_future': False}), flush=True)
    import engine_probe
    sys.argv = [sys.argv[0], *argv]
    return engine_probe.main()


if __name__ == '__main__':
    raise SystemExit(main())
