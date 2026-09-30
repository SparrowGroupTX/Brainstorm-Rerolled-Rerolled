"""Manufactured arithmetic checks only; no training or simulator execution."""

import unittest

try:
    from .gae import compute_gae
    from .train import pad_numpy, training_reward
except ImportError:
    from gae import compute_gae
    from train import pad_numpy, training_reward

import numpy as np


def transition(value, reward=0.0, *, terminal=False, valid=True, boundary=None, label=""):
    return {"value": value, "reward": reward, "terminal": terminal, "valid": valid,
            "boundary": terminal if boundary is None else boundary, "label": label}


class GAETests(unittest.TestCase):
    def test_real_terminal_monte_carlo_returns_and_no_input_mutation(self):
        trajectory = [transition(0.4, label="first"), transition(0.6, 1.0, terminal=True, label="last")]
        result = compute_gae(trajectory, bootstrap=99.0, gamma=1.0, gae_lambda=1.0)
        self.assertEqual([entry["label"] for entry in result], ["first", "last"])
        self.assertAlmostEqual(result[0]["advantage"], 0.6)
        self.assertAlmostEqual(result[1]["advantage"], 0.4)
        self.assertEqual([entry["return"] for entry in result], [1.0, 1.0])
        self.assertNotIn("return", trajectory[0])

    def test_rollout_cutoff_uses_observed_successor_bootstrap(self):
        trajectory = [transition(0.3, 0.1), transition(0.4, 0.2)]
        result = compute_gae(trajectory, bootstrap=2.0, gamma=0.5, gae_lambda=0.5)
        self.assertAlmostEqual(result[0]["return"], 0.5)
        self.assertAlmostEqual(result[1]["return"], 1.2)

    def test_censor_or_unsupported_action_has_no_imputed_target(self):
        trajectory = [transition(0.3, 0.1),
                      transition(0.8, float("nan"), valid=False, boundary=True)]
        result = compute_gae(trajectory, bootstrap=999.0, gamma=0.5, gae_lambda=0.9)
        self.assertEqual(len(result), 1)
        self.assertAlmostEqual(result[0]["return"], 0.1 + 0.5 * 0.8)
        self.assertAlmostEqual(result[0]["advantage"], 0.2)

    def test_censored_boundary_does_not_leak_next_episode_value(self):
        trajectory = [transition(0.3, 0.1, label="previous"),
                      transition(0.8, 1000.0, valid=False, boundary=True),
                      transition(50.0, -1.0, terminal=True, label="new_episode")]
        result = compute_gae(trajectory, bootstrap=2000.0, gamma=0.5, gae_lambda=1.0)
        self.assertEqual([entry["label"] for entry in result], ["previous", "new_episode"])
        self.assertAlmostEqual(result[0]["return"], 0.5)
        self.assertAlmostEqual(result[1]["return"], -1.0)

    def test_multiple_true_terminal_episodes_do_not_mix(self):
        trajectory = [transition(0.4, 1.0, terminal=True),
                      transition(0.7, 0.0), transition(0.6, -1.0, terminal=True)]
        result = compute_gae(trajectory, bootstrap=99.0, gamma=1.0, gae_lambda=1.0)
        for entry, expected in zip(result, [1.0, -1.0, -1.0]):
            self.assertAlmostEqual(entry["return"], expected)

    def test_all_invalid_or_empty_batch_has_no_targets(self):
        self.assertEqual(compute_gae([], 0.0), [])
        self.assertEqual(compute_gae([transition(0.8, valid=False, boundary=True)], 0.0), [])

    def test_lambda_zero_is_one_step_td(self):
        result = compute_gae([transition(0.3, 0.1), transition(0.8, 1.0, terminal=True)],
                             bootstrap=0.0, gamma=0.5, gae_lambda=0.0)
        self.assertAlmostEqual(result[0]["return"], 0.5)
        self.assertAlmostEqual(result[1]["return"], 1.0)

    def test_reject_inconsistent_or_nonfinite_target_data(self):
        for entry in (transition(0.3, boundary=True),
                      transition(0.3, terminal=True, boundary=False),
                      transition(float("nan")), transition(0.3, float("inf"))):
            with self.assertRaises(ValueError):
                compute_gae([entry], 0.0)
        with self.assertRaises(ValueError):
            compute_gae([], float("nan"))
        with self.assertRaises(ValueError):
            compute_gae([], 0.0, gamma=1.1)


class TrainingInputTests(unittest.TestCase):
    def test_padding_preserves_candidate_alignment(self):
        observations = [
            {"global": np.ones(3, np.float32), "entities": np.zeros((0, 2), np.float32),
             "candidates": np.full((1, 4), 3.0, np.float32)},
            {"global": np.zeros(3, np.float32), "entities": np.full((2, 2), 2.0, np.float32),
             "candidates": np.arange(12, dtype=np.float32).reshape(3, 4)},
        ]
        global_features, entities, entity_mask, candidates, candidate_mask = pad_numpy(observations)
        self.assertEqual(global_features.shape, (2, 3))
        self.assertEqual(entities.shape, (2, 2, 2))
        self.assertEqual(candidates.shape, (2, 3, 4))
        self.assertEqual(entity_mask.tolist(), [[False, False], [True, True]])
        self.assertEqual(candidate_mask.tolist(), [[True, False, False], [True, True, True]])
        np.testing.assert_array_equal(candidates[1], observations[1]["candidates"])

    def test_real_terminal_shaping_zeroes_successor_potential(self):
        previous = {"blinds_cleared": 23}
        win = training_reward({"outcome": "win", "blinds_cleared": 24}, previous, True)
        loss = training_reward({"outcome": "loss", "blinds_cleared": 23}, previous, True)
        self.assertAlmostEqual(win, 10.0 - 0.0005 - 4.6)
        self.assertAlmostEqual(loss, -1.0 - 0.0005 - 4.6)


if __name__ == "__main__":
    unittest.main()
