from pathlib import Path
import copy
import json
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/advisor_eval'))
import outcome_validation as O


class OutcomeValidationTests(unittest.TestCase):
    def requests(self):
        return [{'challenge': 'c_rich_1', 'seed': 'DEV263', 'split': 'development'},
                {'challenge': 'c_rich_1', 'seed': 'HOLD263', 'split': 'holdout'}]

    def test_holdout_cannot_reuse_development_trajectory(self):
        rows = self.requests(); rows[1]['seed'] = rows[0]['seed']
        with self.assertRaises(ValueError): O.requests_from(rows)

    def test_both_splits_are_required_before_execution(self):
        rows = self.requests(); rows[1]['split'] = 'development'
        with self.assertRaises(ValueError): O.requests_from(rows)

    def test_requests_do_not_accept_undeclared_overrides_or_filtering(self):
        rows = self.requests(); rows[0]['override'] = {'kind': 'reroll'}
        with self.assertRaises(ValueError): O.requests_from(rows)

    def test_execution_order_keeps_holdout_after_development_without_mutating_input(self):
        rows = list(reversed(self.requests())); ordered = O.requests_from(rows)
        self.assertEqual(rows[0]['split'], 'holdout')
        self.assertEqual(ordered[0]['split'], 'development')

    def records(self):
        return [dict(pair_index=i, role='candidate', outcome=outcome, elapsed_seconds=seconds,
                     actions={'play': 10}, score_verification={'explicit_unverified_scores': 0, 'missing_verification_steps': []})
                for i, outcome, seconds in [(0, 'loss', 10), (1, 'win', 20)]]

    def summary(self, records):
        return O.cohort_summary([{'pair_index': 0}, {'pair_index': 1}], records, 'candidate', 1.5, 5)

    def test_failed_attempt_and_action_costs_enter_retry_time(self):
        result = self.summary(self.records())
        self.assertEqual(result['diagnostic_seconds_per_win'], 65)
        self.assertIsNone(result['qualified_win_rate'])

    def test_each_unknown_outcome_blocks_terminal_and_retry_inference(self):
        for outcome in ('timeout', 'unsupported', 'censored', 'error'):
            with self.subTest(outcome=outcome):
                rows = self.records(); rows[0]['outcome'] = outcome
                result = self.summary(rows)
                self.assertFalse(result['complete_terminal_coverage'])
                self.assertIsNone(result['diagnostic_seconds_per_win'])
                self.assertEqual(result['outcomes'][outcome], 1)

    def test_missing_attempt_is_not_dropped_from_requested_denominator(self):
        result = self.summary(self.records()[1:])
        self.assertEqual(result['requested'], 2)
        self.assertEqual(result['outcomes']['missing'], 1)
        self.assertIsNone(result['diagnostic_seconds_per_win'])

    def test_score_gaps_stay_visible_even_for_a_terminal_win(self):
        rows = self.records(); rows[1]['score_verification'] = {'explicit_unverified_scores': 2, 'missing_verification_steps': [8]}
        result = self.summary(rows)
        self.assertEqual(result['score_gap_count'], 3)
        self.assertIsNone(result['qualified_win_rate'])

    def test_score_coverage_anomalies_are_not_dropped(self):
        rows = self.records(); rows[1]['score_verification'] = {'duplicate_verification_steps': [1],
            'unmatched_verification_steps': [9], 'invalid_verification_scope_steps': [2]}
        self.assertEqual(self.summary(rows)['score_gap_count'], 3)

    def profile(self):
        name = 'all_unlocked_discovered_v1'; spec = O.engine_probe.profile_spec(name)
        data = '\n'.join(scope + ':test:true:true' for scope in sorted(spec['scope'])).encode()
        return O.engine_probe.profile_record(name, data), {'profile_spec': spec}

    def test_actual_inventory_digest_is_recomputed(self):
        profile, manifest = self.profile()
        self.assertEqual(O.applied_profile([profile], manifest), profile['unlock_profile_digest'])
        for field, value in [('unlock_profile_digest', 'forged'), ('emitted_before_episode', False)]:
            altered = copy.deepcopy(profile); altered[field] = value
            with self.assertRaises(ValueError): O.applied_profile([altered], manifest)
        profile['inventory'][0]['unlocked'] = 'false'
        with self.assertRaises(ValueError): O.applied_profile([profile], manifest)

    def test_missing_duplicate_or_different_profile_is_rejected(self):
        profile, manifest = self.profile()
        for rows in ([], [profile, profile]):
            with self.assertRaises(ValueError): O.applied_profile(rows, manifest)
        manifest['profile_spec'] = O.engine_probe.profile_spec('source_defaults_v1')
        with self.assertRaises(ValueError): O.applied_profile([profile], manifest)

    def audited_record(self, role='candidate', outcome='win'):
        return dict(pair_index=0, role=role, challenge='c_rich_1', seed='DEV263',
                    outcome=outcome, reason='fixture', trace=role + '.log', elapsed_seconds=7,
                    actions={'play': 1}, score_verification={}, loss_analysis={},
                    action_sequence=[(1, {'kind': 'play', 'indices': [1]})])

    def audit_records(self, records, extra_lines=()):
        profile, manifest = self.profile()
        manifest['requests'] = self.requests()
        registration = dict(requests=self.requests(), registration_digest='fixture',
                            auditor_files={}, action_seconds=1.5, retry_seconds=5)
        def checked(directory, actual_manifest, value):
            if value.get('fixture_reject'):
                raise ValueError('Trace provenance differs from frozen policy/rules/start/adapter')
            return copy.deepcopy(value)
        def parsed(trace):
            record = next(row for row in records if row['trace'] == trace)
            return ([] if record.get('fixture_missing_profile') else [profile]), []
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp)
            (out / 'episodes.jsonl').write_text(''.join(json.dumps(row) + '\n' for row in records) +
                                               ''.join(line + '\n' for line in extra_lines))
            with patch.object(O, 'verify', return_value=(registration, manifest)), \
                 patch.object(O.paired, 'checked_record', side_effect=checked), \
                 patch.object(O.paired, 'parse_trace', side_effect=parsed):
                return O.audit(out)

    def test_rejected_actual_profile_cannot_enter_recorded_wins_or_divergences(self):
        record = self.audited_record(); record['fixture_missing_profile'] = True
        result = self.audit_records([record])
        self.assertEqual(result['recorded_attempts'], 0)
        summary = result['cohorts'][0]['roles']['candidate']
        self.assertEqual(summary['observed_source_wins'], 0)
        self.assertEqual(summary['outcomes'], {'unverified': 1})
        self.assertEqual(result['audit_errors'][0]['unverified_record']['trace'], record['trace'])

    def test_rejected_timeout_stays_distinct_from_an_unattempted_request(self):
        record = self.audited_record(outcome='timeout'); record['fixture_reject'] = True
        result = self.audit_records([record])
        self.assertEqual(result['submitted_attempt_records'], 1)
        self.assertEqual(len(result['missing_attempts']), 3)
        self.assertEqual(result['audit_errors'][0]['unverified_record']['outcome'], 'timeout')
        self.assertEqual(result['audit_errors'][0]['unverified_record']['elapsed_seconds'], 7)
        summary = result['cohorts'][0]['roles']['candidate']
        self.assertEqual(summary['reported_unverified_outcomes'], {'timeout': 1})
        self.assertIsNone(summary['diagnostic_seconds_per_win'])

    def test_unequal_action_suffix_is_a_prefix_end_not_an_action_divergence(self):
        a, b = self.audited_record('incumbent', 'timeout'), self.audited_record()
        b['action_sequence'].append((2, {'kind': 'discard', 'indices': [2]}))
        result = self.audit_records([a, b])
        self.assertEqual(result['first_divergences'], [])
        ended = result['action_prefix_ends'][0]
        self.assertEqual(ended['matching_action_prefix'], 1)
        self.assertEqual(ended['ended_role'], 'incumbent')
        self.assertEqual(ended['ended_outcome'], 'timeout')
        self.assertEqual(ended['next_observed_action'][0], 2)

    def test_actual_first_action_divergence_precedes_later_sequence_end(self):
        a, b = self.audited_record('incumbent'), self.audited_record()
        b['action_sequence'] = [(1, {'kind': 'discard', 'indices': [2]}), (2, {'kind': 'play'})]
        result = self.audit_records([a, b])
        self.assertEqual(result['first_divergences'][0]['candidate'][1]['kind'], 'discard')
        self.assertEqual(result['action_prefix_ends'], [])

    def test_duplicate_attempt_blocks_divergence_without_double_counting(self):
        a, b = self.audited_record('incumbent'), self.audited_record()
        b['action_sequence'] = [(1, {'kind': 'discard', 'indices': [2]})]
        result = self.audit_records([a, b, b])
        self.assertEqual(result['recorded_attempts'], 2)
        self.assertEqual(result['submitted_attempt_records'], 3)
        self.assertEqual(result['first_divergences'], [])
        self.assertEqual(result['cohorts'][0]['roles']['candidate']['outcomes'], {'win': 1})
        self.assertFalse(result['cohorts'][0]['paired_terminal_coverage'])

    def test_malformed_and_nonfinite_attempt_lines_remain_reportable(self):
        lines = ['{"pair_index":', '{"elapsed_seconds": NaN}', '[]']
        result = self.audit_records([], lines)
        self.assertEqual(result['recorded_attempts'], 0)
        self.assertEqual(result['submitted_attempt_records'], 3)
        self.assertEqual(len(result['missing_attempts']), 4)
        self.assertEqual([r['raw_record_line'] for r in result['audit_errors']], lines)

    def test_each_worker_rechecks_budget_after_pair_admission(self):
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp)
            reg = {'auditor_files': {}, 'registration_digest': 'fixed', 'wall_budget_seconds': 10}
            manifest = {'requests': [self.requests()[0]], 'timeout_seconds': 4}
            with patch.object(O, 'verify', return_value=(reg, manifest)), \
                 patch.object(O.paired, 'verify_manifest'), \
                 patch.object(O.time, 'perf_counter', side_effect=[0, 0, 7]), \
                 patch.object(O, 'audit', return_value={}), patch.object(O.paired, 'collect') as collect:
                O.execute(out)
                collect.assert_not_called()

    def test_empty_success_cohort_has_no_invented_expected_retry_time(self):
        rows = self.records(); rows[1]['outcome'] = 'loss'
        self.assertIsNone(self.summary(rows)['diagnostic_seconds_per_win'])

    def test_nonfinite_or_boolean_costs_are_rejected(self):
        for number in (float('nan'), float('inf'), True, -1, 121):
            self.assertFalse(O.finite_range(number, 0, 120))

    def test_execution_lease_prevents_spending_again_after_interruption(self):
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp); (out / 'outcome_execution_started.json').write_text('{}')
            reg = {'auditor_files': {}, 'registration_digest': 'fixed', 'wall_budget_seconds': 1}
            manifest = {'requests': [], 'timeout_seconds': 1}
            with patch.object(O, 'verify', return_value=(reg, manifest)), \
                 patch.object(O.paired, 'verify_manifest'), patch.object(O.paired, 'collect') as collect:
                with self.assertRaises(FileExistsError): O.execute(out)
                collect.assert_not_called()


if __name__ == '__main__': unittest.main()
