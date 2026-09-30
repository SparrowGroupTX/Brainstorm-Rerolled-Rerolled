"""Synthetic reporting/profiling protocol cases, never win-rate evidence."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / "tools/advisor_eval/development_report.py"
spec = importlib.util.spec_from_file_location("development_report", MODULE)
D = importlib.util.module_from_spec(spec)
spec.loader.exec_module(D)


class DevelopmentTests(unittest.TestCase):
    def test_terminal_requires_real_completion(self):
        win = {"type": "engine_episode_terminal", "outcome": "win", "game_won": True, "ante": 8,
               "source_profile_completed": True, "source_game_won": True, "game_over": False}
        self.assertEqual(D.classify([win], 0)[0], "win")
        self.assertEqual(D.classify([{**win, "game_won": False}], 0)[0], "error")
        self.assertEqual(D.classify([{**win, "ante": 7}], 0)[0], "error")
        self.assertEqual(D.classify([{**win, "outcome": "loss", "game_won": False, 'game_over': True}], 0)[0], "loss")
        self.assertEqual(D.classify([{**win, 'source_profile_completed': False}], 0)[0], 'error')
        self.assertEqual(D.classify([{**win, 'game_over': True}], 0)[0], 'error')
        legacy = {k: v for k, v in win.items() if k != 'source_profile_completed'}
        self.assertEqual(D.classify([legacy], 0), ('unsupported', 'terminal_source_evidence_missing'))
        self.assertEqual(D.classify([{**win, 'source_game_won': 'true'}], 0)[0], 'error')
        self.assertEqual(D.classify([{**win, 'ante': float('inf')}], 0)[0], 'error')

    def test_timeouts_and_errors_override_partial_terminal(self):
        win = {"type": "engine_episode_terminal", "outcome": "win", "game_won": True, "ante": 8,
               "source_profile_completed": True, "source_game_won": True, "game_over": False}
        self.assertEqual(D.classify([win], "timeout")[0], "timeout")
        self.assertEqual(D.classify([win], 1)[0], "error")
        self.assertEqual(D.classify([win, win], 0)[0], "error")
        self.assertEqual(D.classify([win], 0, [{"line": 1}])[0], "error")
        stop = {'type': 'engine_episode_stopped', 'reason': 'development_action_limit'}
        self.assertEqual(D.classify([win, stop], 0)[0], 'error')
        self.assertEqual(D.classify([stop, stop], 0)[0], 'error')

    def test_score_gaps_are_explicit_and_cannot_qualify(self):
        actions = [{'type': 'engine_episode_action', 'step': i, 'action': {'kind': 'play'}} for i in range(1, 4)]
        rows = actions + [{'type': 'engine_episode_score_verified', 'step': 1, 'scope': 'deterministic_score'},
                          {'type': 'engine_episode_score_unverified', 'step': 2}]
        coverage = D.score_coverage(rows)
        self.assertEqual(coverage['missing_verification_steps'], [3])
        self.assertEqual(coverage['explicit_unverified_scores'], 1)
        self.assertFalse(coverage['complete_exact_or_floor_coverage'])
        self.assertFalse(D.score_coverage([])['complete_exact_or_floor_coverage'])
        self.assertTrue(D.score_coverage(rows[:1] + [rows[3]])['complete_exact_or_floor_coverage'])

    def test_score_coverage_rejects_duplicate_unmatched_and_unknown_scopes(self):
        action = {'type': 'engine_episode_action', 'step': 1, 'action': {'kind': 'play'}}
        checked = {'type': 'engine_episode_score_verified', 'step': 1, 'scope': 'deterministic_score'}
        duplicate = D.score_coverage([action, checked, checked])
        self.assertEqual(duplicate['duplicate_verification_steps'], [1])
        self.assertFalse(duplicate['complete_exact_or_floor_coverage'])
        unmatched = D.score_coverage([action, {**checked, 'step': 2}])
        self.assertEqual(unmatched['unmatched_verification_steps'], [2])
        self.assertFalse(unmatched['complete_exact_or_floor_coverage'])
        unknown = D.score_coverage([action, {**checked, 'scope': 'unverified_random_mean'}])
        self.assertEqual(unknown['invalid_verification_scope_steps'], [1])
        self.assertFalse(unknown['complete_exact_or_floor_coverage'])

    def test_distinct_populations_never_share_a_cohort(self):
        records = []
        for spec, flags in [('A', 'one'), ('B', 'one'), ('B', 'two')]:
            records.append({'challenge': 'fixture', 'seed': 'S', 'outcome': 'censored', 'reason': 'cutoff',
                            'elapsed_seconds': 1, 'provenance': {'profile_spec_digest': spec},
                            'unlock_profile': {'unlock_profile_digest': flags}})
        self.assertEqual(len(D.summarize(records)['cohorts']), 3)

    def test_limits_are_censored_including_legacy_traces(self):
        for outcome in ("unsupported", "censored"):
            row = {"type": "engine_episode_stopped", "outcome": outcome, "reason": "development_action_limit"}
            self.assertEqual(D.classify([row], 0)[0], "censored")
        self.assertEqual(D.classify([], 0)[0], "error")

    def test_unsupported_and_policy_disagreement_are_distinct(self):
        def blocked(reason):
            return [{"type": "engine_probe_blocked", "reason": reason}]
        self.assertEqual(D.classify(blocked("HEADLESS_BOUNDARY unknown callback"), 1)[0], "unsupported")
        self.assertEqual(D.classify(blocked("HEADLESS_BOUNDARY deterministic score disagreement"), 1)[0], "error")
        self.assertEqual(D.classify(blocked("HEADLESS_BOUNDARY policy action rejected by can_use"), 1)[0], "error")

    def test_partial_json_does_not_discard_valid_records(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "trace.log"
            path.write_text('PROBE engine initialized\n{"type":"valid"}\n{"type":', encoding="utf-8")
            rows, errors = D.parse_trace(path)
        self.assertEqual(rows, [{"type": "valid"}])
        self.assertEqual(len(errors), 1)
        self.assertEqual(D.classify(rows, "timeout", errors)[0], "timeout")

    def test_profile_percentiles_and_empty_data(self):
        data = D.distribution([1, 2, 3, 4, None, float("nan"), -1])
        self.assertEqual((data["count"], data["p50"], data["p95"]), (4, 2, 4))
        self.assertIsNone(D.distribution([])["mean"])

    def test_every_attempt_stays_in_denominator_and_cohort(self):
        def record(outcome, policy="fixture", challenge="fixture_challenge"):
            return {"challenge": challenge, "seed": "fixture", "outcome": outcome, "reason": outcome,
                    "elapsed_seconds": 1, "trace": "fixture.log", "command": ["fixture"],
                    "provenance": {"policy_digest": policy, "start_distribution": {"kind": "ordinary"}}}
        records = [record(outcome) for outcome in ("win", "loss", "error", "timeout", "unsupported", "censored")]
        result = D.summarize(records + [record("win", "other")])
        self.assertEqual(result["attempted"], 7)
        self.assertEqual(len(result["cohorts"]), 2)
        cohort = next(row for row in result["cohorts"] if row["policy_digest"] == "fixture")
        self.assertEqual(cohort["attempted"], 6)
        self.assertIsNone(cohort["observed_complete_win_rate"])
        self.assertIsNone(result["user_completion_time_estimate"])

    def test_episode_profiles_keep_stalled_decision(self):
        rows = [{"type": "engine_probe_provenance", "challenge": "fixture", "seed": "S"},
                {"type": "engine_episode_profile", "step": 1, "advisor_seconds": .2, "score_calls": 10},
                {"type": "engine_episode_decision_started", "step": 2, "phase": "hand"}]
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "trace.log"
            path.write_text("\n".join(json.dumps(row) for row in rows), encoding="utf-8")
            record = D.episode_record(path, "fixture", "S", "timeout", 1, ["fixture"])
        self.assertEqual(record["outcome"], "timeout")
        self.assertEqual(record["unfinished_decision"]["step"], 2)
        self.assertEqual(record["decision_metrics"]["score_calls"]["total"], 10)

    def test_loss_context_exposes_observations_and_replay_state(self):
        previous = {'phase': 'hand', 'discards_left': 2}
        current = {'ante': 5, 'chips': 400, 'hands_left': 0, 'hand_size': 8,
                   'blind': {'key': 'bl_plant', 'boss': True, 'chips': 1000},
                   'consumeables': [{'key': 'c_death'}],
                   'playing_cards': [{'ability': {}}, {'ability': {'perma_debuff': True}}]}
        rows = [{'type': 'engine_episode_terminal_context', 'snapshot': current,
                 'last_decision': {'step': 31, 'action': {'kind': 'play', 'indices': [1]}, 'snapshot': previous}}]
        result = D.loss_analysis(rows, 'loss', 'game_over')
        self.assertEqual(result['remaining_score_deficit'], 600)
        self.assertEqual(result['usable_cards'], 1)
        self.assertEqual(result['last_step'], 31)
        self.assertEqual(result['pre_action_snapshot'], previous)
        self.assertIn('consumables_unspent', result['groups'])
        self.assertIn('discards_remaining_at_last_play', result['groups'])
        self.assertIn('active_boss_at_loss', result['groups'])
        self.assertIn('causal claims require replay', result['interpretation'])

    def test_missing_loss_context_does_not_invent_resources(self):
        result = D.loss_analysis([], 'loss', 'game_over')
        self.assertEqual(result['groups'], ['terminal_loss_context_missing'])
        self.assertIsNone(result['usable_cards'])
        self.assertIsNone(result['remaining_score_deficit'])

    def test_failure_context_separates_errors_from_policy_losses(self):
        rows = [{'type': 'engine_episode_failure_context', 'last_decision':
                 {'step': 8, 'snapshot': {'phase': 'shop'}, 'action': {'kind': 'buy'}}}]
        result = D.loss_analysis(rows, 'error', 'HEADLESS_BOUNDARY policy action rejected')
        self.assertEqual(result['groups'], ['action_legality_defect'])
        self.assertEqual(result['last_step'], 8)
        self.assertNotIn('insufficient_blind_score', result['groups'])

    def test_timeout_groups_only_observed_stall_location(self):
        rows = [{'type': 'engine_episode_decision_started', 'step': 3}]
        self.assertEqual(D.loss_analysis(rows, 'timeout', '')['groups'], ['decision_latency_timeout'])
        rows.append({'type': 'engine_episode_profile', 'step': 3})
        self.assertEqual(D.loss_analysis(rows, 'timeout', '')['groups'], ['source_transition_timeout'])

    def test_hard_timeout_retains_current_input_without_inventing_selected_action(self):
        state = {'phase': 'shop', 'ante': 3, 'dollars': 12, 'shop_jokers': [{'key': 'j_joker'}]}
        rows = [{'type': 'engine_episode_action', 'step': 4, 'action': {'kind': 'cash_out'}},
                {'type': 'engine_episode_decision_started', 'step': 5, 'snapshot': state}]
        result = D.loss_analysis(rows, 'timeout', 'wall_clock_limit')
        self.assertEqual(result['snapshot'], state)
        self.assertEqual(result['pre_action_snapshot'], state)
        self.assertEqual(result['last_step'], 5)
        self.assertIsNone(result['last_action'])
        self.assertEqual(result['context_trace_type'], 'engine_episode_decision_started')
        self.assertIsNone(result['remaining_score_deficit'])
        rows.append({'type': 'engine_episode_profile', 'step': 5})
        resolved = D.loss_analysis(rows, 'timeout', 'wall_clock_limit')
        self.assertEqual(resolved['groups'], ['source_transition_timeout'])
        self.assertIsNone(resolved['snapshot'])


if __name__ == "__main__":
    unittest.main()
