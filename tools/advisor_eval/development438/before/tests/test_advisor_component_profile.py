"""Frozen profiling validation; synthetic protocol cases, never win evidence."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parents[1] / 'tools/advisor_eval'
sys.path.insert(0, str(HERE))
spec = importlib.util.spec_from_file_location('component_profile_test', HERE / 'component_profile.py')
P = importlib.util.module_from_spec(spec)
spec.loader.exec_module(P)


def records():
    return [{'workload': workload, 'mode': mode, 'status': 'complete', 'rows': [
        {'input_fingerprint': 'input', 'decision_fingerprint': 'decision', 'action_fingerprint': 'action',
         'evaluations': 123, 'elapsed_seconds': .1} for _ in range(3)]}
        for workload in P.WORKLOADS for mode in P.MODES]


class ComponentProfileTests(unittest.TestCase):
    def test_pair_requires_exact_decisions_and_score_counts(self):
        data = records()
        self.assertTrue(all(row['exact_paired_result'] for row in P.summarize(data)['workloads']))
        for field in ('input_fingerprint', 'decision_fingerprint', 'action_fingerprint', 'evaluations'):
            altered = json.loads(json.dumps(data));altered[1]['rows'][0][field] = 'different'
            self.assertFalse(P.summarize(altered)['workloads'][0]['performance_comparison_eligible'])

    def test_timeout_and_missing_workers_remain_ineligible(self):
        data = records();data[0]['status'] = 'timeout'
        report = P.summarize(data)
        self.assertEqual(report['requested_workers'], 6)
        self.assertEqual(len(report['records']), 6)
        self.assertFalse(report['workloads'][0]['performance_comparison_eligible'])
        self.assertFalse(P.summarize(data[2:])['workloads'][0]['complete'])
        self.assertFalse(report['general_speedup_established'])
        self.assertFalse(report['win_rate_evidence'])

    def test_repeated_decision_nondeterminism_rejects_pair(self):
        data = records();data[0]['rows'][2]['decision_fingerprint'] = 'drift'
        self.assertFalse(P.summarize(data)['workloads'][0]['exact_paired_result'])

    def test_registration_bounds_precede_output_creation(self):
        with tempfile.TemporaryDirectory() as temp:
            destination = Path(temp) / 'bad'
            for repeat, timeout in ((0, 1), (6, 1), (True, 1), (1, 0), (1, 31)):
                with self.assertRaises(ValueError):
                    P.freeze(temp, destination, Path(temp) / 'lua.dll', repeat, timeout)
                self.assertFalse(destination.exists())
            for workloads in ([], ['shop_dagger', 'shop_dagger'], ['unknown'], list(P.ALL_WORKLOADS)):
                with self.assertRaises(ValueError):
                    P.freeze(temp, destination, Path(temp) / 'lua.dll', 1, 1, workloads)
                self.assertFalse(destination.exists())

    def test_selected_workloads_preserve_missing_or_unsupported_comparisons(self):
        report = P.summarize([], ['shop_dagger', 'shop_marble'])
        self.assertEqual(report['requested_workers'], 4)
        self.assertEqual([w['workload'] for w in report['workloads']], ['shop_dagger', 'shop_marble'])
        self.assertFalse(any(w['performance_comparison_eligible'] for w in report['workloads']))

    def test_frozen_provenance_and_fresh_directory(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp);source = base / 'source';product = source / 'Brainstorm/Advisor'
            product.mkdir(parents=True);(product / 'strategy.lua').write_text('return {}', encoding='utf-8')
            for relative in ('Core/Brainstorm.lua', 'Core/challenge_opening.lua', 'UI/advisor.lua',
                             'UI/ui.lua', 'UI/challenge_opening.lua', 'lovely.toml'):
                required = source / 'Brainstorm' / relative;required.parent.mkdir(parents=True, exist_ok=True)
                required.write_text('-- fixture', encoding='utf-8')
            runtime = base / 'fixture.dll';runtime.write_bytes(b'synthetic fixture only')
            out = base / 'output';manifest = P.freeze(source, out, runtime, 1, 1)
            self.assertEqual(P.verify(out)['policy_digest'], manifest['policy_digest'])
            # Changing the loader's dependency wiring must invalidate frozen
            # evidence even when the profiled runtime module bytes still match.
            frozen_loader = out / 'adapter/component_profile.lua'
            loader_bytes = frozen_loader.read_bytes()
            frozen_loader.write_bytes(loader_bytes + b'\n-- changed dependency wiring\n')
            with self.assertRaisesRegex(ValueError, 'profiling adapter changed'):
                P.verify(out)
            frozen_loader.write_bytes(loader_bytes)
            self.assertEqual(P.verify(out)['adapter_digest'], manifest['adapter_digest'])
            with self.assertRaises(FileExistsError):
                P.freeze(source, out, runtime, 1, 1)
            (out / 'policy/Brainstorm/Advisor/strategy.lua').write_text('return {changed=true}', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'product changed'):
                P.verify(out)

    def test_literal_handles_lua_delimiters(self):
        self.assertEqual(P.lua_literal('ordinary'), b'[=[ordinary]=]')
        self.assertEqual(P.lua_literal('end ]=] text'), b'[==[end ]=] text]==]')


if __name__ == '__main__':
    unittest.main()
