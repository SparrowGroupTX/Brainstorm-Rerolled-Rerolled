"""Pure M20 preparation checks; never invokes comparison or registration."""
from copy import deepcopy
from pathlib import Path
import hashlib
import importlib.util
import json
import unittest
import compare_cache20 as worker

HERE = Path(__file__).resolve().parent


def result():
    return {'status': 'complete', 'input_unchanged': True, 'input_fingerprint': 'synthetic',
            'action': {'kind': 'discard', 'indices': [1, 2]}, 'score_calls': 30,
            'result': {'action': {'kind': 'discard', 'indices': [1, 2]}, 'evaluations': 30,
                       'play': {'score': 100, 'hand': 'Pair'}, 'score_cache': {'hits': 3, 'misses': 27}}}


class SpecTests(unittest.TestCase):
    def test_only_top_level_cache_diagnostics_may_differ(self):
        a, b = result(), result()
        b['result']['score_cache'] = {'hits': 20, 'misses': 10, 'evictions': 5}
        self.assertTrue(worker.compare_pair(a, b))
        for mutation in ('input', 'action', 'count', 'evaluation', 'score', 'nested'):
            b = result()
            if mutation == 'input': b['input_unchanged'] = False
            elif mutation == 'action': b['action']['indices'] = [2, 3]
            elif mutation == 'count': b['score_calls'] = 31
            elif mutation == 'evaluation': b['result']['evaluations'] = 31
            elif mutation == 'score': b['result']['play']['score'] = 101
            else: b['result']['play']['score_cache'] = {'hidden_difference': True}
            with self.assertRaises(ValueError): worker.compare_pair(a, b)

    def test_fixed_order_and_caps(self):
        self.assertEqual(worker.ORDER, (('baseline', 85), ('candidate', 85), ('candidate', 185), ('baseline', 185)))
        self.assertEqual(worker.CAP, 140000)
        self.assertEqual(worker.TOTAL_CAP, 560000)
        with self.assertRaises(FileNotFoundError): worker.verify(HERE)

    def test_one_policy_file_change_with_same_membership(self):
        a = json.loads((HERE / 'baseline_record.json').read_text())['policy']['policy_files']
        b = json.loads((HERE / 'candidate_record.json').read_text())['policy']['policy_files']
        self.assertEqual(set(a), set(b))
        self.assertEqual([k for k in a if a[k] != b[k]], ['Brainstorm/Advisor/score_cache.lua'])
        self.assertEqual(hashlib.sha256((HERE / 'candidate_score_cache.lua').read_bytes()).hexdigest(), b['Brainstorm/Advisor/score_cache.lua'])

    def test_exact_current_runtime_derivation_without_dispatch(self):
        root = HERE.parents[4]
        runtime = root / 'tools/advisor_eval/runs/certificate309_installed/policy/Brainstorm/Advisor/runtime.lua'
        prefix = (HERE / 'module_setup.lua').read_bytes()
        provenance = json.loads((HERE / 'input_provenance.json').read_text())
        self.assertEqual(hashlib.sha256(prefix).hexdigest(), provenance['module_setup_sha256'])
        self.assertEqual(hashlib.sha256(runtime.read_bytes()).hexdigest(), provenance['module_setup_parent_sha256'])
        self.assertEqual(len(provenance['omitted_product_integrations']), 5)
        self.assertNotIn(b'function A.defaults', prefix)
        self.assertIn(b'A.snapshot.certificate=A.certificate', prefix)
        self.assertIn(b'A.shop_scoring.bell_opening=A.bell_opening', prefix)
        self.assertNotIn(b'pack_survival', prefix)


if __name__ == '__main__':
    unittest.main()
