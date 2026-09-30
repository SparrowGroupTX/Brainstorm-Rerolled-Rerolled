from pathlib import Path
import json
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/advisor_eval'))
import filtered_route_selection as S


def row(seed, targets='', seconds=10, actions=5, **extra):
    return {'seed': seed, 'challenge': 'c_knife_1', 'targets': targets,
            'elapsed_seconds': seconds, 'actions_observed': actions, **extra}


class FilteredRouteSelectionTests(unittest.TestCase):
    def test_all_attempt_costs_include_misses_without_double_counting_components(self):
        records = [row('A', seconds=2, actions=0, search_seconds=1, native_status='not_found'),
                   row('B', seconds=20, actions=8, search_seconds=1, setup_seconds=3)]
        costs = {'action_seconds': 1, 'failed_run_restart_seconds': 5, 'search_invocation_seconds': 2}
        report = S.summarize_records(records, costs, ['resolved_search_miss', 'win'])
        group = report['groups'][0]
        self.assertEqual(group['source_attempt_seconds'], 22)
        self.assertEqual(group['diagnostic_declared_seconds_per_win'], 34)
        self.assertEqual(group['recorded_losses'], 0);self.assertEqual(group['observed_native_misses'], 1)
        self.assertFalse(report['promotion_allowed'])

    def test_any_censor_error_timeout_or_missing_status_prevents_completion_estimate(self):
        for status in ('unresolved_timeout', 'unresolved_censored', 'unresolved_error', 'unresolved_legacy_exit_status'):
            with self.subTest(status=status):
                report = S.summarize_records([row('A'), row('B')], None, ['win', status])
                self.assertIsNone(report['groups'][0]['diagnostic_source_seconds_per_win'])
                self.assertEqual(report['comparisons'][0]['status'], 'inconclusive')

    def test_terminal_losses_and_restart_cost_remain_in_retry_proxy(self):
        costs = {'action_seconds': 0, 'failed_run_restart_seconds': 7, 'search_invocation_seconds': 0}
        group = S.summarize_records([row('A'), row('B', seconds=20)], costs, ['loss', 'win'])['groups'][0]
        self.assertEqual(group['diagnostic_declared_seconds_per_win'], 37)
        self.assertEqual(group['recorded_losses'], 1)

    def test_acquisition_and_attrition_cannot_be_substituted_for_wins(self):
        record = row('A', acquired_pair=['j_yorick', 'j_caino'], setup_complete=True,
                     first_loss_of_pair={'step': 4}, last_observed_pair_keys=[],
                     observations=[{'retained_row': [{'key': 'j_ceremonial', 'mult_counter': 58}]}])
        group = S.summarize_records([record], None, ['unresolved_censored'])['groups'][0]
        self.assertEqual(group['recorded_wins'], 0);self.assertEqual(group['observed_pair_attritions'], 1)
        self.assertEqual(group['last_observed_rows'][0]['row'][0]['mult_counter'], 58)
        self.assertIsNone(group['diagnostic_source_seconds_per_win'])

    def test_only_matched_complete_terminal_cohorts_get_diagnostic_rank(self):
        costs = {'action_seconds': 0, 'failed_run_restart_seconds': 0, 'search_invocation_seconds': 0}
        records = [row('A', seconds=10), row('A', targets='j_perkeo', seconds=8)]
        report = S.summarize_records(records, costs, ['win', 'win'])
        comparison = report['comparisons'][0]
        self.assertEqual(comparison['diagnostic_preferred_targets'], 'j_perkeo')
        self.assertFalse(comparison['runtime_filter_change_allowed'])
        records[1]['seed'] = 'B'
        self.assertEqual(S.summarize_records(records, costs, ['win', 'win'])['comparisons'][0]['status'], 'inconclusive')

    def test_jokerless_duplicate_attempts_and_unknown_costs_fail_closed(self):
        with self.assertRaisesRegex(ValueError, 'Jokerless'):
            S.summarize_records([row('A', challenge='c_jokerless_1')], None, ['win'])
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            S.summarize_records([row('A'), row('A')], None, ['win', 'win'])
        for costs in ({}, {'action_seconds': float('nan')}, {'action_seconds': True}):
            with self.assertRaises(ValueError): S.cost_model(costs)

    def test_cached_win_cannot_override_censor_or_missing_exit(self):
        with tempfile.TemporaryDirectory() as temporary:
            trace = Path(temporary) / 'trace.log'
            trace.write_text('\n'.join(json.dumps(r) for r in [
                {'type': 'engine_probe_provenance', 'challenge': 'c_knife_1', 'seed': 'A'},
                {'type': 'engine_episode_stopped', 'outcome': 'censored', 'reason': 'development_step_limit'}]))
            record = row('A', trace=str(trace), trace_digest=S.file_digest(trace), outcome='win',
                         native_status='found', setup_complete=True)
            self.assertEqual(S.complete_attempt(record), 'unresolved_legacy_exit_status')
            record['exit_code'] = 0
            self.assertEqual(S.complete_attempt(record), 'unresolved_censored')

    def test_one_more_search_uses_miss_fallback_and_worst_case_bounds(self):
        scenario = {'current_remaining_seconds': [100, 100], 'search_seconds': [5, 5],
                    'hit_probability': [.5, .5], 'found_remaining_seconds': [50, 50]}
        result = S.one_more_search_scenario(scenario)
        self.assertEqual(result['extra_expected_seconds_bounds'], [-20, -20])
        self.assertEqual(result['conditional_choice'], 'one_more_bounded_search')
        self.assertFalse(result['search_execution_authorized']);self.assertFalse(result['measured_estimate'])
        scenario['hit_probability'] = [0, .5]
        self.assertEqual(S.one_more_search_scenario(scenario)['conditional_choice'], 'inconclusive')
        scenario['found_remaining_seconds'] = [120, 130]
        self.assertEqual(S.one_more_search_scenario(scenario)['conditional_choice'], 'use_current_engine')

    def test_search_scenario_does_not_accept_optimistic_invalid_probabilities(self):
        scenario = {'current_remaining_seconds': [100, 100], 'search_seconds': [5, 5],
                    'hit_probability': [0, 1.1], 'found_remaining_seconds': [50, 50]}
        with self.assertRaises(ValueError): S.one_more_search_scenario(scenario)


if __name__ == '__main__':
    unittest.main()
