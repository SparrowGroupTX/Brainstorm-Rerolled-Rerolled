"""Manufactured curriculum checks: no simulator initialization or optimization.

Worker protocol tests replace the complete environment module with a fake before
calling worker synchronously; they never import or construct the real engine.
"""

import sys
import types
import unittest
from unittest.mock import patch

from . import train


class FakeConnection:
    def __init__(self, commands):
        self.commands = iter(commands)
        self.sent = []
        self.closed = False

    def recv(self):
        return next(self.commands)

    def send(self, value):
        self.sent.append(value)

    def close(self):
        self.closed = True


class CurriculumWorkerTests(unittest.TestCase):
    def run_fake_worker(self, commands, *, default_stake=8, failure=None):
        constructions, actions = [], []

        class FakeEnvironment:
            def __init__(self, seed, *, deck, stake, max_steps):
                constructions.append((seed, deck, stake, max_steps))
                if failure is not None:
                    raise failure
                self.stake = stake

            def observe(self):
                return {"manufactured_public_stake": self.stake}

            def step(self, action):
                actions.append((self.stake, action))
                return self.observe(), 0.0, False, False, {"outcome": "ongoing"}

        module_name = train.__package__ + ".environment"
        fake = types.ModuleType(module_name)
        fake.Environment = FakeEnvironment
        connection = FakeConnection(commands)
        with patch.dict(sys.modules, {module_name: fake}):
            train.worker(connection, "manufactured_deck", default_stake, 800)
        return connection, constructions, actions

    def test_reset_tuple_changes_stake_without_changing_seed_or_deck(self):
        connection, constructions, actions = self.run_fake_worker([
            ("reset", ("TFIXTURE1", 1)), ("step", 3),
            ("reset", ("TFIXTURE8", 8)), ("step", 7), ("close", None),
        ])
        self.assertEqual(constructions, [
            ("TFIXTURE1", "manufactured_deck", 1, 800),
            ("TFIXTURE8", "manufactured_deck", 8, 800),
        ])
        self.assertEqual(actions, [(1, 3), (8, 7)])
        self.assertEqual(connection.sent[0][0], {"manufactured_public_stake": 1})
        self.assertEqual(connection.sent[2][0], {"manufactured_public_stake": 8})
        self.assertTrue(connection.closed)

    def test_legacy_scalar_reset_retains_fixed_evaluation_stake(self):
        connection, constructions, _ = self.run_fake_worker([
            ("reset", "FFIXTURE"), ("close", None),
        ], default_stake=8)
        self.assertEqual(constructions, [("FFIXTURE", "manufactured_deck", 8, 800)])
        self.assertEqual(connection.sent[0][4]["outcome"], "ongoing")

    def test_reset_failure_remains_unresolved_not_a_game_loss(self):
        class UnsupportedState(RuntimeError):
            pass

        for failure, expected in [(UnsupportedState("manufactured"), "unsupported"),
                                  (RuntimeError("manufactured"), "error")]:
            with self.subTest(outcome=expected):
                connection, _, actions = self.run_fake_worker([
                    ("reset", ("TFIXTURE", 1)), ("close", None),
                ], failure=failure)
                observation, reward, terminated, truncated, info = connection.sent[0]
                self.assertIsNone(observation)
                self.assertEqual(reward, 0.0)
                self.assertFalse(terminated)
                self.assertTrue(truncated)
                self.assertEqual(info["outcome"], expected)
                self.assertEqual(actions, [])

    def test_seed_roles_are_disjoint_and_reproducible(self):
        families = {role: [train.seed_for(namespace, i) for i in range(32)] for role, namespace in [
            ("T", "L355TRAIN02"), ("D", "L355DEV"), ("F", "L355FINAL"), ("S", "L355SMOKE")
        ]}
        for role, seeds in families.items():
            self.assertTrue(all(seed.startswith(role) and len(seed) == 8 for seed in seeds))
        all_seeds = [seed for seeds in families.values() for seed in seeds]
        self.assertEqual(len(set(all_seeds)), len(all_seeds))
        self.assertEqual(train.seed_for("L355TRAIN02", 7), train.seed_for("L355TRAIN02", 7))
        with self.assertRaises(ValueError):
            train.seed_for("unregistered", 0)
        with self.assertRaises(ValueError):
            train.seed_for("L355FINAL", -1)


if __name__ == "__main__":
    unittest.main()
