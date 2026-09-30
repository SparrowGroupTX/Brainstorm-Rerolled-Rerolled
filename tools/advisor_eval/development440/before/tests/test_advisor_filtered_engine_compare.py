from pathlib import Path
import copy
import json
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/advisor_eval'))
import filtered_engine_compare as compare


class FilteredEngineComparisonTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.request = {'challenge': 'c_knife_1', 'seed': 'FRESH1', 'targets': 'j_perkeo'}
        self.manifest = {'policy': {'policy_digest': 'policy', 'policy_files': {'Brainstorm/Immolate-v2.16.dll': 'native'}},
            'rules_digest': 'rules', 'runtime_digest': 'lua', 'adapter_digest': 'adapter', 'search_limit': 100}
        self.pair = ['j_yorick', 'j_perkeo']
        self.native = {'status': 'found', 'seed': 'FOUND1', 'legendary_jokers': self.pair, 'required_sales': 0}
        self.provenance = {'type': 'engine_probe_provenance', **self.request,
            **{k: self.manifest[k] for k in ('rules_digest', 'runtime_digest', 'adapter_digest')},
            'policy_digest': 'policy', 'policy_files': self.manifest['policy']['policy_files'],
            'start_distribution': {'kind': 'filtered_two_soul_native_v1', 'targets': 'j_perkeo'},
            'opening_policy_loaded': True, 'run_seed': 'FOUND1', 'opening': {'result': self.native,
                'search_start': 'FRESH1', 'search_limit': 100, 'threads': 1, 'targets': 'j_perkeo',
                'native_sha256': 'native', 'search_seconds': .2}}
        self.snapshot = {'ante': 1, 'round': 0, 'phase': 'blind', 'jokers': [
            {'key': 'j_yorick', 'ability': {'x_mult': 3, 'yorick_discards': 7, 'extra': {'xmult': 1, 'discards': 23}}}, {'key': 'j_perkeo', 'ability': {}}],
            'consumeables': [], 'playing_cards': []}
        self.rows = [self.provenance,
            {'type': 'engine_episode_action', 'step': 1, 'action': {'kind': 'skip_blind', 'blind': 'Small'}},
            {'type': 'engine_episode_action', 'step': 2, 'action': {'kind': 'choose'}, 'card_key': 'c_soul'},
            {'type': 'engine_episode_action', 'step': 3, 'action': {'kind': 'choose'}, 'card_key': 'c_soul'},
            {'type': 'engine_opening_setup_complete', 'actual_pair': self.pair, 'run_seed': 'FOUND1', 'decisions': 3,
             'search_seconds': .2, 'setup_seconds': .3, 'search_and_setup_seconds': .5, 'snapshot': self.snapshot}]

    def inspect(self, rows=None, outcome='censored'):
        path = self.root / 'trace.log';path.write_text('\n'.join(json.dumps(r) for r in (rows or self.rows)))
        record = {'trace': str(path), 'trace_digest': compare.file_digest(path), 'outcome': outcome,
                  'reason': 'development_fixture', 'elapsed_seconds': 1.0}
        return compare.inspect(record, self.manifest, self.request)

    def test_pair_acquisition_is_not_productive_perkeo_inventory(self):
        row = self.inspect()
        self.assertTrue(row['setup_complete'])
        features = row['observations'][0]['engine_features']
        self.assertEqual(features[0]['current_xmult'], 3)
        self.assertEqual(features[0]['remaining_discard_counter'], 7)
        self.assertEqual(features[0]['xmult_gain_per_trigger'], 1)
        self.assertEqual(features[0]['discard_trigger_size'], 23)
        self.assertFalse(features[1]['has_observed_copy_target'])
        self.assertEqual(row['cashouts_observed'], 0)

    def test_yorick_trigger_constants_cannot_fabricate_live_growth(self):
        old={'jokers':[{'key':'j_yorick','ability':{'extra':{'xmult':9,'discards':23}}}]}
        feature=compare.engine_features(old,['j_yorick'])[0]
        self.assertIsNone(feature['current_xmult'])
        self.assertIsNone(feature['remaining_discard_counter'])
        self.assertFalse(feature['counters_known'])
        self.assertIsNone(compare.retained_row(old)[0]['xmult_counter'])
        old['jokers'][0]['ability'].update(x_mult=1,yorick_discards=4)
        self.assertEqual(compare.retained_row(old)[0]['xmult_counter'],1)
        self.assertEqual(compare.engine_features(old,['j_yorick'])[0]['remaining_discard_counter'],4)

    def test_post_acquisition_soul_or_sale_is_not_revalidated_as_setup(self):
        self.rows += [{'type': 'engine_episode_action', 'step': 4, 'action': {'kind': 'choose'}, 'card_key': 'c_soul'},
                      {'type': 'engine_episode_action', 'step': 5, 'action': {'kind': 'sell'}, 'card_key': 'j_joker'}]
        row = self.inspect()
        self.assertEqual(row['setup_actions'], 3)
        self.assertEqual(row['actions_observed'], 5)

    def test_later_attrition_preserved_while_remaining_engine_gains_copy_target(self):
        hand = copy.deepcopy(self.snapshot);hand.update(phase='hand', round=1)
        hand['jokers'] = hand['jokers'][1:]
        hand['consumeables'] = [{'key': 'c_earth', 'edition': {'negative': True}}]
        self.rows += [
            {'type': 'engine_opening_pair_changed', 'step': 4, 'round': 1, 'ante': 1,
             'retained': ['j_perkeo'], 'missing': ['j_yorick'], 'action': {'kind': 'select_blind'}},
            {'type': 'engine_episode_decision', 'step': 5, 'snapshot': hand},
            {'type': 'engine_episode_action', 'step': 6, 'action': {'kind': 'cash_out'}},
        ]
        row = self.inspect(outcome='timeout')
        self.assertEqual(row['outcome'], 'timeout')
        self.assertEqual(row['first_loss_of_pair']['missing'], ['j_yorick'])
        self.assertEqual(row['last_observed_pair_keys'], ['j_perkeo'])
        feature = row['observations'][-1]['engine_features'][0]
        self.assertTrue(feature['has_observed_copy_target'])
        self.assertEqual(feature['negative_inventory_count'], 1)
        self.assertEqual(row['observed_rounds'], [0, 1])

    def test_same_round_inventory_changes_are_not_discarded(self):
        shop = copy.deepcopy(self.snapshot);shop['phase'] = 'shop';shop['round'] = 1
        self.rows.append({'type': 'engine_episode_decision', 'step': 5, 'snapshot': copy.deepcopy(shop)})
        shop['consumeables'] = [{'key': 'c_earth'}]
        self.rows.append({'type': 'engine_episode_decision', 'step': 6, 'snapshot': shop})
        self.assertEqual(len(self.inspect()['observations']), 3)

    def test_native_miss_retains_cost_and_never_becomes_playable(self):
        p = copy.deepcopy(self.provenance);p['opening']['result'] = {'status': 'not_found'}
        p['opening_policy_loaded'] = False;p['run_seed'] = None
        miss = self.inspect([p]);self.assertEqual(miss['search_seconds'], .2)
        self.assertFalse(miss['setup_complete'])
        p['run_seed'] = 'FAKE1'
        with self.assertRaisesRegex(ValueError, 'fabricated'):
            self.inspect([p])

    def test_cost_summary_keeps_misses_errors_and_timeouts_without_double_counting(self):
        first = self.inspect()
        miss = {**self.request, 'outcome': 'timeout', 'native_status': 'not_found', 'elapsed_seconds': 3,
                'search_seconds': 2, 'setup_complete': False}
        error = {**self.request, 'outcome': 'error', 'elapsed_seconds': 2, 'verification_error': 'mismatch'}
        result = compare.summarize([first, miss, error]);group = result['groups'][0]
        self.assertEqual(group['attempts'], 3)
        self.assertEqual(group['total_attempt_seconds']['total'], 6)
        self.assertEqual(group['search_seconds']['total'], 2.2)
        self.assertEqual(group['verified_acquisitions'], 1)
        self.assertEqual(group['verification_errors'], 1)
        self.assertIsNone(result['win_rate_estimate'])

    def test_provenance_and_setup_cost_are_checked(self):
        self.provenance['adapter_digest'] = 'changed'
        with self.assertRaisesRegex(ValueError, 'Provenance'):
            self.inspect()
        self.provenance['adapter_digest'] = 'adapter'
        self.rows[-1]['search_and_setup_seconds'] = .3
        with self.assertRaisesRegex(ValueError, 'excludes search'):
            self.inspect()

    def test_attrition_cannot_omit_missing_cards(self):
        self.rows.append({'type': 'engine_opening_pair_changed', 'step': 4, 'retained': ['j_perkeo'], 'missing': []})
        with self.assertRaisesRegex(ValueError, 'Incomplete retention'):
            self.inspect()

    def test_jokerless_excluded(self):
        self.request['challenge'] = 'c_jokerless_1'
        with self.assertRaisesRegex(ValueError, 'Jokerless'):
            self.inspect()

    def test_debuffed_or_expired_perkeo_is_not_an_active_copy_engine(self):
        self.snapshot['consumeables'] = [{'key': 'c_earth'}]
        self.snapshot['jokers'][1]['ability'] = {'perishable': True, 'perish_tally': 0}
        feature = compare.engine_features(self.snapshot, self.pair)[1]
        self.assertFalse(feature['active'])
        self.assertFalse(feature['has_observed_copy_target'])

    def test_continuation_chain_includes_prior_miss_cost(self):
        miss = {**self.request, 'outcome': 'censored', 'native_status': 'not_found', 'elapsed_seconds': 3,
                'search_seconds': 2, 'setup_complete': False, 'next_search_seed': 'NEXT1'}
        found = {**self.inspect(), 'seed': 'NEXT1', 'elapsed_seconds': 8}
        other = {**miss, 'targets': '', 'next_search_seed': 'ELSE1'}
        result = compare.summarize_chains([miss, found, other])
        self.assertEqual(len(result['chains']), 2)
        chain = result['chains'][0]
        self.assertEqual(chain['attempts'], 2)
        self.assertEqual(chain['total_attempt_seconds'], 11)
        self.assertEqual(chain['acquisitions'], 1)
        self.assertEqual(chain['search_starts'], ['FRESH1', 'NEXT1'])

    def test_chain_rejects_duplicate_attempts_and_cycles(self):
        row = {**self.request, 'outcome': 'censored', 'elapsed_seconds': 1, 'next_search_seed': 'NEXT1'}
        with self.assertRaisesRegex(ValueError, 'Repeated'):
            compare.summarize_chains([row, copy.deepcopy(row)])
        back = {**row, 'seed': 'NEXT1', 'next_search_seed': 'FRESH1'}
        with self.assertRaisesRegex(ValueError, 'Cyclic'):
            compare.summarize_chains([row, back])

    def test_sacrifice_growth_is_visible_in_retained_row_even_when_pair_gone(self):
        s = {'jokers': [{'key': 'j_ceremonial', 'pinned': True, 'ability': {'mult': 32}, 'sell_cost': 2}]}
        self.assertEqual(compare.engine_features(s, self.pair), [])
        row = compare.retained_row(s)[0]
        self.assertEqual(row['mult_counter'], 32)
        self.assertTrue(row['pinned'])
        self.assertTrue(row['active'])


if __name__ == '__main__':
    unittest.main()
