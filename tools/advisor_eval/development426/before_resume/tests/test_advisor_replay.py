"""Replay admission rejects stale products and incomplete or altered contracts."""
import copy
from argparse import Namespace
import json
from pathlib import Path
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parents[1] / 'tools' / 'advisor_eval'
sys.path.insert(0, str(HERE))
import engine_probe as E
import decision_replay as D


class VerifiedReplayTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        source = self.root / 'Brainstorm' / 'Advisor'
        source.mkdir(parents=True)
        (source / 'decision.lua').write_text('return {}')
        (source / 'snapshot.lua').write_text('return {}')
        for name in ('Core/Brainstorm.lua', 'Core/challenge_opening.lua', 'UI/advisor.lua',
                     'UI/ui.lua', 'UI/challenge_opening.lua', 'lovely.toml'):
            target = self.root / 'Brainstorm' / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text('-- fixture')
        self.trace = self.root / 'trace.log'
        self.provenance = {'rules_digest': 'rules', 'runtime_digest': 'runtime', 'adapter_digest': 'adapter'}
        hashes = E.policy_hashes(self.root)
        self.rows = [
            {'type': 'engine_probe_provenance', **self.provenance, 'challenge': 'fixture', 'seed': 'S',
             'start_distribution': E.ORDINARY_START, 'opening_policy_loaded': False,
             'policy_files': hashes, 'policy_digest': E.digest(hashes)},
            {'type': 'engine_probe_profile', 'unlock_profile_digest': 'c' * 64},
            {'type': 'engine_episode_action', 'step': 1, 'phase': 'hand', 'action': {'kind': 'play', 'indices': [1]},
             'state_fingerprint': 'a' * 64, 'fingerprint_schema': 'source_decision_v1',
             'score_prediction': {'score': 100, 'uncertain': False, 'reliable_bound': False}},
            {'type': 'engine_episode_resolved', 'step': 1, 'state_fingerprint': 'b' * 64},
            {'type': 'engine_episode_checkpoint', 'step': 2, 'phase': 'shop',
             'state_fingerprint': 'd' * 64, 'fingerprint_schema': 'source_decision_v1'},
        ]

    def admit(self):
        self.trace.write_text('\n'.join(json.dumps(row) for row in self.rows), encoding='utf-8')
        return E.verified_replay(self.trace, self.root, self.provenance, 'fixture', 'S', 2)

    def test_complete_prefix_and_checkpoint_are_retained(self):
        admitted = self.admit()
        self.assertEqual(admitted['prefix'][1]['before']['action']['kind'], 'play')
        self.assertEqual(admitted['prefix'][1]['after']['state_fingerprint'], 'b' * 64)
        self.assertEqual(admitted['checkpoint']['phase'], 'shop')
        self.assertEqual(admitted['source_adapter_digest'], 'adapter')
        self.assertEqual(len(admitted['source_snapshot_digest']), 64)

    def test_every_provenance_dimension_is_checked(self):
        for key in ('rules_digest', 'runtime_digest', 'adapter_digest', 'seed', 'challenge', 'policy_digest'):
            with self.subTest(key=key):
                original = self.rows[0][key]
                self.rows[0][key] = 'changed'
                with self.assertRaises(ValueError): self.admit()
                self.rows[0][key] = original

    def test_source_policy_mutation_is_rejected(self):
        (self.root / 'Brainstorm' / 'Advisor' / 'decision.lua').write_text('return {changed=true}')
        with self.assertRaisesRegex(ValueError, 'policy'): self.admit()

    def test_missing_resolved_step_and_prediction_rejected(self):
        self.rows[2].pop('score_prediction')
        with self.assertRaisesRegex(ValueError, 'prediction'): self.admit()
        self.rows.pop(3)
        with self.assertRaisesRegex(ValueError, 'incomplete'): self.admit()

    def test_legacy_fingerprintless_and_missing_checkpoint_rejected(self):
        self.rows[2].pop('state_fingerprint')
        with self.assertRaisesRegex(ValueError, 'fingerprint'): self.admit()
        self.rows.pop()
        with self.assertRaisesRegex(ValueError, 'checkpoint'): self.admit()

    def test_duplicate_actions_and_provenance_rejected(self):
        self.rows.append(copy.deepcopy(self.rows[2]))
        with self.assertRaisesRegex(ValueError, 'duplicate'): self.admit()
        self.rows.append(copy.deepcopy(self.rows[0]))
        with self.assertRaisesRegex(ValueError, 'one engine_probe_provenance'): self.admit()

    def test_counterfactual_source_is_explicitly_ineligible(self):
        self.rows[0]['counterfactual'] = True
        with self.assertRaisesRegex(ValueError, 'recorded policy'): self.admit()

    def test_boundaries_require_integers_and_actual_checkpoint(self):
        self.admit()
        for boundary in (True, 0, 1.5, 501):
            with self.assertRaises(ValueError):
                E.verified_replay(self.trace, self.root, self.provenance, 'fixture', 'S', boundary)


class DecisionReplayAuditTests(unittest.TestCase):
    def setUp(self):
        VerifiedReplayTests.setUp(self)
        install = self.root / 'install'
        install.mkdir()
        (install / 'Balatro.exe').write_bytes(b'fixture rules')
        (install / 'lua51.dll').write_bytes(b'fixture runtime')
        self.rows[0].update(challenge='c_golden_needle_1',
            rules_digest=D.paired.file_digest(install / 'Balatro.exe'),
            runtime_digest=D.paired.file_digest(install / 'lua51.dll'),
            adapter_digest=D.paired.digest({name: D.paired.file_digest(HERE / name) for name in D.paired.ADAPTER_FILES}))
        self.trace.write_text('\n'.join(json.dumps(row) for row in self.rows), encoding='utf-8')
        self.output = self.root / 'comparison'
        self.args = Namespace(source_trace=self.trace, source_policy_root=self.root, candidate_root=self.root,
                              step=2, output_dir=self.output, install=install, timeout=5, wall_budget=15,
                              full_episode=False, evaluate_prefix=False, execute=False)

    def test_register_and_audit_keep_unexecuted_requests_missing(self):
        report = D.run(self.args)
        self.assertFalse(report['matched_checkpoint'])
        self.assertEqual({row['outcome'] for row in report['requests'].values()}, {'missing'})
        self.assertEqual(D.audit(self.output)['commands'], report['commands'])

    def test_changed_registration_rejected(self):
        D.run(self.args)
        path = self.output / 'decision_registration.json'
        registration = json.loads(path.read_text())
        registration['boundary_step'] = 1
        path.write_text(json.dumps(registration))
        with self.assertRaisesRegex(ValueError, 'registration'): D.audit(self.output)

    def test_changed_trace_and_frozen_candidate_rejected(self):
        D.run(self.args)
        path = self.output / 'source.log';original = path.read_bytes()
        path.write_bytes(original + b'\n')
        with self.assertRaisesRegex(ValueError, 'trace changed'): D.audit(self.output)
        path.write_bytes(original)
        (self.output / 'candidate' / 'Brainstorm' / 'Advisor' / 'decision.lua').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'Frozen product'): D.audit(self.output)


if __name__ == '__main__':
    unittest.main()
