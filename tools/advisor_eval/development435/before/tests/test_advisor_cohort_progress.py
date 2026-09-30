from pathlib import Path
import copy
import importlib.util
import json
import math
import unittest


MODULE_PATH = Path(__file__).resolve().parents[1] / 'tools/advisor_eval/cohort_progress.py'
SPEC = importlib.util.spec_from_file_location('advisor_cohort_progress', MODULE_PATH)
C = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(C)


def fixture(seeds=('S1', 'S2'), four=False):
    policies = {'baseline': '1' * 64, 'candidate': '2' * 64}
    if four:
        policies = {'baseline': '1' * 64, 'a': '2' * 64, 'b': '3' * 64, 'ab': '4' * 64}
    reg = {'digest': 'd' * 64, 'challenge': 'synthetic_fixture', 'split': 'development',
           'provenance': {key: 'a' * 64 for key in C.DIGEST_KEYS}, 'policies': policies,
           'seeds': list(seeds), 'baseline': 'baseline', 'initial_state': 'fresh_run',
           'retry_context': 'disabled_clean', 'sampling': {key: False for key in C.SAMPLING_KEYS},
           'milestones': [{'ante': 2, 'blind': 'big', 'event': 'entered'},
                          {'ante': 2, 'blind': 'big', 'event': 'cleared'}]}
    if four:
        reg['factorial'] = {key: key for key in ('baseline', 'a', 'b', 'ab')}
    return {'schema': 1, 'registration': reg, 'records': []}


def add(document, variant, seed, outcome='loss', verified=True, **changes):
    reg = document['registration']
    row = {'variant': variant, 'seed': seed, 'outcome': outcome,
           'terminal_verified': verified if outcome in ('win', 'loss') else False,
           'terminal_audit_digest': 'e' * 64, 'registration_digest': reg['digest'],
           'challenge': reg['challenge'], 'split': reg['split'], 'provenance': copy.deepcopy(reg['provenance']),
           'policy_digest': reg['policies'][variant], 'initial_state': 'fresh_run',
           'retry_context': 'disabled_clean', 'dependent_attempt': False}
    row.update(changes)
    document['records'].append(row)
    return row


class CohortProgressTests(unittest.TestCase):
    def test_all_registered_attempts_and_missing_outcomes_remain_in_denominator(self):
        doc = fixture()
        add(doc, 'baseline', 'S1', 'win')
        result = C.report(doc)
        self.assertEqual(result['registered_attempts'], 4)
        self.assertEqual(result['submitted_records'], 1)
        value = result['variants']['baseline']
        self.assertEqual(value['outcomes'], {'missing': 1, 'win': 1})
        self.assertEqual(value['completion']['missing_outcome_bounds'], [.5, 1])
        self.assertIsNone(value['completion']['observed_complete_fraction'])
        self.assertEqual(result['variants']['candidate']['completion']['missing_outcome_bounds'], [0, 1])

    def test_each_unresolved_category_is_preserved_without_imputation(self):
        statuses = ('error', 'timeout', 'unsupported', 'censored', 'unverified')
        doc = fixture(tuple(f'S{i}' for i in range(len(statuses))))
        for seed, status in zip(doc['registration']['seeds'], statuses):
            add(doc, 'baseline', seed, status)
        result = C.report(doc)['variants']['baseline']
        self.assertEqual(result['outcomes'], {k: 1 for k in statuses})
        self.assertEqual(result['completion']['missing_outcome_bounds'], [0, 1])
        self.assertEqual(result['completion']['unknown'], 5)

    def test_claimed_win_and_incidental_game_won_cannot_create_verified_win(self):
        doc = fixture()
        add(doc, 'baseline', 'S1', 'win', False, game_won=True)
        add(doc, 'baseline', 'S2', 'loss', game_won=True)
        result = C.report(doc)['variants']['baseline']
        self.assertEqual(result['outcomes'], {'loss': 1, 'unverified': 1})
        self.assertEqual(result['completion']['positive'], 0)
        self.assertEqual(result['reported_unverified_terminals'], {'win': 1})

    def test_verified_terminal_requires_upstream_audit_digest(self):
        doc = fixture()
        row = add(doc, 'baseline', 'S1', 'win')
        for bad in (None, '', 'old-record', 'a' * 63):
            row['terminal_audit_digest'] = bad
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                C.report(doc)

    def test_mixed_frozen_identities_or_request_identity_are_rejected(self):
        for field in ('registration_digest', 'policy_digest', 'challenge', 'split'):
            doc = fixture()
            row = add(doc, 'baseline', 'S1')
            row[field] = 'different'
            with self.subTest(field=field), self.assertRaises(ValueError):
                C.report(doc)
        for field in C.DIGEST_KEYS:
            doc = fixture()
            row = add(doc, 'baseline', 'S1')
            row['provenance'][field] = 'b' * 64
            with self.subTest(field=field), self.assertRaises(ValueError):
                C.report(doc)

    def test_missing_exact_registration_provenance_is_rejected(self):
        for key in C.DIGEST_KEYS:
            doc = fixture()
            del doc['registration']['provenance'][key]
            with self.subTest(key=key), self.assertRaises(ValueError):
                C.report(doc)

    def test_duplicate_and_dependent_attempts_cannot_become_replications(self):
        doc = fixture()
        row = add(doc, 'baseline', 'S1')
        doc['records'].append(copy.deepcopy(row))
        with self.assertRaises(ValueError):
            C.report(doc)
        for changes in ({'dependent_attempt': True}, {'initial_state': 'checkpoint'},
                        {'retry_context': 'manual'}, {'seed': 'UNREGISTERED'}):
            doc = fixture()
            add(doc, 'baseline', 'S1').update(changes)
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                C.report(doc)
        doc = fixture(('S1', 'S1'))
        with self.assertRaises(ValueError):
            C.report(doc)

    def test_milestone_entry_clearance_and_skips_are_separate(self):
        doc = fixture()
        add(doc, 'baseline', 'S1', milestones={'ante_2_big_entered': True, 'ante_2_big_cleared': False},
            skipped_blinds=[{'ante': 1, 'blind': 'small'}])
        add(doc, 'baseline', 'S2', 'timeout')
        result = C.report(doc)['variants']['baseline']
        self.assertEqual(result['milestones']['ante_2_big_entered']['missing_outcome_bounds'], [.5, 1])
        self.assertEqual(result['milestones']['ante_2_big_cleared']['missing_outcome_bounds'], [0, .5])
        self.assertEqual(result['skipped_blinds']['observed_total'], 1)
        self.assertEqual(result['skipped_blinds']['records_without_complete_skip_list'], 1)

    def test_win_does_not_fabricate_unrecorded_milestones_or_skips(self):
        doc = fixture()
        add(doc, 'baseline', 'S1', 'win')
        add(doc, 'baseline', 'S2', 'win')
        result = C.report(doc)['variants']['baseline']
        self.assertEqual(result['completion']['positive'], 2)
        self.assertEqual(result['milestones']['ante_2_big_cleared']['unknown'], 2)
        self.assertEqual(result['skipped_blinds']['records_with_complete_skip_list'], 0)

    def test_impossible_milestone_and_skip_claims_are_rejected(self):
        alternatives = [
            {'milestones': {'ante_2_big_entered': False, 'ante_2_big_cleared': True}},
            {'milestones': {'ante_2_big_entered': True}, 'skipped_blinds': [{'ante': 2, 'blind': 'big'}]},
            {'skipped_blinds': [{'ante': 2, 'blind': 'boss'}]},
            {'skipped_blinds': [{'ante': 2, 'blind': 'big'}, {'ante': 2, 'blind': 'big'}]},
            {'milestones': {'ante_2_big_entered': 1}},
            {'milestones': {'ante_99_big_entered': True}},
        ]
        for changes in alternatives:
            doc = fixture()
            add(doc, 'baseline', 'S1', **changes)
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                C.report(doc)

    def test_paired_completion_is_aligned_by_seed_not_record_order(self):
        doc = fixture(('S1', 'S2', 'S3'))
        add(doc, 'baseline', 'S1', 'loss')
        add(doc, 'baseline', 'S2', 'win')
        add(doc, 'baseline', 'S3', 'loss')
        add(doc, 'candidate', 'S3', 'win')
        add(doc, 'candidate', 'S2', 'loss')
        add(doc, 'candidate', 'S1', 'win')
        result = C.report(doc)['paired']['candidate']['completion']
        self.assertEqual(result['complete_pairs'], 3)
        self.assertEqual(result['complete_pair_mean_difference'], 1 / 3)
        self.assertEqual(result['full_cohort_difference_bounds'], [1 / 3, 1 / 3])

    def test_partial_pairs_have_full_denominator_bounds_and_no_interval(self):
        doc = fixture()
        doc['registration']['sampling'] = {key: True for key in C.SAMPLING_KEYS}
        add(doc, 'baseline', 'S1', 'loss')
        add(doc, 'candidate', 'S1', 'win')
        add(doc, 'baseline', 'S2', 'win')
        add(doc, 'candidate', 'S2', 'timeout')
        value = C.report(doc)['paired']['candidate']['completion']
        self.assertEqual(value['complete_pairs'], 1)
        self.assertEqual(value['complete_pair_mean_difference'], 1)
        self.assertEqual(value['full_cohort_difference_bounds'], [0, .5])
        self.assertIsNone(value['sampling_interval'])

    def test_selected_old_or_adaptive_cohort_never_gets_confidence_interval(self):
        for missing_assumption in C.SAMPLING_KEYS:
            doc = fixture()
            doc['registration']['sampling'] = {key: True for key in C.SAMPLING_KEYS}
            doc['registration']['sampling'][missing_assumption] = False
            for variant in doc['registration']['policies']:
                for seed in doc['registration']['seeds']:
                    add(doc, variant, seed)
            value = C.report(doc)
            with self.subTest(missing_assumption=missing_assumption):
                self.assertIsNone(value['variants']['baseline']['completion']['sampling_interval'])
                self.assertIsNone(value['paired']['candidate']['completion']['sampling_interval'])

    def test_zero_wins_produce_nonzero_conservative_upper_bound_when_eligible(self):
        doc = fixture(tuple(f'S{i}' for i in range(100)))
        doc['registration']['sampling'] = {key: True for key in C.SAMPLING_KEYS}
        for variant in doc['registration']['policies']:
            for seed in doc['registration']['seeds']:
                add(doc, variant, seed)
        result = C.report(doc)
        ci = result['variants']['baseline']['completion']['sampling_interval']['bounds']
        self.assertEqual(ci[0], 0)
        self.assertAlmostEqual(ci[1], math.sqrt(math.log(40) / 200))
        paired = result['paired']['candidate']['completion']['sampling_interval']['bounds']
        self.assertLess(paired[0], 0)
        self.assertGreater(paired[1], 0)

    def test_failure_only_mean_can_fall_as_completion_improves(self):
        doc = fixture()
        add(doc, 'baseline', 'S1', failure_round=3)
        add(doc, 'baseline', 'S2', failure_round=20)
        add(doc, 'candidate', 'S1', failure_round=3)
        add(doc, 'candidate', 'S2', 'win')
        value = C.report(doc)['variants']
        self.assertEqual(value['baseline']['failure_round_diagnostic']['mean'], 11.5)
        self.assertEqual(value['candidate']['failure_round_diagnostic']['mean'], 3)
        self.assertEqual(value['candidate']['completion']['positive'], 1)

    def test_costs_keep_missing_coverage_and_cannot_estimate_real_completion_time(self):
        doc = fixture()
        add(doc, 'baseline', 'S1', 'win', attempt_seconds=7, user_actions=20)
        value = C.report(doc)
        cost = value['variants']['baseline']['attempt_seconds']
        self.assertEqual(cost['missing'], 1)
        self.assertEqual(cost['observed_total'], 7)
        self.assertEqual(cost['observed_mean'], 7)
        self.assertIsNone(value['expected_real_completion_seconds'])
        self.assertIsNone(value['player_win_rate'])
        self.assertFalse(value['qualification'])

    def test_nonfinite_boolean_negative_and_noninteger_metrics_are_rejected(self):
        for key, bad in [('attempt_seconds', True), ('attempt_seconds', float('nan')),
                         ('attempt_seconds', float('inf')), ('user_actions', 1.5),
                         ('user_actions', -1), ('failure_round', False)]:
            doc = fixture()
            add(doc, 'baseline', 'S1', **{key: bad})
            with self.subTest(key=key, bad=bad), self.assertRaises(ValueError):
                C.report(doc)

    def test_factorial_interaction_uses_only_four_complete_seed_variants(self):
        doc = fixture(four=True)
        for variant in doc['registration']['policies']:
            add(doc, variant, 'S1', 'win' if variant == 'ab' else 'loss')
            add(doc, variant, 'S2', 'timeout' if variant == 'b' else 'loss')
        value = C.report(doc)['interaction']['endpoints']['completion']
        self.assertEqual(value['complete_seed_blocks'], 1)
        self.assertEqual(value['excluded_seed_blocks'], 1)
        self.assertEqual(value['mean_complete_block_contrast'], 1)
        self.assertIsNone(value['sampling_interval'])

    def test_partial_trajectory_cannot_enter_milestone_factorial_interaction(self):
        doc = fixture(('S1',), four=True)
        for variant in doc['registration']['policies']:
            add(doc, variant, 'S1', 'timeout' if variant == 'ab' else 'loss',
                milestones={'ante_2_big_entered': True})
        result = C.report(doc)['interaction']['endpoints']['ante_2_big_entered']
        self.assertEqual(result['complete_seed_blocks'], 0)
        self.assertIsNone(result['mean_complete_block_contrast'])

    def test_does_not_mutate_records_and_output_is_finite_json(self):
        doc = fixture()
        add(doc, 'baseline', 'S1', 'loss')
        original = copy.deepcopy(doc)
        result = C.report(doc)
        self.assertEqual(doc, original)
        json.dumps(result, allow_nan=False)

    def test_json_rejects_shadowed_provenance_and_nonfinite_literals(self):
        for data in (b'{"schema": 1, "schema": 1}', b'{"provenance": {"source": "a", "source": "b"}}',
                     b'{"cost": NaN}', b'{"cost": Infinity}', b'{"cost": -Infinity}'):
            with self.subTest(data=data), self.assertRaises(ValueError):
                C.parse_input(data)
        doc = fixture()
        self.assertEqual(C.parse_input(json.dumps(doc).encode('utf-8-sig')), doc)

    def test_boolean_schema_is_not_a_version_number(self):
        doc = fixture()
        doc['schema'] = True
        with self.assertRaises(ValueError):
            C.report(doc)


if __name__ == '__main__':
    unittest.main()
