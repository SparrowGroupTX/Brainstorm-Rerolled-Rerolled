from pathlib import Path
import copy
import json
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/advisor_eval'))
import filtered_opening_audit as audit
import opening_support as support


class FilteredOpeningTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.request = {'challenge': 'c_omelette_1', 'seed': 'SEARCH1'}
        self.native = {'status': 'found', 'seed': 'ACTUAL1', 'legendary_jokers': ['j_yorick', 'j_perkeo'], 'required_sales': 2}
        self.manifest = {'policy': {'policy_digest': 'policy', 'policy_files': {'Brainstorm/Immolate-v2.16.dll': 'native'}},
                         'rules_digest': 'rules', 'runtime_digest': 'lua', 'adapter_digest': 'adapter',
                         'targets': 'j_perkeo', 'search_limit': 10}
        self.provenance = {'type': 'engine_probe_provenance', **self.request,
            **{k: self.manifest[k] for k in ('rules_digest', 'runtime_digest', 'adapter_digest')},
            'policy_digest': 'policy', 'policy_files': self.manifest['policy']['policy_files'],
            'start_distribution': {'kind': 'filtered_two_soul_native_v1', 'targets': 'j_perkeo'},
            'opening_policy_loaded': True, 'run_seed': 'ACTUAL1', 'opening': {'result': self.native,
                'search_start': 'SEARCH1', 'search_limit': 10, 'threads': 1, 'targets': 'j_perkeo',
                'native_sha256': 'native', 'search_seconds': .2}}
        self.rows = [self.provenance]
        actions = [('skip_blind', None), ('sell', 'j_egg'), ('choose', 'c_soul'), ('sell', 'j_egg'), ('choose', 'c_soul')]
        for index, (kind, key) in enumerate(actions):
            action = {'kind': kind}
            if kind == 'skip_blind': action['blind'] = 'Small'
            self.rows.append({'type': 'engine_episode_action', 'step': index + 1, 'action': action, 'card_key': key})
        self.rows.append({'type': 'engine_opening_setup_complete', 'actual_pair': self.native['legendary_jokers'],
                          'run_seed': 'ACTUAL1', 'search_seconds': .2, 'setup_seconds': .3, 'search_and_setup_seconds': .5})

    def inspect(self, rows=None, role='filtered'):
        path = self.root / 'trace.log';path.write_text('\n'.join(json.dumps(r) for r in (rows or self.rows)))
        record = {'trace': str(path), 'trace_digest': audit.file_digest(path), 'outcome': 'censored', 'reason': 'development_fixture', 'elapsed_seconds': .6}
        return audit.inspect_record(record, self.manifest, role, self.request)

    def test_real_run_seed_distinct_from_search_start(self):
        result = self.inspect()
        self.assertTrue(result['setup_complete']);self.assertEqual(result['run_seed'], 'ACTUAL1')
        self.assertEqual(result['search_and_setup_seconds'], .5)

    def test_no_find_preserves_attempt_without_playable_seed(self):
        row = copy.deepcopy(self.provenance);row['opening']['result'] = {'status': 'not_found', 'next_seed': 'NEXT1'}
        row['run_seed'] = None;row['opening_policy_loaded'] = False
        result = self.inspect([row]);self.assertEqual(result['native_status'], 'not_found');self.assertFalse(result['setup_complete'])
        row['run_seed'] = 'FAKE1'
        with self.assertRaisesRegex(ValueError, 'fabricated'): self.inspect([row])

    def test_found_seed_cannot_be_substituted(self):
        self.provenance['run_seed'] = 'FAKE1'
        with self.assertRaisesRegex(ValueError, 'found seed'): self.inspect()

    def test_pair_requires_source_agreement(self):
        self.rows[-1]['actual_pair'] = ['j_caino', 'j_chicot']
        with self.assertRaisesRegex(ValueError, 'pair differs'): self.inspect()

    def test_setup_cannot_omit_search_cost(self):
        self.rows[-1]['search_and_setup_seconds'] = .3
        with self.assertRaisesRegex(ValueError, 'excludes search'): self.inspect()
        self.rows[-1]['search_and_setup_seconds'] = float('nan')
        with self.assertRaisesRegex(ValueError, 'setup cost'): self.inspect()

    def test_source_actions_required(self):
        self.rows[2]['card_key'] = 'j_joker'
        with self.assertRaisesRegex(ValueError, 'action trace'): self.inspect()

    def test_ordinary_denominator_rejects_filtered(self):
        with self.assertRaisesRegex(ValueError, 'Ordinary prefix'): self.inspect(role='ordinary')

    def test_native_digest_and_search_contract_checked(self):
        self.provenance['opening']['threads'] = 2
        with self.assertRaisesRegex(ValueError, 'Native search'): self.inspect()

    def test_native_inputs_fail_before_dll_access(self):
        for seed, targets, limit in [('ZERO0', '', 1), ('SEED1', 'j_joker', 1), ('SEED1', 'j_perkeo,j_perkeo', 1), ('SEED1', '', 0)]:
            with self.assertRaises(ValueError): support.native_search(self.root, seed, 'c_omelette_1', targets, limit)

    def test_hook_replacement_requires_exact_source_and_frozen_patch(self):
        root = self.root / 'Brainstorm';(root / 'Core').mkdir(parents=True)
        (root / 'Core/Brainstorm.lua').write_text('function Brainstorm.createCharmArcanaCard() end\nfunction Brainstorm.init() end')
        (root / 'Core/challenge_opening.lua').write_text('return {}')
        patches = []
        original = []
        for kind in ('Tarot', 'Spectral'):
            pattern = 'card = create_card("' + kind + '")';original.append(pattern)
            payload = pattern.replace('create_card(', 'Brainstorm.createCharmArcanaCard(self, ')
            patches.append("[[patches]]\n[patches.pattern]\ntarget='card.lua'\nposition='at'\ntimes=1\npattern='" + pattern + "'\npayload='" + payload + "'")
        (root / 'lovely.toml').write_text('\n'.join(patches))
        source = {'card.lua': '\n'.join(original).encode()}
        modified, _, _, hashes = support.opening_sources(self.root, source)
        self.assertEqual(modified['card.lua'].count(b'Brainstorm.createCharmArcanaCard('), 2)
        self.assertNotEqual(hashes['card_before'], hashes['card_after'])
        self.assertEqual(source['card.lua'].count(b'Brainstorm.'), 0)
        with self.assertRaisesRegex(ValueError, 'source mismatch'):
            support.opening_sources(self.root, {'card.lua': source['card.lua'] + b'\n' + original[0].encode()})


if __name__ == '__main__': unittest.main()
