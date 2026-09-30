"""Pure source-option validation. No source ZIP/runtime/profile access."""
import ast
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('gold_objective_spec_tested', HERE / 'gold_objective_spec.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class GoldObjectiveSpec(unittest.TestCase):
    def options(self, **changes):
        args = dict(gold_objective='synthetic_fresh_all_missing_v1', episode=True,
                    deck='b_red', stake=8, unlock_profile='all_unlocked_discovered_v1',
                    normal_filter_recipe=Path('declared_recipe.json'),
                    seed_selection_evidence=Path('declared_selection.json'))
        args.update(changes)
        return SimpleNamespace(**args)

    def test_default_off_without_other_fields(self):
        record = module.build(SimpleNamespace())
        self.assertEqual(record['mode'], 'off')
        self.assertIs(record['enabled'], False)
        self.assertIs(record['actual_player_profile'], False)

    def test_explicit_off_has_no_population_claim(self):
        self.assertNotIn('initial_counts', module.build(SimpleNamespace(gold_objective='off')))

    def test_fresh_red_and_zodiac_have_no_invented_wins(self):
        for deck in ('b_red', 'b_zodiac'):
            record = module.build(self.options(deck=deck))
            self.assertEqual(record['initial_counts'], dict(total=150, complete=0, missing=150, unknown=0))
            self.assertEqual(record['initial_history'], 'natural_empty_loaded_joker_usage')
            self.assertIs(record['actual_player_profile'], False)
            self.assertIs(record['qualification'], False)

    def test_unknown_modes_rejected(self):
        for value in ('player', '', True, False, None, 'all_missing'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                module.build(self.options(gold_objective=value))

    def test_unregistered_profile_route_and_modes_rejected(self):
        for field, value in [('episode', False), ('deck', None), ('deck', 'b_blue'),
                             ('stake', 1), ('stake', True), ('stake', 8.0),
                             ('unlock_profile', 'source_defaults_v1'),
                             ('normal_filter_recipe', None), ('seed_selection_evidence', None),
                             ('replay_trace', Path('old_trace')), ('override', Path('override')),
                             ('test_scenario', 'terminal_win_final'), ('profile_only', True),
                             ('jokerless_opening_recipe', Path('old_recipe')), ('opening_targets', 'x')]:
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                module.build(self.options(**{field: value}))

    def test_affected_copy_parses_and_declares_all_new_provenance(self):
        source = (HERE / 'engine_probe.py').read_text(encoding='utf-8')
        ast.parse(source)
        self.assertIn('default="off"', source)
        self.assertIn("provenance['gold_objective_spec'] = objective_spec", source)
        self.assertIn("provenance['gold_objective_spec_digest'] = digest(objective_spec)", source)
        self.assertIn('"gold_objective_spec.py", "gold_objective_context.lua"', source)
        self.assertLess(source.index('objective_spec = gold_objective_spec(args)'), source.index('with zipfile.ZipFile(executable)'))
        lua = (HERE / 'engine_run.lua').read_text(encoding='utf-8')
        self.assertIn("PROBE_GOLD_OBJECTIVE.enabled then modules.gold_goal=require('probe_policy_gold_goal')", lua)
        self.assertLess(lua.index('G.GAME.used_filter=true;G.GAME.seeded=false'), lua.index("require('probe_gold_objective_context').attach"))
        self.assertLess(lua.index("require('probe_gold_objective_context').attach"), lua.index('decision.run(s,modules)'))


if __name__ == '__main__':
    unittest.main()
