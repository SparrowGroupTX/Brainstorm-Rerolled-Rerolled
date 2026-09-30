"""Pure M22 preparation tests, no captured policy decisions or registration."""
from copy import deepcopy
from pathlib import Path
import hashlib
import json
import unittest
from unittest.mock import patch
import compare_copy22 as worker
import prepare_inputs
import register
from lua_bytes import literal, lua_value

HERE = Path(__file__).resolve().parent


def result():
    action = {'kind': 'reorder_jokers', 'order': [2, 1, 3]}
    return {'status': 'complete', 'input_unchanged': True, 'input_fingerprint': 'synthetic',
            'action': action, 'score_calls': 30, 'decision_wall_seconds': 0.25,
            'result': {'action': deepcopy(action), 'evaluations': 30}}


class SpecTests(unittest.TestCase):
    def test_actions_counts_and_diagnostics_may_differ(self):
        a, b = result(), result()
        b['action']['area'] = 'jokers'
        b['score_calls'] = b['result']['evaluations'] = 15
        b['result']['copy_preflight'] = {'complete': True}
        b['result']['reorder_only'] = True
        pair = worker.compare_pair(a, b)
        self.assertFalse(pair['raw_actions_equal'])
        self.assertTrue(pair['physical_actions_equal'])
        self.assertEqual(pair['score_call_delta'], -15)
        self.assertTrue(pair['candidate_reorder_only'])
        b['action']['order'] = [3, 1, 2]
        self.assertFalse(worker.compare_pair(a, b)['physical_actions_equal'])

    def test_input_and_completion_must_match(self):
        for mutation in ('status', 'input_unchanged', 'input_fingerprint'):
            a, b = result(), result()
            b[mutation] = False
            with self.assertRaises(ValueError):
                worker.compare_pair(a, b)

    def test_action_checks_are_structural_and_limited(self):
        snapshot = {'jokers': [{}, {}, {'pinned': True}]}
        self.assertEqual(worker.structural_action(result()['action'], snapshot)['status'], 'valid_permutation_and_pins')
        for order in ([2, 1], [2, 2, 3], [1, 3, 2], [True, 2, 3]):
            with self.assertRaises(ValueError):
                worker.structural_action({'kind': 'reorder_jokers', 'order': order}, snapshot)
        self.assertEqual(worker.structural_action({'kind': 'play', 'indices': [1]}, snapshot)['status'], 'not_qualified')

    def test_fixed_caps_and_nonexecution_guard(self):
        self.assertEqual(worker.ORDER, (('baseline', 31), ('candidate', 31), ('candidate', 96), ('baseline', 96)))
        self.assertEqual((worker.CAP, worker.TOTAL_CAP), (140000, 560000))
        with self.assertRaises(FileNotFoundError): worker.verify(HERE)
        files, metadata, external = register.plan()
        self.assertTrue(all(p.is_file() for p in files.values()))
        self.assertFalse(metadata['source_execution'])
        self.assertFalse(metadata['action_dispatch'])
        self.assertEqual(metadata['maximum_decisions'], 4)
        self.assertEqual(len(external), 2)

    def test_whole_policy_records_and_unchanged_cache(self):
        a, b = [json.loads((HERE / (role + '_record.json')).read_text())['policy'] for role in ('baseline', 'candidate')]
        self.assertEqual(a['policy_digest'], prepare_inputs.DIGESTS['baseline'])
        self.assertEqual(b['policy_digest'], prepare_inputs.DIGESTS['candidate'])
        self.assertEqual(a['policy_files']['Brainstorm/Advisor/score_cache.lua'], b['policy_files']['Brainstorm/Advisor/score_cache.lua'])
        self.assertEqual(set(b['policy_files']) - set(a['policy_files']), {'Brainstorm/Advisor/hand_copy_preflight.lua'})
        changed = {k for k in a['policy_files'] if a['policy_files'][k] != b['policy_files'][k]}
        self.assertEqual(changed, {'Brainstorm/Advisor/decision.lua', 'Brainstorm/Advisor/search.lua',
            'Brainstorm/Advisor/runtime.lua', 'Brainstorm/Core/Brainstorm.lua', 'Brainstorm/steamodded_compat.lua'})

    def test_runtime_graph_derived_exactly_per_role(self):
        provenance = json.loads((HERE / 'input_provenance.json').read_text())
        for role, directory in prepare_inputs.ROLES.items():
            raw = (prepare_inputs.RUNS / directory / 'policy/Brainstorm/Advisor/runtime.lua').read_bytes()
            expected, omitted = prepare_inputs.module_setup(raw)
            prefix = (HERE / (role + '_module_setup.lua')).read_bytes()
            self.assertEqual(prefix, expected)
            self.assertEqual(len(omitted), 5)
            self.assertEqual(hashlib.sha256(prefix).hexdigest(), provenance['module_setups'][role]['derived_setup_sha256'])
            for connection in (b'A.snapshot.perkeo_inventory = A.perkeo_inventory',
                 b'A.strategy.pack_survival = A.pack_survival', b'A.blind_finishing.pack_survival=A.pack_survival',
                 b'A.shop_scoring.bell_opening=A.bell_opening', b'A.snapshot.certificate=A.certificate'):
                self.assertIn(connection, prefix)
            self.assertEqual(b"A.hand_copy_preflight = module('hand_copy_preflight')" in prefix, role == 'candidate')

    def test_static_snapshot_receipts_only(self):
        p = json.loads((HERE / 'input_provenance.json').read_text())
        for step in (31, 96):
            path = HERE / f'step{step}.json'
            snapshot = json.loads(path.read_text())['snapshot']
            origin = p['snapshots'][str(step)]
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), origin['snapshot_file_sha256'])
            self.assertEqual(hashlib.sha256(prepare_inputs.canonical(snapshot)).hexdigest(), origin['snapshot_canonical_sha256'])
            self.assertEqual(len(snapshot['hand']), 8)
            self.assertEqual(snapshot['jokers'][0]['key'], 'j_perkeo')
        self.assertFalse(p['captured_policy_evaluated'])

    def test_compile_safe_encoding(self):
        encoded = literal(('ordinary source\r\n' * 4000).encode())
        self.assertNotIn(b'..', encoded)
        self.assertIn(b'\\013\\010', encoded)
        with self.assertRaises(ValueError): lua_value(float('nan'))

    def test_plan_refuses_changed_evidence_before_registration(self):
        original = register.sha
        for suffix in ('pack314_final/final_verification.json',
                       'copy315_installed_validation/report.json',
                       'copy315_installed/policy/Brainstorm/Advisor/hand_copy_preflight.lua',
                       'gold299_20260914/C04/trace.log', 'copy_compare22/step96.json'):
            def corrupted(path, suffix=suffix):
                return 'changed' if Path(path).as_posix().endswith(suffix) else original(path)
            with patch.object(register, 'sha', side_effect=corrupted):
                with self.assertRaises(AssertionError): register.plan()


if __name__ == '__main__':
    unittest.main()
