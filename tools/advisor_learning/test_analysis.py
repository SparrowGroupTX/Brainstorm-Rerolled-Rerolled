"""Manufactured analysis records only; no simulator/model imports or execution."""
from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest

from .analyze import analyze_job, analyze_records, markdown_report


STARTERS = {"j_perkeo": 170, "j_yorick": 223}


def episode(index, seed, policy, outcome="loss", *, progress=2, awards=()):
    row = {"episode_index": index, "seed": seed, "policy": policy, "outcome": outcome,
           "won": outcome == "win", "new_gold_keys": list(awards), "new_gold_count": len(awards),
           "namespace": "L355FINAL", "deck": "b_red", "stake": 8,
           "goal_digest": "manufactured", "scope": "manufactured", "simulator_patch": "manufactured"}
    if progress is not None:
        row["blinds_cleared"] = progress
    if outcome == "win":
        row["clear_receipt"] = {"ante": 8, "after_ante": 9, "blind": "Boss", "target": 100, "chips": 120,
                                "before_phase": "selecting_hand", "after_phase": "round_eval",
                                "threshold_met": True, "saved": False,
                                "scope": "simulator_play_to_round_eval"}
    return row


def audit(rows, actions=(), **kwargs):
    return analyze_records(rows, list(actions), starter_ids=STARTERS, missing_count=91, **kwargs)


class AnalysisTests(unittest.TestCase):
    def test_unresolved_rewards_are_unknown_and_bounds_are_not_confidence_intervals(self):
        rows = [episode(0, "a", "learned", "win", awards=("j_a", "j_b")),
                episode(1, "b", "learned", "censored", progress=4),
                episode(2, "c", "learned", "unsupported", progress=None)]
        report = audit(rows)
        policy = report["policies"]["learned"]
        self.assertEqual(policy["observed_terminal_new_gold_sum"], 2)
        self.assertEqual(policy["unresolved_attempts"], 2)
        self.assertIsNone(policy["mean_new_gold_full_cohort"])
        self.assertEqual(policy["sample_new_gold_mean_bounds"], [2 / 3, (2 + 2 * 91) / 3])
        self.assertEqual(policy["observed_progress_records"], 2)
        self.assertEqual(policy["missing_progress_records"], 1)
        self.assertEqual(policy["mean_observed_blinds_cleared_prefix"], 3)
        self.assertIsNone(policy["mean_blinds_cleared_full_cohort"])
        self.assertIn("NOT a confidence interval", policy["bounds_interpretation"])
        self.assertIn("not confidence intervals", markdown_report(report))

    def test_completed_cohort_counts_distinct_awards_per_run_without_campaign_claim(self):
        rows = [episode(0, "a", "learned", "win", awards=("j_a", "j_b")),
                episode(1, "b", "learned", "win", awards=("j_a",)),
                episode(2, "c", "learned", "loss")]
        policy = audit(rows)["policies"]["learned"]
        self.assertEqual(policy["observed_terminal_new_gold_sum"], 3)
        self.assertEqual(policy["distinct_new_gold_keys_across_verified_wins"], ["j_a", "j_b"])
        self.assertEqual(policy["mean_new_gold_full_cohort"], 1)
        self.assertEqual(policy["sample_new_gold_mean_bounds"], [1, 1])

    def test_invalid_or_missing_win_evidence_does_not_become_verified_reward(self):
        for mutate in [lambda row: row.pop("clear_receipt"),
                       lambda row: row.update(won=False),
                       lambda row: row.update(new_gold_keys=["j_a", "j_a"], new_gold_count=2),
                       lambda row: row["clear_receipt"].update(chips=99),
                       lambda row: row.pop("new_gold_count")]:
            row = episode(0, "a", "learned", "win", awards=("j_a",))
            mutate(row)
            policy = audit([row])["policies"]["learned"]
            self.assertEqual(policy["verified_terminal_wins"], 0)
            self.assertEqual(policy["observed_terminal_new_gold_sum"], 0)
            self.assertEqual(policy["unresolved_attempts"], 1)

    def test_final_receipt_requires_exact_ante_phase_and_consistent_flags(self):
        poisons = [
            {"ante": 9, "after_ante": 10},
            {"ante": 8.0},
            {"after_ante": 8},
            {"after_ante": None},
            {"before_phase": "shop"},
            {"after_phase": "selecting_hand"},
            {"blind": "Small"},
            {"scope": "unverified"},
            {"threshold_met": False},
            {"threshold_met": None},
            {"saved": None},
            {"threshold_met": 1},
            {"chips": 25, "threshold_met": False, "saved": False},
            {"chips": 25, "threshold_met": True, "saved": True},
        ]
        for poison in poisons:
            with self.subTest(poison=poison):
                row = episode(0, "a", "learned", "win", awards=("j_a",))
                row["clear_receipt"].update(poison)
                policy = audit([row])["policies"]["learned"]
                self.assertEqual(policy["verified_terminal_wins"], 0)
                self.assertEqual(policy["observed_terminal_new_gold_sum"], 0)
                self.assertEqual(policy["unresolved_attempts"], 1)

    def test_explicit_saved_final_clear_is_verified_only_as_simulator_evidence(self):
        for chips, threshold_met in [(25, False), (120, True)]:
            with self.subTest(chips=chips):
                row = episode(0, "a", "learned", "win", awards=("j_a",))
                row["clear_receipt"].update(chips=chips, threshold_met=threshold_met, saved=True)
                self.assertNotIn("hands_left", row["clear_receipt"])
                report = audit([row])
                policy = report["policies"]["learned"]
                self.assertEqual(policy["verified_terminal_wins"], 1)
                self.assertEqual(policy["observed_terminal_new_gold_sum"], 1)
                self.assertEqual(policy["unresolved_attempts"], 0)
                self.assertFalse(report["simulator_qualified"])
                self.assertFalse(report["real_game_win_claim"])
                self.assertEqual(report["actual_player_awards"], 0)

    def test_pair_validation_and_censored_progress_remain_separate(self):
        rows = [episode(0, "a", "heuristic", progress=2), episode(1, "a", "learned", progress=3),
                episode(2, "b", "heuristic", progress=4), episode(3, "b", "learned", "censored", progress=4),
                episode(4, "c", "heuristic", progress=2), episode(5, "c", "learned", progress=None)]
        pairing = audit(rows)["pairing"]
        self.assertEqual(pairing["valid_pair_count"], 3)
        self.assertEqual(pairing["progress_counts"]["all_observed_pairs"], {"higher": 1, "equal": 1, "unknown": 1})
        self.assertTrue(pairing["pairs"][1]["candidate_unresolved"])
        self.assertIsNone(pairing["pairs"][1]["candidate_new_gold_difference"])
        self.assertEqual(pairing["pairs"][1]["progress_scope"], "observed_prefix_only_not_final_progress")
        changed = deepcopy(rows)
        changed[1]["stake"] = 1
        changed.append(episode(6, "a", "learned"))
        self.assertFalse(audit(changed)["pairing"]["all_seeds_validly_paired"])
        self.assertFalse(audit(rows[:1])["pairing"]["all_seeds_validly_paired"])

    def test_initial_starter_sales_and_reorder_streaks_use_observed_actions(self):
        rows = [episode(0, "a", "learned"), episode(1, "b", "learned")]
        actions = [
            {"episode_index": 0, "step": 1, "candidate_kind": 9, "target_catalog_id": 223},
            {"episode_index": 0, "step": 2, "candidate_kind": 9, "target_catalog_id": 170},
            {"episode_index": 0, "step": 3, "candidate_kind": 15},
            {"episode_index": 0, "step": 4, "candidate_kind": 16},
            {"episode_index": 0, "step": 5, "candidate_kind": 15},
            {"episode_index": 0, "step": 6, "candidate_kind": 0},
        ]
        report = audit(rows, actions)
        behavior = report["policies"]["learned"]["behavior"]
        self.assertEqual(behavior["episodes_first_two_actions_sell_both_starters"], 1)
        self.assertEqual(behavior["episodes_with_observed_first_two_actions"], 1)
        self.assertEqual(behavior["reorder_like_actions"], 3)
        self.assertEqual(behavior["maximum_consecutive_reorder_actions"], 3)
        self.assertIn("not proved", report["behavior_limit"])

    def test_duplicate_episode_identity_rejected(self):
        with self.assertRaises(ValueError):
            audit([episode(0, "a", "learned"), episode(0, "b", "heuristic")])

    def test_completed_job_gate_prevents_output_for_running_job(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            (directory / "receipt.json").write_text(json.dumps({"status": "running", "returncode": None}))
            with self.assertRaises(ValueError):
                analyze_job(directory)
            self.assertFalse((directory / "analysis.json").exists())
            self.assertFalse((directory / "analysis.md").exists())


if __name__ == "__main__":
    unittest.main()
