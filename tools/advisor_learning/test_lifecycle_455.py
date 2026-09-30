"""Manufactured, settled cash-out/shop bookkeeping comparisons."""
from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

from . import simulator_patches as patches
from .lifecycle_contract import compare_lifecycle
from .lifecycle_reference_455 import source_rule_reference

ROOT = Path(__file__).resolve().parents[2]
SIM = ROOT / "tools/advisor_eval/development355/external/jackdaw"
HERE = ROOT / "tools/advisor_eval/development455"
FIXTURES = HERE / "fixtures.json"
sys.path.insert(0, str(SIM))
from jackdaw.engine.actions import CashOut, GamePhase
from jackdaw.engine.economy import RoundEarnings
from jackdaw.engine import game as G


def cases() -> dict[str, dict]:
    return {case["id"]: case for case in json.loads(FIXTURES.read_text(
        encoding="utf-8"))["cases"]}


def manifest(fixture: dict, *, baseline: bool = False) -> dict:
    paths = {
        "fixture_set": FIXTURES,
        "candidate_overlay_455": ROOT / "tools/advisor_learning/lifecycle_455.py",
        "overlay_integration": ROOT / "tools/advisor_learning/simulator_patches.py",
        "reference_model": ROOT / "tools/advisor_learning/lifecycle_reference_455.py",
        "comparator": ROOT / "tools/advisor_learning/lifecycle_contract.py",
        "test_harness": ROOT / "tools/advisor_learning/test_lifecycle_455.py",
        "receipt_writer": HERE / "qualify_manufactured.py",
        "pinned_game": SIM / "jackdaw/engine/game.py",
        "pinned_economy": SIM / "jackdaw/engine/economy.py",
        "pinned_shop": SIM / "jackdaw/engine/shop.py",
    }
    return {
        "sources_sha256": {name: hashlib.sha256(path.read_bytes()).hexdigest()
                           for name, path in paths.items()},
        "original_archive_sha256": "0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47",
        "original_button_callbacks_sha256": "c88a74ca3a8fa8ace0ce46ad10a97238f347c292842c9164d11136fe9952c101",
        "fixture_sha256": hashlib.sha256(json.dumps(fixture, sort_keys=True).encode()).hexdigest(),
        "candidate_patch": "pinned_unpatched_cash_out" if baseline else patches.PATCH_ID,
        "reference": "source-derived handwritten settled model; original cash_out not executed",
    }


def candidate_transition(fixture: dict, *, baseline: bool = False) -> dict:
    gs = {
        "phase": GamePhase.ROUND_EVAL,
        "dollars": fixture["cash"],
        "round_earnings": RoundEarnings(total=fixture["earnings_total"]),
        "current_round": deepcopy(fixture["current_round"]),
        "round_resets": deepcopy(fixture["round_resets"]),
        "round_bonus": deepcopy(fixture["round_bonus"]),
        "previous_round": deepcopy(fixture["previous_round"]),
        "jokers": [], "awarded_tags": [], "rng": None,
        "shop_cards": [], "shop_vouchers": [], "shop_boosters": [],
    }
    gs.update(fixture["flags"])
    stock_snapshots = []

    def empty_stock(state):
        stock_snapshots.append({
            "cash": state["dollars"],
            "shop_phase": state["phase"].value,
            "hands_left": state["current_round"]["hands_left"],
            "discards_left": state["current_round"]["discards_left"],
            "jokers_purchased": state["current_round"]["jokers_purchased"],
            "shop_free_present": "shop_free" in state,
            "shop_d6ed_present": "shop_d6ed" in state,
            "previous_round": deepcopy(state["previous_round"]),
        })
        state["shop_cards"] = []
        state["shop_vouchers"] = []
        state["shop_boosters"] = []

    with patch.object(G, "_populate_shop", new=empty_stock):
        if baseline:
            with patch.object(G, "_handle_cash_out", new=G._advisor_original_cash_out):
                G.step(gs, CashOut())
        else:
            G.step(gs, CashOut())
    assert len(stock_snapshots) == 1
    return {
        "events": [
            {"phase": "cash_out", "event": "payment_settled",
             "cash_before": fixture["cash"], "delta": fixture["earnings_total"],
             "cash_after": gs["dollars"]},
            {"phase": "shop_entry", "event": "shop_population_input",
             **stock_snapshots[0]},
        ],
        "state": {
            "phase": gs["phase"].value, "cash": gs["dollars"],
            "current_round": deepcopy(gs["current_round"]),
            "round_resets": deepcopy(gs["round_resets"]),
            "round_bonus": deepcopy(gs["round_bonus"]),
            "previous_round": deepcopy(gs["previous_round"]),
            "shop_free_present": "shop_free" in gs,
            "shop_d6ed_present": "shop_d6ed" in gs,
            "shop_cards": deepcopy(gs["shop_cards"]),
            "shop_vouchers": deepcopy(gs["shop_vouchers"]),
            "shop_boosters": deepcopy(gs["shop_boosters"]),
        },
    }


def compare_case(fixture: dict, *, baseline: bool = False) -> dict:
    return compare_lifecycle(
        fixture["id"], manifest(fixture, baseline=baseline),
        source_rule_reference(fixture),
        candidate_transition(fixture, baseline=baseline),
        {"fixture_id": fixture["id"],
         "command": "python -m unittest tools.advisor_learning.test_lifecycle_455 -v"},
    )


class Lifecycle455Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        patches.apply_patches(SIM)
        cls.cases = cases()

    def test_pinned_cash_out_first_difference_is_shop_resource(self):
        comparison = compare_case(self.cases["minimal_stale_resources"], baseline=True)
        self.assertFalse(comparison["agreement"])
        self.assertEqual(comparison["first_difference"], {
            "field": "events[1].discards_left", "expected": 3, "actual": 0,
        })

    def test_repaired_main_controls_and_heldout(self):
        for fixture in self.cases.values():
            with self.subTest(case=fixture["id"]):
                comparison = compare_case(fixture)
                self.assertTrue(comparison["agreement"], comparison["first_difference"])

    def test_previous_round_other_fields_survive(self):
        fixture = self.cases["heldout_zero_payment_with_carry"]
        result = candidate_transition(fixture)
        self.assertEqual(result["events"][1]["previous_round"],
                         {"dollars": 12, "carry_marker": "retain"})
        self.assertEqual(result["state"]["previous_round"],
                         {"dollars": 12, "carry_marker": "retain"})
        self.assertEqual(result["state"]["current_round"]["hands_played"], 2)

    def test_invalid_phase_does_not_apply_shop_entry_reset(self):
        gs = {"phase": GamePhase.SHOP,
              "current_round": {"hands_left": 0, "discards_left": 0},
              "round_resets": {"hands": 4, "discards": 3},
              "round_bonus": {"next_hands": 0, "discards": 0},
              "previous_round": {"dollars": 1}}
        before = deepcopy(gs)
        with self.assertRaises(G.IllegalActionError):
            G.step(gs, CashOut())
        self.assertEqual(gs, before)

    def test_wrong_order_negative_control_is_pure(self):
        fixture = self.cases["minimal_stale_resources"]
        expected = source_rule_reference(fixture)
        wrong = deepcopy(expected)
        wrong["events"][0], wrong["events"][1] = wrong["events"][1], wrong["events"][0]
        before_expected, before_wrong = deepcopy(expected), deepcopy(wrong)
        comparison = compare_lifecycle(fixture["id"] + "_wrong_order",
                                       manifest(fixture), expected, wrong,
                                       {"mutation": "swap first two observations"})
        self.assertFalse(comparison["agreement"])
        self.assertTrue(comparison["first_difference"]["field"].startswith("events[0]"))
        self.assertEqual((expected, wrong), (before_expected, before_wrong))


if __name__ == "__main__":
    unittest.main()
