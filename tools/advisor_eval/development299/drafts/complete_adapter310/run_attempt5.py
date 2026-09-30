"""Preparation for one separately registered dependent attempt; never self-registers."""
from pathlib import Path
import json
import sys

SEED = 'S7PXV521'
GOLD_MODE = 'synthetic_fresh_all_missing_v1'


def arguments(folder):
    folder = Path(folder)
    recipe = json.loads((folder / 'normal_opening_recipe.json').read_text(encoding='utf-8'))
    if (recipe.get('seed') != SEED or recipe.get('deck') != 'b_red' or recipe.get('stake') != 8
            or recipe.get('qualification') is not False):
        raise ValueError('C05 requires the declared dependent S7PXV521 Red Gold recipe')
    return ['--deck', 'b_red', '--stake', '8', '--seed', SEED,
            '--unlock-profile', 'all_unlocked_discovered_v1', '--policy-root', str(folder / 'policy'),
            '--seed-selection-evidence', str(folder / 'normal_seed_selection.json'),
            '--normal-filter-recipe', str(folder / 'normal_opening_recipe.json'),
            '--gold-objective', GOLD_MODE, '--episode', '--debug-decisions']


def main():
    folder = Path(__file__).resolve().parent
    argv = arguments(folder)
    print(json.dumps({'type': 'normal_attempt_scope', 'attempt': 'C05', 'seed': SEED,
                     'deck': 'b_red', 'stake': 8, 'selected_dependent_development': True,
                     'previous_same_seed_attempt': 'C03', 'profile': 'all_unlocked_discovered_v1',
                     'max_actions': 500, 'outer_seconds': 180, 'qualification': False,
                     'native_search_executed': False, 'retry_context': 'disabled_clean',
                     'gold_objective_context': GOLD_MODE}), flush=True)
    import engine_probe
    sys.argv = [sys.argv[0], *argv]
    return engine_probe.main()


if __name__ == '__main__':
    raise SystemExit(main())
