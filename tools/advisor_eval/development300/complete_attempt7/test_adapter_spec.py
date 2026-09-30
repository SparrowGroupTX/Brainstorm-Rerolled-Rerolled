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
    spec = importlib.util.spec_from_file_location('adapter_c07_' + name, HERE / (name + '.py'))
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


class AdapterSpec(unittest.TestCase):
    def test_explicit_gold_and_no_special_worker_flags(self):
        worker = module('run_attempt7')
        argv = worker.arguments(HERE)
        self.assertEqual(argv[argv.index('--seed') + 1], 'M4BVSY11')
        self.assertEqual(argv[argv.index('--gold-objective') + 1], 'synthetic_fresh_all_missing_v1')
        self.assertIn('--episode', argv)
        for forbidden in ('--test-scenario', '--replay-trace', '--override', '--opening-targets',
                          '--opening-only-actions', '--stop-on-opening-complete'):
            self.assertNotIn(forbidden, argv)

    def test_recipe_is_observed_dependent_api9(self):
        recipe = module('normal_recipe').load(HERE / 'normal_opening_recipe.json', 'M4BVSY11', 'b_red', 8)
        self.assertFalse(recipe['qualification'])
        self.assertFalse(recipe['native_search_executed_by_adapter'])
        self.assertEqual(recipe['spec']['filter_info']['native_api_version'], 8)
        selection = json.loads((HERE / 'normal_seed_selection.json').read_text())
        self.assertFalse(selection['unseen_holdout'])
        self.assertFalse(selection['actual_player_profile'])

    def test_wrong_recipe_cannot_relabel_old_attempt(self):
        with tempfile.TemporaryDirectory() as temp:
            p = Path(temp)
            (p / 'normal_opening_recipe.json').write_text(json.dumps({'seed': 'S7PXV521', 'deck': 'b_red', 'stake': 8}))
            (p / 'normal_seed_selection.json').write_text('{}')
            with self.assertRaises(ValueError):
                module('run_attempt7').arguments(p)

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

    def test_worker_exact_job_policy_and_caps_fail_closed(self):
        worker = module('run_attempt7')
        with tempfile.TemporaryDirectory() as temp:
            p = Path(temp) / 'C07'; p.mkdir()
            policy = {'version': '2.120.0-alpha', 'policy': {'policy_digest': 'a' * 64}}
            (p / 'installed_policy_record.json').write_text(json.dumps(policy))
            good = {'job': 'C07', 'timeout_seconds': 180, 'metadata': {'checkpoint': 320,
                'maximum_actions': 500, 'seed': 'M4BVSY11', 'policy_digest': 'a' * 64, 'installed_version': '2.120.0-alpha'}}
            def put(r):
                (p / 'registration.json').write_text(json.dumps(r))
                h = hashlib.sha256((p / 'registration.json').read_bytes()).hexdigest()
                (p / 'spent.json').write_text(json.dumps({'job': 'C07', 'one_use': True, 'registration_sha256': h}))
            put(good); worker.verify_registration(p)
            for field, value in [('checkpoint', 315), ('maximum_actions', 501), ('seed', 'OTHER'),
                                  ('policy_digest', 'b' * 64), ('installed_version', '2.119.0-alpha')]:
                bad = json.loads(json.dumps(good)); bad['metadata'][field] = value; put(bad)
                with self.assertRaises(ValueError): worker.verify_registration(p)
            for field, value in [('job', 'C06'), ('timeout_seconds', 181)]:
                bad = dict(good); bad[field] = value; put(bad)
                with self.assertRaises(ValueError): worker.verify_registration(p)
            put(good); (p / 'record.json').write_text('{}')
            with self.assertRaises(ValueError): worker.verify_registration(p)

    def test_registration_requires_exact_reviewed_future_files(self):
        source = (HERE / 'register.py').read_text(); ast.parse(source)
        for part in ("record['version'] == '2.120.0-alpha'", "policy['policy_digest'] == expected_digest",
                     "policy['policy_files'].get(name) == expected", "graph['policy_files'] == policy['policy_files']",
                     "validation['policy_unchanged']", "validation['tests_unchanged']", "cycle.register('C07'",
                     "'product_execution_ui_bypassed': True"):
            self.assertIn(part, source)
        features = json.loads((HERE / 'required_features.json').read_text())
        self.assertEqual(features['required_checkpoint'], 320)
        self.assertEqual(set(features['files']), {'Brainstorm/Advisor/growth.lua', 'Brainstorm/Advisor/multi_discard.lua',
            'Brainstorm/Advisor/blind_finishing.lua', 'Brainstorm/Advisor/shop_scoring.lua', 'Brainstorm/Advisor/pack_survival.lua',
            'Brainstorm/UI/game_speed.lua'})
        self.assertNotIn('cycle.run(', source)

    def test_all_python_preparation_parses_without_source_import(self):
        for path in HERE.glob('*.py'):
            ast.parse(path.read_text(), filename=path.name)

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
        for row in json.loads((HERE / 'preparation_origins.json').read_text()):
            self.assertEqual(hashlib.sha256((HERE / row['file']).read_bytes()).hexdigest(), row.get('prepared_sha256', row['source_sha256']))
        changes = [r['file'] for r in json.loads((HERE / 'preparation_origins.json').read_text()) if r['changed']]
        self.assertEqual(changes, ['engine_run.lua', 'policy_wiring.lua'])
        with self.assertRaises(FileNotFoundError):
            module('run_attempt7').verify_registration(HERE)


if __name__ == '__main__':
    unittest.main()
