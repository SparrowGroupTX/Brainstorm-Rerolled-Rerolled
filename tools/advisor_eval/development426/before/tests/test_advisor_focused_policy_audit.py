"""Prospective development registration and existing one-use executor admission."""
import argparse
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parents[1] / 'tools/advisor_eval'
sys.path.insert(0, str(HERE))
import focused_policy_audit as F


class FocusedPolicyAuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name); self.install = self.root / 'install'; self.install.mkdir()
        (self.install / 'Balatro.exe').write_bytes(b'fixture source never executed')
        (self.install / 'lua51.dll').write_bytes(b'fixture runtime never loaded')
        self.policy = self.root / 'product'
        for name in ('Advisor/snapshot.lua', 'Core/Brainstorm.lua', 'Core/challenge_opening.lua',
                     'UI/advisor.lua', 'UI/ui.lua', 'UI/challenge_opening.lua', 'lovely.toml'):
            path = self.policy / 'Brainstorm' / name; path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('return {}')
        self.args = argparse.Namespace(output=self.root/'out', incumbent=self.policy, candidate=self.policy,
            install=self.install, challenges=['c_knife_1','c_jokerless_1'], action_seconds=1.5,
            retry_seconds=5, unlock_profile='all_unlocked_discovered_v1')

    def register(self):
        with patch.object(F.paired, 'collect') as collect:
            value = F.initialize(self.args); collect.assert_not_called()
        return value

    def test_prospective_registration_freezes_two_development_requests_and_all_auditors(self):
        registration = self.register(); checked, manifest = F.verify(self.args.output)
        self.assertEqual(registration, checked)
        self.assertEqual({r['split'] for r in registration['requests']}, {'development'})
        self.assertEqual([r['challenge'] for r in registration['requests']], self.args.challenges)
        self.assertTrue(all(len(r['seed']) == 8 and r['seed'].isalnum() for r in registration['requests']))
        self.assertEqual(manifest['timeout_seconds'], 80); self.assertIsNone(manifest['action_limit'])
        self.assertEqual(registration['wall_budget_seconds'], 340)
        self.assertFalse((self.args.output / 'outcome_execution_started.json').exists())
        self.assertIn('focused_policy_audit.py', registration['auditor_files'])

    def test_unknown_duplicate_or_wrong_request_count_rejected_before_creation(self):
        for challenges in (['c_knife_1'], ['c_knife_1','c_knife_1'], ['c_knife_1','missing']):
            with self.subTest(challenges=challenges), self.assertRaises(ValueError):
                F.fresh_requests(challenges)
        self.assertFalse(self.args.output.exists())

    def test_registration_and_worker_budget_cannot_be_reused_or_expanded(self):
        registration = self.register()
        with self.assertRaises(FileExistsError): F.initialize(self.args)
        registration['wall_budget_seconds'] = 341
        unsigned = dict(registration); unsigned.pop('registration_digest')
        registration['registration_digest'] = F.paired.digest(unsigned)
        F.paired.write_json(self.args.output/'outcome_registration.json', registration)
        with self.assertRaisesRegex(ValueError, 'caps'): F.verify(self.args.output)

    def test_frozen_auditor_tamper_prevents_execution_without_worker(self):
        self.register(); path=self.args.output/'auditors/focused_policy_audit.py'
        path.write_bytes(path.read_bytes()+b' ')
        with patch.object(F.paired, 'collect') as collect, self.assertRaises(ValueError):
            F.execute(self.args.output)
        collect.assert_not_called()

    def test_missing_attempts_remain_four_missing_development_records(self):
        self.register(); report=F.audit(self.args.output)
        self.assertEqual(report['requested_attempts'], 4)
        self.assertEqual(len(report['missing_attempts']), 4)
        self.assertEqual(report['recorded_attempts'], 0)
        self.assertEqual({r['split'] for r in report['cohorts']}, {'development'})
        self.assertEqual(report['holdout_requests'], 0)
        self.assertFalse(report['qualification']); self.assertFalse(report['promotion_allowed'])

    def test_existing_executor_spends_only_four_workers_once_and_preserves_errors(self):
        self.register(); calls=[]
        def collect(command, trace, request, timeout):
            calls.append((trace.name,timeout))
            return {**request,'outcome':'unsupported','reason':'fixture unresolved','elapsed_seconds':0.01}
        report={'limitations':[],'requested_attempts':4,'recorded_attempts':4,'audit_errors':[]}
        with patch.object(F.paired,'collect',side_effect=collect), patch.object(F.outcome,'audit',return_value=report):
            actual=F.execute(self.args.output)
            with self.assertRaises(FileExistsError): F.execute(self.args.output)
        self.assertEqual(calls,[('000_incumbent.log',80),('000_candidate.log',80),
                                ('001_candidate.log',80),('001_incumbent.log',80)])
        rows=[json.loads(line) for line in (self.args.output/'episodes.jsonl').read_text().splitlines()]
        self.assertEqual(len(rows),4);self.assertTrue(all(r['outcome']=='unsupported' for r in rows))
        self.assertEqual(actual['holdout_requests'],0)


if __name__ == '__main__':
    unittest.main()
