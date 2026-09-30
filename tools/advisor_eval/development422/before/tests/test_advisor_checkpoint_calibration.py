from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/advisor_eval'))
import checkpoint_calibration as C
import engine_probe as E
import qualify_source_profiles as Q


def point(kind='shop', action=None):
    return {'type': 'engine_episode_checkpoint', 'step': 2, 'phase': kind,
            'snapshot': {'shop_jokers': [{'key': 'j_joker'}]}, 'result': {'shop_diagnostics': {'metrics': {'paired_comparisons': 1}}},
            'action': action or {'kind': 'leave_shop'}, 'fingerprint_schema': 'source_decision_v1',
            'state_fingerprint': 'b' * 64}


class CheckpointCalibrationTests(unittest.TestCase):
    def test_opening_prefix_is_rejected_before_spending_a_probe_budget(self):
        for row in (point('blind_select'), {**point(), 'snapshot': {}},
                    {**point(), 'type': 'engine_episode_action'}, {**point(), 'result': None}):
            with self.subTest(row=row), self.assertRaises(ValueError):
                C.meaningful_checkpoint([row], 2)

    def test_observed_rejected_growth_and_real_shop_are_eligible(self):
        self.assertEqual(C.meaningful_checkpoint([point()], 2), 'shop')
        growth = {**point('hand'), 'result': {'growth_diagnostics': {'reason': 'action_cost'}}}
        self.assertEqual(C.meaningful_checkpoint([growth], 2), 'growth')
        self.assertEqual(C.meaningful_checkpoint([point(action={'kind': 'reroll'})], 2), 'reroll')

    def test_uncertain_or_truncated_comparisons_are_not_tuned(self):
        for result in ({'uncertain': True}, {'truncated': True}, {'shop_diagnostics': {'truncated': True}}):
            with self.subTest(result=result), self.assertRaises(ValueError):
                C.meaningful_checkpoint([{**point(), 'result': result}], 2)
        pack = {**point('pack'), 'snapshot': {'pack_cards': [1, 2]}, 'result': {'pack_diagnostics': {'tactical_fallback': True}}}
        with self.assertRaises(ValueError): C.meaningful_checkpoint([pack], 2)

    def test_changed_action_is_only_sensitivity_never_a_win(self):
        report = {'matched_checkpoint': True, 'actions_differ': True,
                  'requests': {role: {'checkpoint': point()} for role in ('incumbent', 'candidate')}}
        self.assertEqual(C.classify_pair(report), 'action_sensitive')
        report['actions_differ'] = False
        self.assertEqual(C.classify_pair(report), 'action_insensitive')
        report['matched_checkpoint'] = False
        self.assertEqual(C.classify_pair(report), 'unresolved')

    def test_explicit_nonzero_effect_counters_override_weak_legacy_opportunities(self):
        checkpoint = point()
        self.assertIn('shop_scoring_gain_weight', C.coefficient_opportunities(checkpoint))
        checkpoint['result']['shop_diagnostics']['metrics']['coefficient_opportunities'] = {
            'shop_scoring_gain_weight': 2, 'computation_cost_scale': 0}
        self.assertIn('shop_scoring_gain_weight', C.coefficient_opportunities(checkpoint))
        self.assertNotIn('computation_cost_scale', C.coefficient_opportunities(checkpoint))
        checkpoint['result']['shop_diagnostics']['metrics']['paired_comparisons'] = 0
        checkpoint['result']['shop_diagnostics']['metrics'].pop('coefficient_opportunities')
        self.assertEqual(C.coefficient_opportunities(checkpoint), [])

    def make_screen(self):
        temporary = tempfile.TemporaryDirectory();self.addCleanup(temporary.cleanup)
        root = Path(temporary.name);product = root / 'source'
        for name in ['Advisor/scoring.lua', 'Advisor/runtime.lua', 'Advisor/search.lua', 'Advisor/growth.lua',
                     'Advisor/snapshot.lua', 'Core/Brainstorm.lua', 'Core/challenge_opening.lua', 'UI/advisor.lua',
                     'UI/ui.lua', 'UI/challenge_opening.lua', 'lovely.toml']:
            target = product / 'Brainstorm' / name;target.parent.mkdir(parents=True, exist_ok=True);target.write_text('-- fixture')
        registry = (ROOT / C.coefficients.REGISTRY).read_text(encoding='utf-8')
        (product / C.coefficients.REGISTRY).write_text(registry, encoding='utf-8')
        install = root / 'install';install.mkdir()
        (install / 'Balatro.exe').write_bytes(b'fixture rules');(install / 'lua51.dll').write_bytes(b'fixture runtime')
        hashes = C.paired.policy_hashes(product)
        spec = E.profile_spec(E.PROFILE_NAMES[0])
        origin = {'type': 'engine_probe_provenance', 'challenge': 'c_golden_needle_1', 'seed': 'CHECKPOINTFIXTURE',
                  'policy_files': hashes, 'policy_digest': C.paired.digest(hashes),
                  'rules_digest': C.paired.file_digest(install / 'Balatro.exe'),
                  'runtime_digest': C.paired.file_digest(install / 'lua51.dll'),
                  'adapter_digest': C.paired.digest({n: C.paired.file_digest(C.paired.HERE / n) for n in C.paired.ADAPTER_FILES}),
                  'start_distribution': E.ORDINARY_START, 'opening_policy_loaded': False,
                  'profile_spec': spec, 'profile_spec_digest': E.digest(spec)}
        profile = E.profile_record(spec['name'], b'P_BLINDS:bl_fixture:nil:false\nP_CENTERS:j_fixture:true:false\nP_SEALS:Red:nil:false\nP_TAGS:tag_fixture:nil:false')
        before = {'type': 'engine_episode_action', 'step': 1, 'phase': 'blind_select', 'action': {'kind': 'select_blind'},
                  'state_fingerprint': 'a' * 64, 'fingerprint_schema': 'source_decision_v1'}
        rows = [origin, profile, before, {'type': 'engine_episode_resolved', 'step': 1, 'state_fingerprint': 'b' * 64}, point()]
        trace = root / 'source.log';trace.write_text('\n'.join(json.dumps(row) for row in rows))
        cases = root / 'cases.json';cases.write_text(json.dumps([{'name': 'shop', 'trace': str(trace), 'step': 2, 'split': 'development'}]))
        grid = root / 'grid.json';grid.write_text(json.dumps([{'name': 'cost', 'values': {'shop_scoring_gain_weight': 1.5}}]))
        args = argparse.Namespace(policy_root=product, install=install, grid=grid, checkpoints=cases,
                                  output_dir=root / 'screen', timeout=5, wall_budget=15, execute=False)
        return args, rows

    def test_numeric_screen_preserves_source_and_declares_profile(self):
        args, _ = self.make_screen()
        with patch.object(C.coefficients, 'activation_check'):
            screen = C.initialize(args);report = C.audit(args.output_dir)
        self.assertEqual(screen['pairs'][0]['candidate'], 'cost')
        self.assertEqual(report['candidates'][0]['status'], 'incomplete')
        self.assertIsNone(report['recommended_policy']);self.assertFalse(report['promotion_allowed'])
        manifest = C.paired.verify_manifest(Path(screen['pairs'][0]['directory']))
        self.assertEqual(manifest['profile_spec']['name'], E.PROFILE_NAMES[0])
        self.assertEqual(C.coefficients.read_values((args.policy_root / C.coefficients.REGISTRY).read_text())['growth_action_cost'], 4)

    def test_holdout_cannot_reuse_development_trajectory(self):
        args, _ = self.make_screen();cases = json.loads(args.checkpoints.read_text())
        cases.append({**cases[0], 'name': 'holdout', 'split': 'holdout'})
        args.checkpoints.write_text(json.dumps(cases))
        baseline = {'policy_files': C.paired.policy_hashes(args.policy_root)}
        baseline['policy_digest'] = C.paired.digest(baseline['policy_files'])
        with self.assertRaisesRegex(ValueError, 'cannot reuse'): C.source_cases(args.checkpoints, baseline)

    def test_screen_tampering_and_unrequested_execution_are_rejected(self):
        args, _ = self.make_screen()
        with patch.object(C.coefficients, 'activation_check'):
            C.initialize(args)
            with self.assertRaisesRegex(ValueError, 'without execution'): C.execute(args.output_dir)
            manifest = args.output_dir / 'checkpoint_screen.json'
            data = json.loads(manifest.read_text());data['wall_budget_seconds'] = 999
            manifest.write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError, 'screen changed'): C.audit(args.output_dir)

    def test_new_registry_schema_uses_declared_bounds_and_keeps_defaults(self):
        source = (ROOT / C.coefficients.REGISTRY).read_text()
        source = source.replace("schema=1,version='1.0'", "schema=2,version='2.0'")
        source = source.replace('local bounds={', 'local bounds={example_cost={0,2},', 1)
        source = source.replace('local VALUES={', 'local VALUES={\n  example_cost=1,', 1)
        spec, values = C.coefficients.registry_spec(source), C.coefficients.read_values(source)
        self.assertEqual(spec['schema'], 2)
        rendered = C.coefficients.apply_values(source, {**values, 'example_cost': .5})
        self.assertEqual(C.coefficients.read_values(rendered)['example_cost'], .5)
        with self.assertRaises(ValueError): C.coefficients.apply_values(source, {**values, 'example_cost': 3})


class SourceProfileTests(unittest.TestCase):
    def test_explicit_profiles_do_not_claim_a_user_population(self):
        for name in E.PROFILE_NAMES:
            spec = E.profile_spec(name)
            self.assertFalse(spec['user_profile']);self.assertFalse(spec['qualification_compatible'])
            self.assertEqual(set(spec['scope']), {'P_CENTERS', 'P_TAGS', 'P_SEALS', 'P_BLINDS'})
        with self.assertRaises(ValueError): E.profile_spec('user_profile')

    def test_durable_inventory_checks_all_flags_and_digest(self):
        raw = b'P_BLINDS:bl_fixture:true:true\nP_CENTERS:j_fixture:true:true\nP_SEALS:Red:true:true\nP_TAGS:tag_fixture:true:true'
        report = E.profile_record(E.PROFILE_NAMES[1], raw)
        self.assertTrue(report['emitted_before_episode']);self.assertTrue(report['declared_scope_verified'])
        self.assertEqual(len(report['inventory']), 4)
        with self.assertRaisesRegex(ValueError, 'not applied'):
            E.profile_record(E.PROFILE_NAMES[1], raw.replace(b'true:true', b'false:true'))

    def test_corrupt_duplicate_or_unsorted_profile_inventory_is_rejected(self):
        for raw in (b'', b'P_TAGS:x:maybe:false', b'unknown:x:true:true',
                    b'P_TAGS:x:true:true\nP_TAGS:x:true:true', b'P_TAGS:z:true:true\nP_TAGS:a:true:true'):
            with self.subTest(raw=raw), self.assertRaises(ValueError): E.profile_record(E.PROFILE_NAMES[0], raw)

    def test_profile_qualification_keeps_adapter_and_user_gates_closed(self):
        default = b'P_BLINDS:bl_fixture:nil:false\nP_CENTERS:j_fixture:false:false\nP_SEALS:Red:nil:false\nP_TAGS:tag_fixture:nil:false'
        full = default.replace(b'nil:false', b'true:true').replace(b'false:false', b'true:true')
        records = {name: {'outcome': 'passed', 'profile': E.profile_record(name, text)}
                   for name, text in zip(E.PROFILE_NAMES, (default, full))}
        report = Q.assess(records, {'j_fixture': False})
        self.assertTrue(report['declared_profile_qualified'])
        self.assertFalse(report['episode_adapter_qualified']);self.assertFalse(report['user_profile_qualified'])
        self.assertIsNone(report['qualified_win_rate'])
        self.assertFalse(Q.assess(records, {'j_fixture': True})['declared_profile_qualified'])

    def test_profile_timeout_or_inventory_tampering_cannot_qualify(self):
        self.assertFalse(Q.assess({}, {'j_fixture': False})['declared_profile_qualified'])
        raw = b'P_BLINDS:bl_fixture:true:true\nP_CENTERS:j_fixture:true:true\nP_SEALS:Red:true:true\nP_TAGS:tag_fixture:true:true'
        profile = E.profile_record(E.PROFILE_NAMES[1], raw)
        profile['unlock_profile_digest'] = 'wrong'
        records = {E.PROFILE_NAMES[1]: {'outcome': 'passed', 'profile': profile}}
        self.assertFalse(Q.assess(records, {'j_fixture': False})['declared_profile_qualified'])


if __name__ == '__main__':
    unittest.main()
