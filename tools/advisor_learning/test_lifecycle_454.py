"""Manufactured Golden round-end/cash-out comparisons, no episode execution."""
from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest

from . import simulator_patches as patches
from .lifecycle_contract import compare_lifecycle
from .lifecycle_reference_454 import source_rule_reference

ROOT = Path(__file__).resolve().parents[2]
SIM = ROOT / "tools/advisor_eval/development355/external/jackdaw"
FIXTURES = ROOT / "tools/advisor_eval/development454/fixtures.json"
sys.path.insert(0, str(SIM))
from jackdaw.engine.card import Card
from jackdaw.engine import game as G
from jackdaw.engine.economy import calculate_round_earnings


def cases():
    return {case["id"]: case for case in json.loads(FIXTURES.read_text(encoding="utf-8"))["cases"]}


def manifest(fixture, baseline=False):
    paths = {
        "fixture_set": FIXTURES,
        "candidate_overlay_453": ROOT / "tools/advisor_learning/lifecycle_453.py",
        "candidate_overlay_454": ROOT / "tools/advisor_learning/lifecycle_454.py",
        "overlay_integration": ROOT / "tools/advisor_learning/simulator_patches.py",
        "reference_model": ROOT / "tools/advisor_learning/lifecycle_reference_454.py",
        "comparator": ROOT / "tools/advisor_learning/lifecycle_contract.py",
        "test_harness": ROOT / "tools/advisor_learning/test_lifecycle_454.py",
        "receipt_writer": ROOT / "tools/advisor_eval/development454/qualify_manufactured.py",
        "pinned_game": SIM / "jackdaw/engine/game.py",
        "pinned_jokers": SIM / "jackdaw/engine/jokers.py",
        "pinned_round_lifecycle": SIM / "jackdaw/engine/round_lifecycle.py",
        "pinned_economy": SIM / "jackdaw/engine/economy.py",
        "pinned_card": SIM / "jackdaw/engine/card.py",
        "retained_original_card": ROOT / "tools/advisor_eval/runs/chicot_order_source1/source/card.lua",
        "retained_original_ease_dollars": ROOT / "tools/advisor_eval/runs/chicot_order_source1/source/functions/common_events.lua",
        "retained_state_events_excerpt": ROOT / "tools/advisor_eval/runs/gold299_20260914/M02/state_events_source_references.json",
    }
    return {"sources_sha256": {name: hashlib.sha256(path.read_bytes()).hexdigest()
                               for name, path in paths.items()},
            "fixture_sha256": hashlib.sha256(json.dumps(fixture, sort_keys=True).encode()).hexdigest(),
            "candidate_patch": "pinned_unpatched_game_eor" if baseline else patches.PATCH_ID,
            "reference": "source-derived handwritten model; original callbacks not executed"}


def candidate_transition(fixture, end_fn=None):
    row = []
    for item in fixture["jokers"]:
        card = Card(center_key=item["center_key"], sort_id=item["physical_id"])
        card.set_ability(item["center_key"])
        if item["perishable"]:
            card.set_perishable(True)
            card.ability["perish_tally"] = item["tally"]
            card.perish_tally = item["tally"]
        card.set_rental(item["rental"])
        card.debuff = item["debuff"]
        card.edition = item["edition"]
        row.append(card)
    gs = {"jokers": row, "dollars": fixture["cash"], "hand_size": 8,
          "current_round": {"hands_left": 0, "discards_left": 0, "discards_used": 0},
          "rental_rate": 3, "_advisor_lifecycle_trace": []}
    eor = (end_fn or G._joker_end_of_round_effects)(gs)
    raw = gs["_advisor_lifecycle_trace"]
    assert len(raw) == len(row)
    events = [{"phase": "round_end", "event": "joker_maintenance_settled",
               "physical_id": raw[i]["physical_id"],
               "rental_requested": fixture["jokers"][i]["rental"],
               "before": {"tally": raw[i]["before"]["tally"],
                          "debuff": raw[i]["before"]["debuff"]},
               "after": {"tally": raw[i]["after"]["tally"],
                         "debuff": raw[i]["after"]["debuff"]}}
              for i in range(len(row))]
    settled_cash = gs["dollars"]
    events.append({"phase": "round_end", "event": "rental_queue_settled",
                   "requests": sum(bool(c["rental"]) for c in fixture["jokers"]),
                   "cash_before": fixture["cash"], "cash_after": settled_cash})
    events.append({"phase": "cashout_eval", "event": "joker_bonus_total",
                   "dollars": eor["dollars_earned"]})
    earnings = calculate_round_earnings(
        blind=SimpleNamespace(dollars=0), hands_left=0, discards_left=0,
        money=settled_cash, jokers=row, game_state=gs,
        joker_dollars=eor["dollars_earned"])
    events.append({"phase": "cashout_eval", "event": "earnings",
                   "joker_dollars": earnings.joker_dollars,
                   "interest": earnings.interest, "total": earnings.total})
    # This is the arithmetic of game._cash_out's payout assignment, not its
    # full shop/deck-shuffle transition.
    paid_cash = settled_cash + earnings.total
    events.append({"phase": "cashout_paid", "event": "payment",
                   "cash_before": settled_cash, "cash_after": paid_cash})
    return {"events": events,
            "state": {"phase": "cashout_paid", "cash": paid_cash,
                      "jokers": [
                          {"physical_id": c.sort_id, "center_key": c.center_key,
                           "perishable": c.perishable,
                           "tally": c.ability.get("perish_tally", c.perish_tally),
                           "debuff": c.debuff, "rental": c.rental,
                           "edition": c.edition} for c in row]}}


def compare_case(fixture, end_fn=None):
    return compare_lifecycle(
        fixture["id"], manifest(fixture, baseline=end_fn is not None),
        source_rule_reference(fixture), candidate_transition(fixture, end_fn=end_fn),
        {"fixture_id": fixture["id"],
         "command": "python -m unittest tools.advisor_learning.test_lifecycle_454 -v"})


class Lifecycle454Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        patches.apply_patches(SIM)
        cls.cases = cases()

    def test_old_candidate_first_difference_is_final_life_bonus(self):
        comparison = compare_case(self.cases["golden_final_life_minimal"],
                                  end_fn=G._advisor_original_joker_eor)
        self.assertFalse(comparison["agreement"])
        self.assertEqual(comparison["first_difference"], {
            "field": "events[2].dollars", "expected": 0, "actual": 4})

    def test_repair_controls_and_reversed_heldout_row(self):
        for fixture in self.cases.values():
            with self.subTest(case=fixture["id"]):
                comparison = compare_case(fixture)
                self.assertTrue(comparison["agreement"], comparison["first_difference"])
        left = candidate_transition(self.cases["heldout_golden_row"])
        right = candidate_transition(self.cases["heldout_golden_row_reversed"])
        self.assertEqual([e["physical_id"] for e in left["events"][:3]], [601, 602, 603])
        self.assertEqual([e["physical_id"] for e in right["events"][:3]], [603, 602, 601])
        self.assertEqual((left["state"]["cash"], right["state"]["cash"]), (12, 12))

    def test_comparator_negative_order_control_is_pure(self):
        fixture = self.cases["heldout_golden_row"]
        expected = source_rule_reference(fixture)
        wrong = deepcopy(expected)
        wrong["events"][0], wrong["events"][1] = wrong["events"][1], wrong["events"][0]
        before_expected, before_wrong = deepcopy(expected), deepcopy(wrong)
        comparison = compare_lifecycle(fixture["id"], manifest(fixture), expected, wrong,
                                       {"fixture_id": fixture["id"], "mutation": "swap first two events"})
        self.assertEqual(comparison["first_difference"]["field"], "events[0].after.debuff")
        self.assertEqual((expected, wrong), (before_expected, before_wrong))

    def test_perishable_guard_remains_for_learning_episodes(self):
        card = Card(center_key="j_golden")
        card.set_ability("j_golden")
        card.set_perishable(True)
        card.ability["perish_tally"] = 1
        self.assertEqual(patches.audit_state_boundary({"jokers": [card]}),
                         "fidelity_perishable_expiry_order")


if __name__ == "__main__":
    unittest.main()
