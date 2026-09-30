"""Manufactured specialized-wrapper checks: no real reset, RNG, or episode."""
from __future__ import annotations

import copy
from types import SimpleNamespace as NS
import unittest
from unittest.mock import patch
import numpy as np

from . import environment as E
from . import specialized_environment as S
from .objective import CompletionGoal
from .test_environment import state, card


def spec(**statuses):
    keys = sorted(k for k, v in E._catalog.items() if v.get("set") == "Joker")
    values = {k: "complete" for k in keys}
    values.update(statuses)
    return {"schema": "completionist_distinct_v1", "joker_keys": keys,
            "status_by_key": values, "verified_collection": True}


def manufactured(gs=None, goal=None, max_steps=800):
    value = object.__new__(S.SpecializedEnvironment)
    value._gs = gs if gs is not None else state()
    value._goal = CompletionGoal.from_spec(goal or spec(j_joker="missing"))
    value._initialize_tracking(max_steps)
    return value


class SpecializedEnvironmentTests(unittest.TestCase):
    def setUp(self):
        boundary = patch.object(E, "audit_state_boundary", return_value=None)
        self.boundary = boundary.start()
        self.addCleanup(boundary.stop)

    def test_constructor_uses_only_mock_reset_and_fresh_public_scaffold(self):
        gs = state("blind_select", 0)
        gs["round"] = 0
        gs["rng"] = object()
        gs["deck"] = [object()]
        deck, rng = gs["deck"], gs["rng"]
        gs["round_resets"].update(hands=4, discards=3,
            blind_choices={"Small": "bl_small", "Big": "bl_big", "Boss": "bl_hook"})
        with patch.object(E, "apply_patches") as overlay, \
             patch.object(E, "initialize_run", return_value=gs) as reset:
            value = S.SpecializedEnvironment("FIXTURE", goal_spec=spec())
        reset.assert_called_once_with("b_red", 8, "FIXTURE")
        overlay.assert_called_once()
        self.assertIs(value._gs["deck"], deck)
        self.assertIs(value._gs["rng"], rng)
        self.assertEqual(gs["phase"], "blind_select")
        self.assertEqual(gs["blind_on_deck"], "Big")
        self.assertEqual(gs["round_resets"]["blind_states"],
                         {"Small": "Skipped", "Big": "Select", "Boss": "Upcoming"})
        self.assertEqual((gs["skips"], gs["round"], gs["dollars"], gs["chips"]), (1, 0, 4, 0))
        self.assertEqual(gs["round_resets"]["discards"], 3)
        self.assertEqual([j.center_key for j in gs["jokers"]], ["j_perkeo", "j_yorick"])
        for joker in gs["jokers"]:
            self.assertEqual((joker.cost, joker.sell_cost), (20, 10))
            self.assertFalse(joker.edition or joker.debuff or joker.eternal or joker.rental or joker.perishable)
        self.assertEqual(gs["jokers"][1].ability["extra"], {"discards": 23, "xmult": 1})
        self.assertEqual(gs["jokers"][1].ability["yorick_discards"], 23)
        self.assertEqual(gs["used_jokers"], {"j_perkeo": True, "j_yorick": True})
        self.assertIsNone(gs["last_tarot_planet"])
        self.assertEqual(gs["pack_choices_remaining"], 0)
        self.assertFalse(gs["seeded"])
        self.assertEqual(value.blinds_cleared, 0)  # skipping is not clearing

    def test_invalid_goal_or_deck_rejected_before_any_reset(self):
        with patch.object(E, "initialize_run", side_effect=AssertionError("No reset")):
            with self.assertRaises(ValueError):
                S.SpecializedEnvironment("FIXTURE", deck="b_blue", goal_spec=spec())
            with self.assertRaises(ValueError):
                S.SpecializedEnvironment("FIXTURE", stake=1, goal_spec=spec())
            with self.assertRaises(ValueError):
                S.SpecializedEnvironment("FIXTURE", goal_spec={})

    def test_scaffold_rejects_nonfresh_inventory(self):
        gs = state("blind_select", 0)
        gs["jokers"] = [card(key="j_joker", kind="Joker")]
        with self.assertRaisesRegex(E.UnsupportedState, "requires_fresh"):
            S._install_public_opening(gs)

    def test_augmented_dimensions_and_public_target_status(self):
        gs = state("shop", 0)
        gs["shop_cards"] = [card(key="j_joker", kind="Joker")]
        value = manufactured(gs)
        observation = value.observe()
        self.assertEqual(observation["global"].shape, (530,))
        self.assertEqual(observation["entities"].shape, (1, 67))
        self.assertEqual(observation["candidates"].shape[1], 163)
        np.testing.assert_array_equal(observation["entities"][0, 64:], [1, 0, 0])
        buy = next(i for i, a in enumerate(value._actions) if isinstance(a, E.A.BuyCard))
        np.testing.assert_array_equal(observation["candidates"][buy, 160:], [1, 0, 0])
        self.assertTrue(all(v.dtype == np.float32 for v in observation.values()))

    def test_nonterminal_step_uses_augmented_observe_once(self):
        value = manufactured(); value.observe()
        with patch.object(E, "engine_step", return_value=None):
            ob, reward, terminated, truncated, info = value.step(0)
        self.assertEqual(ob["global"].shape, (530,))
        self.assertEqual((reward, terminated, truncated), (0, False, False))
        self.assertEqual(info["objective"], "completionist_distinct_v1")
        self.assertEqual(info["new_gold_keys"], [])
        self.assertEqual(info["actual_awards"], 0)

    def _win(self, *, goal=None, seeded=False, challenge=None):
        gs = state()
        gs.update(seeded=seeded, challenge=challenge, blind_on_deck="Boss")
        gs["round_resets"]["ante"] = 8
        gs["jokers"] = [card(key=k, kind="Joker") for k in
                        ("j_joker", "j_joker", "j_perkeo", "j_yorick", "j_abstract")]
        gs["jokers"][0].debuff = True
        gs["jokers"][1].perishable = True
        value = manufactured(gs, goal or spec(j_joker="missing", j_abstract="unknown"))
        value.observe()
        def final_boss(g, action):
            g.update(phase="round_eval", won=True, chips=300)
            g["round_resets"]["ante"] = 9
        with patch.object(E, "engine_step", side_effect=final_boss):
            return value.step(0)

    def test_verified_win_rewards_distinct_missing_not_copies_or_engine_keys(self):
        ob, reward, terminated, truncated, info = self._win()
        self.assertIsNone(ob)
        self.assertEqual((reward, terminated, truncated), (1, True, False))
        self.assertEqual(info["new_gold_keys"], ["j_joker"])
        self.assertEqual(info["new_gold_count"], 1)
        self.assertEqual(info["actual_awards"], 0)
        self.assertTrue(info["simulated"])
        self.assertFalse(info["seed_equivalent_opening"])
        self.assertEqual(info["clear_receipt"]["blind"], "Boss")

    def test_zero_new_sticker_win_has_zero_reward(self):
        self.assertEqual(self._win(goal=spec())[1], 0)

    def test_seeded_challenge_or_unverified_history_never_awards(self):
        self.assertEqual(self._win(seeded=True)[1], 0)
        self.assertEqual(self._win(challenge={"id": "fixture"})[1], 0)
        goal = spec(j_joker="missing"); goal["verified_collection"] = False
        self.assertEqual(self._win(goal=goal)[1], 0)

    def test_stray_win_loss_unsupported_and_limit_never_award(self):
        for phase, won, expected in (("game_over", True, "loss"),
                                      ("round_eval", True, "unsupported")):
            value = manufactured(); value.observe()
            with patch.object(E, "engine_step", side_effect=lambda g, a: g.update(phase=phase, won=won)):
                result = value.step(0)
            self.assertEqual(result[4]["outcome"], expected)
            self.assertEqual(result[1], 0)
            self.assertEqual(result[4]["new_gold_count"], 0)
        value = manufactured(max_steps=1); value.observe()
        with patch.object(E, "engine_step", return_value=None): result = value.step(0)
        self.assertEqual(result[4]["outcome"], "censored")
        self.assertEqual(result[1], 0)

    def test_fidelity_boundary_still_stops_before_engine(self):
        value = manufactured(); value.observe()
        self.boundary.return_value = "fidelity_fixture"
        with patch.object(E, "engine_step", side_effect=AssertionError("No transition")) as step:
            result = value.step(0)
        step.assert_not_called()
        self.assertEqual(result[4]["outcome"], "unsupported")
        self.assertEqual(result[1], 0)


if __name__ == "__main__":
    unittest.main()
