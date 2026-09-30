from __future__ import annotations
import argparse
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / 'tools/advisor_eval'
sys.path.insert(0, str(TOOLS))
spec = importlib.util.spec_from_file_location('calibration', TOOLS / 'calibrate_policy.py')
C = importlib.util.module_from_spec(spec);spec.loader.exec_module(C)
SOURCE = (ROOT / C.REGISTRY).read_text(encoding='utf-8')


class CalibrationTests(unittest.TestCase):
    def test_registry_defaults_and_roundtrip(self):
        values = C.read_values(SOURCE)
        original_defaults = {'growth_action_cost': 4, 'growth_utility_scale': 1, 'discard_action_penalty': .06}
        self.assertEqual({key: values[key] for key in original_defaults}, original_defaults)
        self.assertEqual(set(values), set(C.registry_spec(SOURCE)['bounds']))
        values['growth_action_cost'] = 2
        rendered = C.apply_values(SOURCE, values)
        self.assertEqual(C.read_values(rendered), values)
        self.assertEqual(SOURCE.split('-- POLICY_WEIGHTS_BEGIN')[0], rendered.split('-- POLICY_WEIGHTS_BEGIN')[0])
        self.assertEqual(SOURCE.split('-- POLICY_WEIGHTS_END')[1], rendered.split('-- POLICY_WEIGHTS_END')[1])

    def test_invalid_values_are_not_silently_defaulted(self):
        for values in ({'unknown': 1}, {'growth_action_cost': True}, {'growth_utility_scale': float('nan')},
                       {'discard_action_penalty': -.01}, {'growth_action_cost': 13}):
            with self.subTest(values=values), self.assertRaises(ValueError):
                C.validate_values(values, complete=False)

    def test_code_and_duplicate_keys_rejected(self):
        for source in (SOURCE.replace('growth_action_cost=4,', 'growth_action_cost=os.execute("bad"),'),
                       SOURCE.replace('growth_action_cost=4,', 'growth_action_cost=4,growth_action_cost=5,'),
                       SOURCE + SOURCE, SOURCE.replace("version='" + C.registry_spec(SOURCE)['version'] + "'", "version='99.0'")):
            with self.subTest(), self.assertRaises(ValueError): C.read_values(source)

    def test_grid_is_bounded_unique_and_applied(self):
        defaults = C.read_values(SOURCE)
        good = {'name': 'less_action_cost', 'values': {'growth_action_cost': 2}}
        self.assertEqual(C.validate_grid([good], defaults)[0]['values']['growth_action_cost'], 2)
        for grid in ([], [good] * 7, [good, good], [{'name': '../escape', 'values': good['values']}],
                     [{'name': 'unchanged', 'values': {}}]):
            with self.subTest(), self.assertRaises(ValueError): C.validate_grid(grid, defaults)

    def make_screen(self):
        temp = tempfile.TemporaryDirectory();self.addCleanup(temp.cleanup);directory = Path(temp.name)
        product = directory / 'source'
        for name in ['Advisor/scoring.lua', 'Advisor/runtime.lua', 'Advisor/search.lua', 'Advisor/growth.lua',
                     'Core/Brainstorm.lua', 'Core/challenge_opening.lua', 'UI/advisor.lua', 'UI/ui.lua',
                     'UI/challenge_opening.lua', 'lovely.toml']:
            file = product / 'Brainstorm' / name;file.parent.mkdir(parents=True, exist_ok=True);file.write_text('-- fixture')
        (product / C.REGISTRY).write_text(SOURCE, encoding='utf-8')
        install = directory / 'install';install.mkdir()
        (install / 'Balatro.exe').write_bytes(b'fixture rules');(install / 'lua51.dll').write_bytes(b'fixture runtime')
        grid = directory / 'grid.json';grid.write_text(json.dumps([{'name': 'less_action_cost', 'values': {'growth_action_cost': 2}}]))
        args = argparse.Namespace(challenges=['c_fragile_1'], seeds=['CALIBRATIONFIXTURE'], wall_budget=45, timeout=20,
                                  output_dir=directory / 'screen', policy_root=product, grid=grid, install=install,
                                  full_episode=False, stop_after_step=3, retry_overhead_seconds=2, execute=False)
        with patch.object(C, 'activation_check'): C.initialize(args)
        return args.output_dir

    def test_registration_freezes_only_numeric_candidate_changes(self):
        directory = self.make_screen()
        with patch.object(C, 'activation_check'):
            screen = C.verify(directory);report = C.summarize(directory)
        self.assertEqual(screen['default_values']['growth_action_cost'], 4)
        self.assertEqual(C.read_values((directory / 'pairs/less_action_cost/candidate' / C.REGISTRY).read_text())['growth_action_cost'], 2)
        self.assertFalse(report['promotion_allowed']);self.assertIsNone(report['recommended_policy'])
        self.assertIn('missing_attempts', report['candidates'][0]['blockers'])
        self.assertIsNone(report['candidates'][0]['diagnostic_sum_challenge_retry_proxy_delta_seconds'])

    def test_default_registry_and_live_source_not_changed(self):
        directory = self.make_screen()
        for root in (directory / 'baseline', directory.parent / 'source'):
            self.assertEqual((root / C.REGISTRY).read_text(encoding='utf-8'), SOURCE)

    def test_registered_sources_and_screen_are_immutable(self):
        directory = self.make_screen()
        (directory / 'baseline' / C.REGISTRY).write_text(SOURCE + '-- mutated')
        with self.assertRaisesRegex(ValueError, 'baseline changed'): C.verify(directory)
        directory = self.make_screen()
        screen = json.loads((directory / 'screen.json').read_text());screen['wall_budget_seconds'] = 999
        C.paired.write_json(directory / 'screen.json', screen)
        with self.assertRaisesRegex(ValueError, 'screen changed'): C.verify(directory)

    def test_cannot_execute_unapproved_registration(self):
        directory = self.make_screen()
        with patch.object(C, 'activation_check'), self.assertRaisesRegex(ValueError, 'without execution'):
            C.execute(directory)

    def test_activation_checks_real_module_wiring(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary);(directory / 'Brainstorm/Advisor').mkdir(parents=True)
            for filename in ('runtime.lua', 'search.lua', 'growth.lua'):
                (directory / 'Brainstorm/Advisor' / filename).write_text('-- policy_weights')
            (directory / 'engine_run.lua').write_text('-- probe_policy_policy_weights')
            with self.assertRaisesRegex(ValueError, 'not activated'): C.activation_check(directory, directory)
            (directory / 'Brainstorm/Advisor/growth.lua').write_text('policy_weights growth_action_cost growth_utility_scale')
            (directory / 'Brainstorm/Advisor/search.lua').write_text('policy_weights discard_action_penalty')
            C.activation_check(directory, directory)

    def test_terminal_diagnostics_still_cannot_promote(self):
        directory = self.make_screen();pair = directory / 'pairs/less_action_cost'
        manifest = C.paired.verify_manifest(pair);request = manifest['requests'][0]
        records = []
        for role, elapsed in [('incumbent', 10), ('candidate', 8)]:
            provenance = {'type': 'engine_probe_provenance', 'validation': 'experimental', **request,
                          **{key: manifest[key] for key in ('rules_digest', 'runtime_digest', 'adapter_digest', 'start_distribution',
                                                           'retry_context_spec', 'retry_context_spec_digest')},
                          **manifest['policies'][role], 'opening_policy_loaded': False}
            from engine_probe import retry_context_record
            rows = [provenance, retry_context_record(),
                    {'type': 'engine_probe_profile', 'unlock_profile_digest': 'same', 'qualification_compatible': False},
                    {'type': 'engine_episode_terminal', 'outcome': 'win', 'game_won': True, 'ante': 8,
                     'source_profile_completed': True, 'source_game_won': True, 'game_over': False}]
            trace = pair / (role + '.log');trace.write_text('\n'.join(json.dumps(row) for row in rows))
            record = C.paired.episode_record(trace, request['challenge'], request['seed'], 0, elapsed,
                                           C.paired.command_for(pair, manifest, role, request))
            record.update({'pair_index': 0, 'role': role});records.append(record)
        (pair / 'episodes.jsonl').write_text('\n'.join(json.dumps(record) for record in records))
        with patch.object(C, 'activation_check'): report = C.summarize(directory)
        self.assertEqual(report['candidates'][0]['diagnostic_sum_challenge_retry_proxy_delta_seconds'], -2)
        self.assertFalse(report['promotion_allowed']);self.assertIsNone(report['recommended_policy'])
        self.assertIsNone(report['candidates'][0]['qualified_win_rate'])


if __name__ == '__main__':
    unittest.main()
