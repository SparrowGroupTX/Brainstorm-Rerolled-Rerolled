"""Pure setup/provenance checks. Does not import or run engine_probe.main."""
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest

HERE = Path(__file__).resolve().parent


def module(name):
    spec = importlib.util.spec_from_file_location('adapter310_' + name, HERE / (name + '.py'))
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


class AdapterSpec(unittest.TestCase):
    def test_explicit_gold_and_no_special_worker_flags(self):
        worker = module('run_attempt5')
        argv = worker.arguments(HERE)
        self.assertEqual(argv[argv.index('--seed') + 1], 'S7PXV521')
        self.assertEqual(argv[argv.index('--gold-objective') + 1], 'synthetic_fresh_all_missing_v1')
        self.assertIn('--episode', argv)
        for forbidden in ('--test-scenario', '--replay-trace', '--override', '--opening-targets',
                          '--opening-only-actions', '--stop-on-opening-complete'):
            self.assertNotIn(forbidden, argv)

    def test_recipe_is_observed_dependent_api9(self):
        recipe = module('normal_recipe').load(HERE / 'normal_opening_recipe.json', 'S7PXV521', 'b_red', 8)
        self.assertFalse(recipe['qualification'])
        self.assertFalse(recipe['native_search_executed_by_adapter'])
        self.assertEqual(recipe['spec']['filter_info']['native_api_version'], 9)
        selection = json.loads((HERE / 'normal_seed_selection.json').read_text())
        self.assertFalse(selection['unseen_holdout'])
        self.assertFalse(selection['actual_player_profile'])

    def test_wrong_recipe_cannot_relabel_old_attempt(self):
        with tempfile.TemporaryDirectory() as temp:
            p = Path(temp)
            (p / 'normal_opening_recipe.json').write_text(json.dumps({'seed': 'M4BVSY11', 'deck': 'b_red', 'stake': 8}))
            with self.assertRaises(ValueError):
                module('run_attempt5').arguments(p)

    def test_default_gold_off_and_explicit_profile_requirements(self):
        build = module('gold_objective_spec').build
        self.assertFalse(build(SimpleNamespace())['enabled'])
        args = dict(gold_objective='synthetic_fresh_all_missing_v1', episode=True, deck='b_red', stake=8,
                    unlock_profile='all_unlocked_discovered_v1', normal_filter_recipe='declared',
                    seed_selection_evidence='declared')
        result = build(SimpleNamespace(**args))
        self.assertFalse(result['qualification'])
        self.assertFalse(result['actual_player_profile'])
        for field, invalid in [('stake', 7), ('unlock_profile', 'source_defaults_v1'),
                               ('test_scenario', 'terminal_win_final'), ('replay_trace', 'oldtrace')]:
            bad = dict(args, **{field: invalid})
            with self.assertRaises(ValueError):
                build(SimpleNamespace(**bad))

    def test_new_verifier_is_preloaded_and_in_adapter_digest(self):
        source = (HERE / 'engine_probe.py').read_text()
        ast.parse(source)
        self.assertIn('"policy_wiring.lua")}', source)
        self.assertIn('package.preload.probe_policy_wiring=', source)
        lua = (HERE / 'engine_run.lua').read_text()
        self.assertLess(lua.index("require('probe_policy_wiring').verify"), lua.index('decision.run(s,modules)'))
        self.assertIn('max_checkpoint_reloads=0', lua)
        self.assertNotIn('options={retry=', lua)

    def test_unchanged_original_adapter_and_selected_recipe_material(self):
        changes = {'engine_run.lua', 'engine_probe.py'}
        for row in json.loads((HERE / 'base_manifest.json').read_text()):
            if row['draft'] not in changes:
                self.assertEqual(hashlib.sha256((HERE / row['draft']).read_bytes()).hexdigest(), row['base_sha256'])


if __name__ == '__main__':
    unittest.main()
