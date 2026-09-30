"""Manufactured callback-order comparison for Booster use."""
from __future__ import annotations

from copy import deepcopy
import hashlib
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

from . import simulator_patches as patches
from .lifecycle_contract import compare_lifecycle
from .lifecycle_reference_458 import source_rule_open_callback
from .test_lifecycle_457 import candidate_stock, cases, SIM

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(SIM))
from jackdaw.engine import actions as A, game as G


def callback_open(*, baseline: bool = False) -> dict:
    fixture = cases()[0]  # Physical slot 2, compact offer index 0.
    _, gs = candidate_stock(fixture)
    gs["rng"] = None  # Exclude pack-content generation.
    observations = []

    def observe(state, **_kwargs):
        observations.append(deepcopy(state["current_round"]["used_packs"]))
        return []

    handler = G._advisor_previous_open_booster_457 if baseline else G._handle_open_booster
    with patch.object(G, "_handle_open_booster", new=handler), \
         patch.object(G, "_fire_shop_joker_context", new=observe):
        G.step(gs, A.OpenBooster(card_index=0))
    assert len(observations) == 1
    return {
        "events": [{"event": "opening_callback_input", "slot": 2,
                    "stored_key": observations[0][1]}],
        "state": {"used_packs": deepcopy(gs["current_round"]["used_packs"]),
                  "cash": gs["dollars"], "phase": gs["phase"].value},
    }


def compare_open(*, baseline: bool = False) -> dict:
    fixture = cases()[0]
    expected = source_rule_open_callback(fixture["used_packs"], slot=2,
                                         key="p_arcana_normal_1", cash=4, price=4)
    actual = callback_open(baseline=baseline)
    paths = {
        "reference": ROOT / "tools/advisor_learning/lifecycle_reference_458.py",
        "candidate": ROOT / "tools/advisor_learning/lifecycle_458.py",
        "integration": ROOT / "tools/advisor_learning/simulator_patches.py",
        "test": Path(__file__),
    }
    manifest = {
        "files_sha256": {name: hashlib.sha256(path.read_bytes()).hexdigest()
                         for name, path in paths.items()},
        "candidate": "old_457_order" if baseline else patches.PATCH_ID,
        "source_member_sha256": "c88a74ca3a8fa8ace0ce46ad10a97238f347c292842c9164d11136fe9952c101",
        "original_source_executed": False,
    }
    return compare_lifecycle(
        "booster_open_callback_order", manifest, expected, actual,
        {"command": "python -B -m unittest tools.advisor_learning.test_lifecycle_458 -v"},
    )


class Lifecycle458Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        patches.apply_patches(SIM)

    def test_old_order_observes_unconsumed_key(self):
        comparison = compare_open(baseline=True)
        self.assertEqual(comparison["first_difference"], {
            "field": "events[0].stored_key", "expected": "USED",
            "actual": "p_arcana_normal_1",
        })

    def test_repaired_order_observes_used_before_callback(self):
        comparison = compare_open()
        self.assertTrue(comparison["agreement"], comparison["first_difference"])

    def test_invalid_actions_leave_cash_and_slot_intact(self):
        fixture = cases()[0]
        for change, action in (
            ({"phase": A.GamePhase.ROUND_EVAL}, A.OpenBooster(card_index=0)),
            ({}, A.OpenBooster(card_index=1)),
            ({"dollars": 3}, A.OpenBooster(card_index=0)),
        ):
            with self.subTest(change=change, action=action):
                _, gs = candidate_stock(fixture)
                gs.update(change)
                before = (gs["dollars"], deepcopy(gs["current_round"]["used_packs"]))
                with self.assertRaises(G.IllegalActionError):
                    G.step(gs, action)
                self.assertEqual((gs["dollars"], gs["current_round"]["used_packs"]), before)


if __name__ == "__main__":
    unittest.main()
